# Org flake standard

Every external-systems repo has the same shape. A developer needs Nix (with
its sandbox on, the default) and devenv; nothing else.

## Layout

```
flake.nix / flake.lock      one org-pkgs input (nixpkgs, flake-parts,
                            import-tree follow it); imports
                            inputs.org-pkgs.flakeModules.default
flake-parts/                the repo's own modules (import-tree)
devenv.yaml / devenv.lock   org-pkgs input (this repo), nixpkgs follows
                            org-pkgs/nixpkgs, imports org-pkgs/devenv
devenv.nix                  this repo's languages, services, processes
documentation/              docs/*.md, slides/slides.md; optional
                            flake-module.nix (docs.* overrides)
```

No `dev/flake.nix`, no `dev/flake.lock`, no partition: every dev tool
(treefmt, MkDocs, reveal.js) comes from pkgs, which every repo already
locks, so a second lock would protect nobody. pkgs itself is the one
exception: its code-agent image needs external-systems/modules, which
depends on pkgs, so that input lives in pkgs' own dev partition.

Start a repo from the template:

```sh
nix flake init -t github:external-systems/pkgs
```

## What pkgs provides

| Piece | Gives |
|---|---|
| `flakeModules.treefmt` | alejandra, deadnix, nixf-diagnose, shellcheck, sizelint, statix as treefmt programs: `formatter`, `checks.treefmt` |
| `flakeModules.docs` | MkDocs site + reveal.js deck: `packages.documentation`, `packages.slides`, `apps.watch-documentation`, `apps.serve-slides`. See [Docs and slides](docs-and-slides.md) |
| `flakeModules.vmTests` | NixOS VM tests from `vm-tests/*.nix`: `legacyPackages.vmTests`, `apps.vm-test`, eval-only checks. See [VM tests](vm-tests.md) |
| `flakeModules.default` | treefmt, docs, vmTests, `checks.lock-sync`, `apps.sync-locks`, and the docs and slides builds as checks |
| `devenv/` (imported by `devenv.yaml`) | the org shell: `fmt`, `check`, `sync-locks`, `docs`, `slides`, `vm-test` scripts, `devenv up` docs + slides processes, `devenv test` gates |
| `templates.default` | the whole layout for a new repo |

The flake modules are bound to pkgs' own `treefmt-nix` and `reveal-js`
inputs, so a repo declares neither. They add two small nodes to every
`flake.lock`; Nix fetches them only when formatting or building docs.

## Daily commands (inside the devenv shell)

| Command | Does |
|---|---|
| `fmt` | format and lint (treefmt) |
| `check` | `nix flake check` |
| `docs-build` | `nix build .#documentation -o result-docs`; open `result-docs/index.html` from disk |
| `devenv up` | live docs on :8981 and slides on :8982 |
| `devenv test` | treefmt check and lock sync, no VMs |
| `sync-locks` | after `nix flake update org-pkgs`: re-pin `devenv.lock` |
| `vm-test` | NixOS VM tests: `--list`, `<name>`, `--all`, `--remote`, `--driver`. Never in CI |

## Badges

Every public repo shows the same row of [shields.io](https://shields.io)
badges under the title of its `README.md` and `documentation/docs/index.md`
(the template has both, with `CHANGE-ME` as the repo name):

| Badge | Shows | Needs |
|---|---|---|
| ci | `ci / flake-check` on `main` | the org CI |
| release | the latest `w.x.<commits>` tag | the org CI's `release` job |
| docs | whether `https://<repo>.external.systems/` answers | Pages with the custom domain |
| license | the `LICENSE` file's license | a `LICENSE` file |
| built with Nix | static | nothing |

Drop a badge whose "needs" the repo lacks yet. Private repos (secrets,
gitops) get no badges: shields.io asks GitHub as an anonymous client, so
a private repo looks like it does not exist. On a docs build opened from
disk without internet, the badges show their text labels.

## Docs without a server

`nix build .#documentation` builds the static site with the deck embedded
at `slides/`, and `nix build .#slides` builds the deck alone. Open
`result/index.html` straight from disk (`firefox result/index.html`,
`zen result/index.html`). The site uses `use_directory_urls: false` and
Material's `offline` plugin so links and search work over `file://`.

## Why the input is `org-pkgs`

The repo is external-systems/pkgs, but every `flake.nix` and `devenv.yaml`
names the input `org-pkgs`. `pkgs` means the nixpkgs package set everywhere
else (module arguments, `perSystem`), and devenv passes every `devenv.yaml`
input to `devenv.nix` as a module argument, so an input named `pkgs`
replaces nixpkgs' `pkgs` and fails with "attribute 'bash' missing".

## Two lockfiles, one nixpkgs

`flake.lock` and `devenv.lock` must resolve nixpkgs to the same rev (pkgs
also checks its `dev/flake.lock`). `checks.lock-sync` fails when they
drift and names the fix. The bump flow is always
`nix flake update org-pkgs`, then `sync-locks`, in one commit.
