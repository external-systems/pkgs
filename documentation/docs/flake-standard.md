# Org flake standard

Every external-systems repo has the same shape. A developer needs Nix (with
its sandbox on, the default) and devenv; nothing else.

## Layout

```
flake.nix / flake.lock      consumer outputs; inputs follow pkgs
dev/flake.nix / flake.lock  dev partition inputs: treefmt-nix, presenting
dev/flake-module.nix        imports inputs.pkgs.flakeModules.dev + docs
devenv.yaml / devenv.lock   pkgs input, nixpkgs follows pkgs/nixpkgs,
                            imports pkgs/devenv (the org shell)
devenv.nix                  this repo's languages, services, processes
documentation/              mkdocs.yml, docs/, slides/, module.nix
```

Start a repo from the template:

```sh
nix flake init -t github:external-systems/pkgs
```

## What pkgs provides

| Piece | Gives |
|---|---|
| `flakeModules.treefmt` | alejandra, deadnix, nixf-diagnose, shellcheck, sizelint, statix as treefmt programs: `formatter`, `checks.treefmt` |
| `flakeModules.dev` | treefmt, `checks.lock-sync`, `apps.sync-locks`, and the docs and slides builds as checks |
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
| `devenv up` | live docs on :8000 and slides on :8001 |
| `devenv test` | treefmt check and lock sync, no VMs |
| `sync-locks` | after `nix flake update pkgs`: re-pin `dev/flake.lock` and `devenv.lock` |

## Three lockfiles, one nixpkgs

`flake.lock`, `dev/flake.lock` and `devenv.lock` must resolve nixpkgs to the
same rev. `checks.lock-sync` fails when they drift and names the fix. The
bump flow is always `nix flake update pkgs`, then `sync-locks`.
