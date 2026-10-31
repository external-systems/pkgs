# Org flake standard

Every external-systems repo has the same shape. A developer needs Nix (with
its sandbox on, the default) and devenv; nothing else.

## Layout

```
flake.nix / flake.lock      consumer outputs; inputs follow org-pkgs
dev/flake.nix / flake.lock  dev partition inputs: treefmt-nix, presenting
dev/flake-module.nix        imports inputs.org-pkgs.flakeModules.dev + docs
devenv.yaml / devenv.lock   org-pkgs input (this repo), nixpkgs follows
                            org-pkgs/nixpkgs, imports org-pkgs/devenv
devenv.nix                  this repo's languages, services, processes
documentation/              mkdocs.yml, docs/, slides/, flake-module.nix
```

Start a repo from the template:

```sh
nix flake init -t github:external-systems/pkgs
```

## What pkgs provides

| Piece | Gives |
|---|---|
| `flakeModules.treefmt` | alejandra, deadnix, nixf-diagnose, shellcheck, sizelint, statix as treefmt programs: `formatter`, `checks.treefmt` |
| `flakeModules.dev` | treefmt, `checks.lock-sync`, `apps.sync-locks`, and the docs and slides builds as checks and as `legacyPackages` (`nix build .#documentation`) |
| `devenv/` (imported by `devenv.yaml`) | the org shell: `fmt`, `check`, `sync-locks`, `docs`, `slides` scripts, `devenv up` docs + slides processes, `devenv test` gates |
| `templates.default` | the whole layout for a new repo |

The flake modules read the importing repo's own `inputs.treefmt-nix` and
`inputs.presenting` (declared in its `dev/flake.nix`), so pkgs adds nothing
to anyone's main `flake.lock`.

## Daily commands (inside the devenv shell)

| Command | Does |
|---|---|
| `fmt` | format and lint (treefmt) |
| `check` | `nix flake check` |
| `docs-build` | `nix build .#documentation -o result-docs`; open `result-docs/index.html` from disk |
| `devenv up` | live docs on :8981 and slides on :8982 |
| `devenv test` | treefmt check and lock sync, no VMs |
| `sync-locks` | after `nix flake update pkgs`: re-pin `dev/flake.lock` and `devenv.lock` |

## Docs without a server

`nix build .#documentation` builds the static site with the deck embedded
at `slides/`, and `nix build .#slides` builds the deck alone. Open
`result/index.html` straight from disk (`firefox result/index.html`,
`zen result/index.html`). The site uses `use_directory_urls: false` and
Material's `offline` plugin so links and search work over `file://`.
These come from `legacyPackages`, partitioned to `dev`, so `packages`
stay at the root and consumers never fetch docs inputs. A repo whose
consumers use its `legacyPackages` cannot partition it; there, build
`.#checks.<system>.documentation` instead.

## Why the input is `org-pkgs`

The repo is external-systems/pkgs, but every `flake.nix` and `devenv.yaml`
names the input `org-pkgs`. `pkgs` means the nixpkgs package set everywhere
else (module arguments, `perSystem`), and devenv passes every `devenv.yaml`
input to `devenv.nix` as a module argument, so an input named `pkgs`
replaces nixpkgs' `pkgs` and fails with "attribute 'bash' missing".

## Three lockfiles, one nixpkgs

`flake.lock`, `dev/flake.lock` and `devenv.lock` must resolve nixpkgs to the
same rev. `checks.lock-sync` fails when they drift and names the fix. The
bump flow is always `nix flake update pkgs`, then `sync-locks`.
