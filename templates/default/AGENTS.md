# AGENTS.md

CHANGE ME: one paragraph on what this repo is.

## Layout
- `flake.nix`: consumer-facing inputs (all follow external-systems/pkgs) and the dev partition wiring.
- `flake-parts/`: consumer-facing flake-parts modules, auto-imported (import-tree).
- `dev/flake.nix` + `dev/flake.lock`: dev-only inputs. `dev/flake-module.nix`: the dev partition (formatter, checks, apps, docs).
- `devenv.yaml` + `devenv.lock` + `devenv.nix`: the dev shell. The org shell comes from `pkgs/devenv`.
- `documentation/`: MkDocs site (`docs/`) and reveal.js deck (`slides/`).

## Tool loop
- The shell is devenv. If `DEVENV_ROOT` is unset, run commands with `devenv shell -- <cmd>`.
- `git add` new files before any `nix` command.
- `fmt`, then `check`. Both must pass before a change is done.
- After `nix flake update pkgs`, run `sync-locks` in the same commit.

## Rules
- Load the `nix-style` skill before editing any `.nix` file.
- Dev-only inputs go in `dev/flake.nix`, never `flake.nix`.
- Work on a branch and open a PR. Never push to `main`.
