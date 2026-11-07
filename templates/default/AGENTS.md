# AGENTS.md

CHANGE ME: one paragraph on what this repo is.

## Layout
- `flake.nix`: consumer-facing inputs (all follow external-systems/pkgs); imports `org-pkgs.flakeModules.default` (treefmt, docs and slides, lock-sync). No dev partition, no `dev/flake.nix`.
- `flake-parts/`: consumer-facing flake-parts modules, auto-imported (import-tree).
- `flake-parts/docs.nix`: `docs.*` settings that differ from the org defaults (pkgs' "Docs and slides" page).
- `devenv.yaml` + `devenv.lock` + `devenv.nix`: the dev shell. The org shell comes from external-systems/pkgs (`org-pkgs/devenv` in devenv.yaml).
- `vm-tests/`: NixOS VM tests, one `nixosLib.runTest` module per file (flakeModules.vmTests from org-pkgs). Built as `legacyPackages.<system>.vmTests.<name>`, never in `checks`.
- `documentation/`: MkDocs site (`docs/*.md`) and reveal.js deck (`slides/slides.md`). The MkDocs config and the deck's index.html are generated.
- `.github/workflows/ci.yml`: the org standard CI, calling the org-ci reusable workflow in external-systems/pkgs. `nix flake check` on PRs and the merge queue; on main pushes, after it passes, the Pages deploy and the `<major>.<minor>.<commits>` release tag. `.github/rulesets/default.json`: the org branch ruleset (required check `ci / flake-check`).
- `.vscode/`: nixd (Nix language server) settings, resolved from this flake's own inputs and `debug` options; nixd and alejandra come from the devenv shell.

## Tool loop
- The shell is devenv. If `DEVENV_ROOT` is unset, run commands with `devenv shell -- <cmd>`.
- `git add` new files before any `nix` command.
- `fmt`, then `check`. Both must pass before a change is done.
- After `nix flake update org-pkgs`, run `sync-locks` in the same commit.
- VM tests: `vm-test --list`, `vm-test <name>` (local KVM) or `vm-test <name> --remote` (remote builder). Exit code is the result; logs in `.vm-tests/<name>/`.

## Rules
- Load the `nix-style` skill before editing any `.nix` file.
- No dev-only inputs: tooling comes from org-pkgs. A test-only input that must not reach consumers is the rare case for a dev partition (ask first).
- Work on a branch and open a PR. Never push to `main`; the ruleset requires a PR with a green `ci / flake-check`.
- VM tests run only by hand (`vm-test`), never in CI or `checks`; they stay hermetic (no network, fake secrets built at build time).
- Never commit build output (`result*`, `_site/`, `site/`): docs and slides are built and deployed by CI.
