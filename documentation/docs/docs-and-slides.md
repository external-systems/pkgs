# Docs and slides

Every external-systems repo has a MkDocs website and a reveal.js deck.
`flakeModules.docs` (part of `flakeModules.default`) builds both. A repo that
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
| `checks.documentation`, `checks.slides` | both builds, from `flakeModules.default` |

MkDocs, Material and the Markdown extensions come from the org nixpkgs, so
they download from cache.nixos.org. reveal.js is pinned by pkgs
(`inputs.reveal-js`); its release tags ship a prebuilt `dist/`. rough.js
and Mermaid are single files cut from their npm tarballs at pinned
versions (`fetchurl`), only when a repo uses them. There is no npm
anywhere.

## The org style

Every site and deck gets the look first built in explain-kube-to-me
(`docs.orgStyle.enable`, on by default):

- **Palette:** a clay-orange accent on warm dark (`#1f1e1d`) and cream
  (`#faf9f5`) backgrounds, for the site's light and dark modes and the
  deck. Serif headings (Georgia), larger body text.
- **Deck building blocks** (`org/org.css`), as classes in `slides.md`:
  `kicker` (small caps line above a title), `big`, `hint`, `muted`,
  `takeaway` (a callout line), `layer` (a stacked layer cake), `pre.spec`
  (short YAML listings: `.k` keys, `.v` values, `.c` comments, `.kw`
  keywords), `ul.ticks` / `ul.ticks.cross`, `img.icon` / `img.hero`,
  `tiles` + `tile`, `title-slide`.
- **Speaker sync** (`docs.slides.speakerSync`): key presses in the speaker
  view (press S) go straight to the audience window, so clicking fast no
  longer lags, skips steps or jumps back.
- **Sketch diagrams** (`docs.slides.sketch.enable`): an
  `<svg class="sketch">` is redrawn with rough.js once the deck is ready,
  so boxes, circles and arrows look hand-drawn while text stays crisp.
- **Mermaid and emoji** on the site: ` ```mermaid ` blocks become
  diagrams (Mermaid ships with the site when a page uses it, so it renders
  offline), and `:material-github:`-style emoji and icons work.
- **Reveal defaults:** 1280×720, slide transition, fading backgrounds,
  progress bar, `h.v` slide numbers, auto-animate.

A sketch diagram in `slides.md`:

```html
<div class="diagram">
<svg class="sketch" viewBox="0 0 600 160">
  <rect x="20" y="40" width="200" height="80" stroke="#d97757" fill="#d97757" />
  <text x="120" y="88" text-anchor="middle">Desired state</text>
  <line x1="230" y1="80" x2="370" y2="80" stroke="#faf9f5" data-arrow />
  <rect x="380" y="40" width="200" height="80" stroke="#6a9bcc" fill="none" data-dash />
  <text x="480" y="88" text-anchor="middle">Actual state</text>
</svg>
</div>
```

Attributes: `fill` is drawn as a soft tint (`data-fill="solid"` for full
strength, `fill="none"` for an outline), `rx` rounds a rect (default 12),
`data-arrow` puts an arrowhead on a line or polyline, `data-dash` dashes
it. Put fragment classes on a `<g>` around shapes, never on a shape.

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
        inputs.org-pkgs.flakeModules.default
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
      # The deck's own files in documentation/slides/, loaded after the
      # org style so they can override it.
      extraHead = ''<link rel="stylesheet" href="custom.css" />'';
      # Scripts that need the Reveal global.
      extraBody = ''<script src="deck.js"></script>'';
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
| `docs.orgStyle.enable` | `true` | the org look for site and deck |
| `docs.mermaid.enable` | a page has ` ```mermaid ` | ship Mermaid so diagrams render offline |
| `docs.slides.enable` | `documentation/slides/` exists | the deck and its preview |
| `docs.slides.markdown` | `slides.md` | `---` next slide, `--` below, `Note:` speaker notes |
| `docs.slides.title` | `docs.settings.site_name` | page title |
| `docs.slides.theme` | `black` | reveal.js theme |
| `docs.slides.config` | org defaults (above) | `Reveal.initialize` options |
| `docs.slides.speakerSync` | `true` | audience window follows the speaker view |
| `docs.slides.sketch.enable` | `true` | hand-drawn `svg.sketch` diagrams |
| `docs.slides.extraHead` | empty | extra `<head>` tags, after the org style |
| `docs.slides.extraBody` | empty | extra tags after reveal.js, before `Reveal.initialize` |
| `docs.slides.embed` | `true` | copy the deck into the site at `slides/` |
| `docs.slides.port` | `8982` | live slides preview |

The org MkDocs defaults: Material with a light and dark palette (the org
colours), system fonts, `search` and `offline` plugins,
`use_directory_urls: false` (so the site browses from `file://`), and
abbr, admonition, attr_list, md_in_html, tables, details, highlight, keys,
emoji, superfences with the Mermaid fence, tabbed and toc permalinks.

A setting that needs a Python object is written as a
`"!!python/name:module.name"` string; the generated mkdocs.yml turns it
into that YAML tag.

## Escape hatches

Prefer, in order: the defaults; `docs.*` options; the deck's own files
(`custom.css`, images) loaded with `extraHead` / `extraBody`; a pkgs PR
for anything every repo would want. The whole-file overrides below are
the last resort:

- **`documentation/mkdocs.yml`**: when present it is used as-is and
  `docs.settings` is ignored (so is the org style's site CSS).
- **`documentation/slides/index.html`**: when present it replaces the
  generated deck page. The org files are still copied to `org/`
  (`org.css`, `speaker-sync.js`, `rough.js`, `sketch.js`), so it can load
  them.

## Linking the deck from a page

Use plain HTML, not a Markdown link: strict builds check Markdown links
against `docs/`, where `slides/` does not exist until the build copies it
in.

```html
<iframe src="slides/index.html" title="Slide deck"
  style="width: 100%; aspect-ratio: 16 / 9; border: 0;"
  allowfullscreen></iframe>
```

