# AGENTS.md

CHANGE ME: one paragraph on what this repo is.

## Layout
- `flake.nix`: consumer-facing inputs (all follow external-systems/pkgs) and the dev partition wiring.
- `flake-parts/`: consumer-facing flake-parts modules, auto-imported (import-tree).
- `dev/flake.nix` + `dev/flake.lock`: dev-only inputs. `dev/flake-module.nix`: the dev partition (formatter, checks, apps, docs).
- `devenv.yaml` + `devenv.lock` + `devenv.nix`: the dev shell. The org shell comes from external-systems/pkgs (`org-pkgs/devenv` in devenv.yaml).
- `documentation/`: MkDocs site (`docs/`) and reveal.js deck (`slides/`).
- `.github/workflows/ci.yml`: the org standard CI, calling the org-ci reusable workflow in external-systems/pkgs. `nix flake check` on PRs and the merge queue; on main pushes, after it passes, the Pages deploy and the `<major>.<minor>.<commits>` release tag. `.github/rulesets/default.json`: the org branch ruleset (required check `ci / flake-check`).
- `.vscode/`: nixd (Nix language server) settings, resolved from this flake's own inputs and `debug` options; nixd and alejandra come from the devenv shell.

## Tool loop
- The shell is devenv. If `DEVENV_ROOT` is unset, run commands with `devenv shell -- <cmd>`.
- `git add` new files before any `nix` command.
- `fmt`, then `check`. Both must pass before a change is done.
- After `nix flake update org-pkgs`, run `sync-locks` in the same commit.

## Rules
- Load the `nix-style` skill before editing any `.nix` file.
- Dev-only inputs go in `dev/flake.nix`, never `flake.nix`.
- Work on a branch and open a PR. Never push to `main`; the ruleset requires a PR with a green `ci / flake-check`.
- Never commit build output (`result*`, `_site/`, `site/`): docs and slides are built and deployed by CI.
