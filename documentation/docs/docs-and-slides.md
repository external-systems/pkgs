# Docs and slides

Every external-systems repo has a MkDocs website and a reveal.js deck.
`flakeModules.docs` (part of `flakeModules.dev`) builds both. A repo that
follows the layout below needs no Nix for its docs.

## Layout

```
documentation/
  docs/index.md        the website, one Markdown file per page
  slides/slides.md     the deck (optional)
  flake-module.nix     optional: docs.* settings that differ from the defaults
  mkdocs.yml           optional: replaces the generated MkDocs config
```

| Output | What |
|---|---|
| `packages.documentation` | the static site, the deck embedded at `slides/`; opens from disk |
| `packages.slides` | the deck alone, Markdown inlined, reveal.js next to it |
| `apps.watch-documentation` | live preview on 127.0.0.1:8981 (`docs` devenv script) |
| `apps.serve-slides` | live preview on 127.0.0.1:8982 (`slides` devenv script) |
| `checks.documentation`, `checks.slides` | both builds, from `flakeModules.dev` |

MkDocs, Material and the Markdown extensions come from the org nixpkgs, so
they download from cache.nixos.org. reveal.js is pinned by pkgs
(`inputs.reveal-js`); its release tags ship a prebuilt `dist/`, so there
is no npm anywhere.

## A repo's flake.nix

```nix
{
  inputs = {
    org-pkgs.url = "github:external-systems/pkgs";
    nixpkgs.follows = "org-pkgs/nixpkgs";
    flake-parts.follows = "org-pkgs/flake-parts";
    import-tree.follows = "org-pkgs/import-tree";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux"];
      imports = [
        # treefmt, docs + slides, lock-sync: everything from pkgs.
        inputs.org-pkgs.flakeModules.dev
        (inputs.import-tree ./flake-parts)
        # Only when it sets something:
        ./documentation/flake-module.nix
      ];
    };
}
```

## Setting things

Everything is optional. Set only what differs:

```nix
# documentation/flake-module.nix
{
  perSystem.docs = {
    # site_url https://home.external.systems/, repository and
    # "edit this page" links.
    repo = "home";

    # mkdocs.yml as Nix, merged over the org defaults. Without nav,
    # MkDocs builds the navigation from the files.
    settings = {
      site_name = "external-systems home";
      nav = [
        {Home = "index.md";}
        {Fleet = ["fleet/index.md" "fleet/remote-builder.md"];}
      ];
      plugins = ["search" "offline" "glightbox" "tags"];
    };

    # More MkDocs plugins from nixpkgs.
    extraPythonPackages = ps: [ps.mkdocs-redirects];

    slides = {
      title = "Home fleet";
      theme = "white";
      # Reveal.initialize options, merged over hash + slideNumber.
      config = {
        transition = "fade";
        width = 1280;
        height = 720;
      };
      # The deck's own files in documentation/slides/.
      extraHead = ''<link rel="stylesheet" href="custom.css" />'';
    };
  };
}
```

| Option | Default | |
|---|---|---|
| `docs.enable` | `documentation/docs/` exists | the site and its preview |
| `docs.root` | `${self}/documentation` | the documentation directory |
| `docs.repo` | `null` | org repo name: site, repository and edit links |
| `docs.settings` | org defaults | mkdocs.yml as Nix |
| `docs.strict` | `true` | broken links and missing pages fail the build |
| `docs.port` | `8981` | live docs preview |
| `docs.extraPythonPackages` | `ps: []` | more MkDocs plugins |
| `docs.slides.enable` | `documentation/slides/` exists | the deck and its preview |
| `docs.slides.markdown` | `slides.md` | `---` next slide, `--` below, `Note:` speaker notes |
| `docs.slides.title` | `docs.settings.site_name` | page title |
| `docs.slides.theme` | `black` | reveal.js theme |
| `docs.slides.config` | `{hash = true; slideNumber = true;}` | `Reveal.initialize` options |
| `docs.slides.extraHead` | empty | extra `<head>` tags |
| `docs.slides.embed` | `true` | copy the deck into the site at `slides/` |
| `docs.slides.port` | `8982` | live slides preview |

The org defaults: Material with a light and dark palette, `search` and
`offline` plugins, `use_directory_urls: false` (both so the site browses
from `file://`), and admonition, attr_list, md_in_html, tables, details,
highlight, keys, superfences, tabbed and toc permalinks.

## Escape hatches

- **`documentation/mkdocs.yml`**: when present it is used as-is and
  `docs.settings` is ignored. Use it for settings JSON cannot express,
  such as `!!python/name:` tags (emoji, custom fences).
- **`documentation/slides/index.html`**: when present it replaces the
  generated deck page, for full control over plugins and scripts.

## Linking the deck from a page

Use plain HTML, not a Markdown link: strict builds check Markdown links
against `docs/`, where `slides/` does not exist until the build copies it
in.

```html
<iframe src="slides/index.html" title="Slide deck"
  style="width: 100%; aspect-ratio: 16 / 9; border: 0;"
  allowfullscreen></iframe>
```

## Moving a repo off external-systems/presenting

1. Bump org-pkgs, import `inputs.org-pkgs.flakeModules.dev` in
   `flake.nix`, drop the partition, `dev/flake.nix` and `dev/flake.lock`.
2. Replace `documentation/flake-module.nix` with the `docs.*` settings
   above, or delete it. Delete `mkdocs.yml` and `slides/index.html` unless
   the repo needs them as escape hatches.
3. `nix flake lock`, `sync-locks`, `fmt`, `check`.

While a repo still imports presenting's module, `docs.enable` stays off,
so bumping org-pkgs alone does not break its build.
