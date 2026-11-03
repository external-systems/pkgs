# Docs and slides for every external-systems repo: a MkDocs site
# (packages.documentation, the deck embedded at /slides/), a reveal.js
# deck (packages.slides), and live previews (apps.watch-documentation,
# apps.serve-slides).
#
# Zero config by convention: a repo with documentation/docs/*.md (and,
# for a deck, documentation/slides/slides.md) needs no Nix at all. The
# org MkDocs settings (Material theme, offline, extensions) and the deck's
# index.html are generated; a repo's own documentation/mkdocs.yml or
# slides/index.html wins when present.
#
# MkDocs comes from the org nixpkgs (python3.withPackages, cached on
# cache.nixos.org), not from a flake of its own. reveal.js is pinned by
# THIS flake (inputs.reveal-js, its release tag commits a prebuilt dist/),
# and flakeModules.nix binds it here, so consumers add no input.
{orgInputs}: {
  lib,
  self,
  ...
}: let
  inherit (lib) mkDefault mkOption types;
  json = types.attrsOf types.anything;
  # Path of `dir` inside the repo checkout, for the live-preview apps.
  # Both are store paths under the flake's own source.
  relative = dir: lib.removePrefix "${toString self}/" (toString dir);
in {
  # importApply'd modules have no key of their own; this one dedups
  # flakeModules.docs imported both directly and through flakeModules.dev.
  key = "external-systems/pkgs#flakeModules.docs";

  perSystem = {
    config,
    options,
    pkgs,
    ...
  }: let
    cfg = config.docs;
    inherit (cfg) slides;

    mkdocs = pkgs.python3.withPackages (ps:
      [
        ps.mkdocs
        ps.mkdocs-material
        ps.mkdocs-glightbox
        ps.pymdown-extensions
      ]
      ++ cfg.extraPythonPackages ps);

    ownConfig = builtins.pathExists "${cfg.root}/mkdocs.yml";
    # JSON is YAML, so MkDocs reads it as mkdocs.yml.
    configFile = pkgs.writeText "mkdocs.yml" (builtins.toJSON cfg.settings);

    # Only the documentation/ subtree, so an unrelated change elsewhere in
    # the repo does not rebuild the site.
    docsSrc = builtins.path {
      path = cfg.root;
      name = "documentation-src";
    };

    revealDist = "${orgInputs.reveal-js}/dist";
    ownIndex = builtins.pathExists "${slides.dir}/index.html";
    indexHtml = pkgs.writeText "index.html" ''
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <title>${lib.escapeXML slides.title}</title>
          <link rel="stylesheet" href="reveal/reset.css" />
          <link rel="stylesheet" href="reveal/reveal.css" />
          <link rel="stylesheet" href="reveal/theme/${slides.theme}.css" />
          <link rel="stylesheet" href="reveal/plugin/highlight/monokai.css" />
          ${slides.extraHead}
        </head>
        <body>
          <div class="reveal">
            <div class="slides">
              <section data-markdown="${slides.markdown}" data-separator="^---$" data-separator-vertical="^--$" data-separator-notes="^Note:"></section>
            </div>
          </div>
          <script src="reveal/reveal.js"></script>
          <script src="reveal/plugin/markdown.js"></script>
          <script src="reveal/plugin/highlight.js"></script>
          <script src="reveal/plugin/notes.js"></script>
          <script>
            Reveal.initialize(Object.assign(${builtins.toJSON slides.config}, {
              plugins: [RevealMarkdown, RevealHighlight, RevealNotes],
            }));
          </script>
        </body>
      </html>
    '';

    slidesPackage = pkgs.runCommand "slides" {nativeBuildInputs = [pkgs.python3];} ''
      cp -r --no-preserve=mode ${builtins.path {
        path = slides.dir;
        name = "slides-src";
      }} $out
      ${lib.optionalString (!ownIndex) "cp --no-preserve=mode ${indexHtml} $out/index.html"}
      # Inline each data-markdown deck into its .html, so the built deck
      # opens from file:// and MkDocs never sees a stray .md file.
      python3 ${./docs/inline-markdown.py} $out
      cp -r ${revealDist} $out/reveal
    '';

    documentation = pkgs.runCommand "documentation" {nativeBuildInputs = [mkdocs];} ''
      cp -r --no-preserve=mode ${docsSrc} src
      cd src
      ${lib.optionalString (!ownConfig) "cp --no-preserve=mode ${configFile} mkdocs.yml"}
      ${lib.optionalString (slides.enable && slides.embed) ''
        rm -rf docs/slides
        cp -r --no-preserve=mode ${slidesPackage} docs/slides
      ''}
      mkdocs build ${lib.optionalString cfg.strict "--strict"} --site-dir $out
    '';

    watch-documentation = pkgs.writeShellApplication {
      name = "watch-documentation";
      runtimeInputs = [mkdocs pkgs.git pkgs.jq];
      text = ''
        cd "$(git rev-parse --show-toplevel)"
        port="''${1:-${toString cfg.port}}"
        dir=${lib.escapeShellArg cfg.path}
        if [ -f "$dir/mkdocs.yml" ]; then
          config="$dir/mkdocs.yml"
        else
          # The generated settings, with docs_dir pointing at the live
          # checkout so edits reload.
          tmp=$(mktemp -d)
          trap 'rm -rf "$tmp"' EXIT
          config="$tmp/mkdocs.yml"
          jq --arg d "$PWD/$dir/docs" '.docs_dir = $d' ${configFile} > "$config"
        fi
        exec mkdocs serve -f "$config" -a "127.0.0.1:$port" ${lib.optionalString cfg.strict "--strict"}
      '';
    };

    # A web server, because browsers refuse to fetch slides.md from a
    # file:// page. Serves the checkout's files, so a refresh shows edits.
    serve-slides = pkgs.writeShellApplication {
      name = "serve-slides";
      runtimeInputs = [pkgs.python3 pkgs.git];
      text = ''
        cd "$(git rev-parse --show-toplevel)"
        port="''${1:-${toString slides.port}}"
        dir=${lib.escapeShellArg slides.path}
        root=$(mktemp -d)
        trap 'rm -rf "$root"' EXIT
        ln -s ${revealDist} "$root/reveal"
        for f in "$PWD/$dir"/*; do ln -s "$f" "$root/"; done
        [ -e "$root/index.html" ] || ln -s ${indexHtml} "$root/index.html"
        echo "Slides on http://127.0.0.1:$port: edit $dir/${slides.markdown}, then refresh."
        python3 -m http.server --bind 127.0.0.1 --directory "$root" "$port"
      '';
    };
  in {
    options.docs = {
      enable = mkOption {
        type = types.bool;
        # Off while a repo still imports presenting's mkdocs-flake module
        # (it defines packages.documentation too); drop that clause once
        # every repo has moved to this module.
        default = builtins.pathExists "${cfg.root}/docs" && !(options ? documentation || options ? presenting);
        defaultText = lib.literalMD "`true` when `documentation/docs/` exists";
        description = "Build the MkDocs site (`packages.documentation`) and its live preview.";
      };

      root = mkOption {
        type = types.path;
        default = "${self}/documentation";
        defaultText = lib.literalExpression ''"''${self}/documentation"'';
        description = ''
          The documentation directory: `docs/` (Markdown pages), optional
          `slides/` (the deck) and an optional `mkdocs.yml`.
        '';
      };

      path = mkOption {
        type = types.str;
        default = relative cfg.root;
        defaultText = lib.literalExpression ''"documentation"'';
        description = "`root` relative to the repository root; the live preview serves from there.";
      };

      repo = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "home";
        description = ''
          The repository's name in the external-systems org. Sets
          `site_url` (`https://<repo>.external.systems/`), the repository
          link and the "edit this page" link.
        '';
      };

      settings = mkOption {
        type = types.submodule {freeformType = json;};
        default = {};
        example = lib.literalExpression ''
          {
            site_name = "external-systems home";
            nav = [{Home = "index.md";} {Fleet = "fleet.md";}];
          }
        '';
        description = ''
          mkdocs.yml as Nix, merged over the org defaults (Material, light
          and dark palette, search + offline, common Markdown extensions,
          `use_directory_urls: false` so the build browses from disk).
          Without `nav`, MkDocs builds the navigation from the files.
          Ignored when `root` has its own `mkdocs.yml`; use that file for
          settings JSON cannot express (`!!python/name:` tags).
        '';
      };

      strict = mkOption {
        type = types.bool;
        default = true;
        description = "Fail the build on broken links and missing pages (`mkdocs --strict`).";
      };

      port = mkOption {
        type = types.port;
        default = 8981;
        description = "Port of `nix run .#watch-documentation`; 8000 is left to the apps themselves.";
      };

      extraPythonPackages = mkOption {
        type = types.functionTo (types.listOf types.package);
        default = _: [];
        example = lib.literalExpression "ps: [ps.mkdocs-redirects]";
        description = "More MkDocs plugins, from nixpkgs' python3Packages.";
      };

      slides = {
        enable = mkOption {
          type = types.bool;
          default = builtins.pathExists slides.dir && !(options ? presenting);
          defaultText = lib.literalMD "`true` when `documentation/slides/` exists";
          description = "Build the reveal.js deck (`packages.slides`) and its live preview.";
        };

        dir = mkOption {
          type = types.path;
          default = "${cfg.root}/slides";
          defaultText = lib.literalExpression ''"''${config.docs.root}/slides"'';
          description = "The deck: its Markdown file, plus any images, CSS or JS it loads.";
        };

        path = mkOption {
          type = types.str;
          default = relative slides.dir;
          defaultText = lib.literalExpression ''"documentation/slides"'';
          description = "`dir` relative to the repository root; the live preview serves from there.";
        };

        embed = mkOption {
          type = types.bool;
          default = true;
          description = "Copy the built deck into the site at `/slides/`.";
        };

        markdown = mkOption {
          type = types.str;
          default = "slides.md";
          description = ''
            The deck's Markdown file in `dir`. Slides are split by `---`
            (next), `--` (below) and `Note:` (speaker notes).
          '';
        };

        title = mkOption {
          type = types.str;
          default = cfg.settings.site_name or "Slides";
          defaultText = lib.literalExpression "config.docs.settings.site_name";
          description = "The deck's page title.";
        };

        theme = mkOption {
          type = types.str;
          default = "black";
          example = "white";
          description = "reveal.js theme: black, white, league, moon, dracula, ...";
        };

        config = mkOption {
          type = json;
          default = {};
          example = {
            transition = "fade";
            width = 1280;
            height = 720;
          };
          description = "Options for `Reveal.initialize`, merged over `hash` and `slideNumber` (https://revealjs.com/config/).";
        };

        extraHead = mkOption {
          type = types.lines;
          default = "";
          example = ''<link rel="stylesheet" href="custom.css" />'';
          description = "Extra tags for the generated index.html's `<head>`, e.g. the deck's own CSS.";
        };

        port = mkOption {
          type = types.port;
          default = 8982;
          description = "Port of `nix run .#serve-slides`.";
        };
      };
    };

    config = lib.mkMerge [
      {
        docs = {
          settings = {
            site_name = mkDefault (
              if cfg.repo != null
              then "external-systems ${cfg.repo}"
              else "Documentation"
            );
            # page.html instead of page/, so the build browses from disk.
            use_directory_urls = mkDefault false;
            theme = {
              name = mkDefault "material";
              # System fonts, no Google Fonts request: the site stays
              # offline-clean from file://.
              font = mkDefault false;
              features = mkDefault [
                "content.code.annotate"
                "content.code.copy"
                "navigation.footer"
                "navigation.indexes"
                "navigation.sections"
                "navigation.top"
                "search.highlight"
                "search.suggest"
                "toc.follow"
              ];
              palette = mkDefault [
                {
                  media = "(prefers-color-scheme: light)";
                  scheme = "default";
                  toggle = {
                    icon = "material/brightness-7";
                    name = "Switch to dark mode";
                  };
                }
                {
                  media = "(prefers-color-scheme: dark)";
                  scheme = "slate";
                  toggle = {
                    icon = "material/brightness-4";
                    name = "Switch to light mode";
                  };
                }
              ];
            };
            # offline: search and the rest of the site work from file://.
            plugins = mkDefault ["search" "offline"];
            markdown_extensions = mkDefault [
              "admonition"
              "attr_list"
              "md_in_html"
              "tables"
              "pymdownx.details"
              "pymdownx.highlight"
              "pymdownx.keys"
              "pymdownx.superfences"
              {"pymdownx.tabbed".alternate_style = true;}
              {toc.permalink = true;}
            ];
          };
          slides.config = {
            # Keep the slide number in the URL, so a refresh stays put.
            hash = mkDefault true;
            slideNumber = mkDefault true;
          };
        };
      }

      (lib.mkIf (cfg.repo != null) {
        docs.settings = {
          site_url = mkDefault "https://${cfg.repo}.external.systems/";
          repo_url = mkDefault "https://github.com/external-systems/${cfg.repo}";
          repo_name = mkDefault "external-systems/${cfg.repo}";
          edit_uri = mkDefault "edit/main/${cfg.path}/docs/";
        };
      })

      (lib.mkIf cfg.enable {
        packages = {inherit documentation;};
        apps.watch-documentation = {
          type = "app";
          program = lib.getExe watch-documentation;
          meta.description = "Live docs preview on 127.0.0.1:${toString cfg.port}";
        };
      })

      (lib.mkIf slides.enable {
        packages.slides = slidesPackage;
        apps.serve-slides = {
          type = "app";
          program = lib.getExe serve-slides;
          meta.description = "Live slides preview on 127.0.0.1:${toString slides.port}";
        };
      })
    ];
  };
}
