# external-systems pkgs

[![ci](https://img.shields.io/github/actions/workflow/status/external-systems/pkgs/ci.yml?branch=main&label=ci&logo=github)](https://github.com/external-systems/pkgs/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/external-systems/pkgs?label=release&color=d97757)](https://github.com/external-systems/pkgs/releases/latest)
[![docs](https://img.shields.io/website?url=https%3A%2F%2Fpkgs.external.systems%2F&label=docs&up_message=online&down_message=offline)](https://pkgs.external.systems/)
[![license](https://img.shields.io/github/license/external-systems/pkgs)](https://github.com/external-systems/pkgs/blob/main/LICENSE)
[![built with Nix](https://img.shields.io/badge/built_with-Nix-5277C3?logo=nixos&logoColor=white)](https://nixos.org)

The organization's artifact flake: pinned, source-built packages and source
materials (charts, images, rendered manifests) for downstream flakes, plus
the shared pieces every external-systems repo builds on.

- **Packages, overlays, `lib`**: see the repository README for the version
  matrix, committed manifests and update apps.
- **Org flake standard**: the flake modules, devenv shell and template every
  repo uses. See [Org flake standard](flake-standard.md).
- **CI**: the reusable GitHub workflows (flake check, docs deploy,
  tagged releases) every repo calls. See [CI](ci.md).

<iframe src="slides/index.html" title="Slide deck"
  style="width: 100%; aspect-ratio: 16 / 9; border: 0;"
  allowfullscreen></iframe>
