# CHANGE ME

[![ci](https://img.shields.io/github/actions/workflow/status/external-systems/CHANGE-ME/ci.yml?branch=main&label=ci&logo=github)](https://github.com/external-systems/CHANGE-ME/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/external-systems/CHANGE-ME?label=release&color=d97757)](https://github.com/external-systems/CHANGE-ME/releases/latest)
[![docs](https://img.shields.io/website?url=https%3A%2F%2FCHANGE-ME.external.systems%2F&label=docs&up_message=online&down_message=offline)](https://CHANGE-ME.external.systems/)
[![license](https://img.shields.io/github/license/external-systems/CHANGE-ME)](https://github.com/external-systems/CHANGE-ME/blob/main/LICENSE)
[![built with Nix](https://img.shields.io/badge/built_with-Nix-5277C3?logo=nixos&logoColor=white)](https://nixos.org)

One line on what this repo provides.

## Develop

Needs Nix and devenv.

```sh
devenv allow     # auto-activates the shell on cd (after `devenv hook`)
fmt              # format and lint
check            # nix flake check
docs-build       # static docs to ./result-docs; open index.html from disk
devenv up        # live docs on :8981 and slides on :8982
```

Editor: VS Code with the Nix IDE extension uses `.vscode/settings.json`
(nixd hints from this flake's nixpkgs, flake-parts and NixOS options;
alejandra on format). Start it from the devenv shell, or install nixd
yourself, so `nixd` is on PATH.

## CI and branch protection

`.github/workflows/ci.yml` is the org standard: it calls the `org-ci`
reusable workflow in [external-systems/pkgs](https://github.com/external-systems/pkgs)
(see its CI docs page). Pull requests and the merge queue run `nix flake
check`; pushes to main also deploy the docs to GitHub Pages and tag a
`<major>.<minor>.<commits>` release, both only after the check passes.

One-time setup for a new repo:

```sh
# Settings > Pages > Source: GitHub Actions, then the branch ruleset:
gh api -X POST repos/external-systems/<repo>/rulesets \
  --input .github/rulesets/default.json
```

Private flake inputs (e.g. external-systems/secrets): give the repo access to
the `NIX_APP_CLIENT_ID` org variable and `NIX_APP_PRIVATE_KEY` org secret and set
`private-repos: secrets` under `with:` in `ci.yml`.
