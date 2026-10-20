# pkgs

External Systems' artifact flake: pinned, source-built packages and source
materials (charts, images, CRDs) for downstream flakes — primarily
[external-systems/clanServices](../clanServices) — to consume via a locked
flake input. This repo contains packaging only: no inventory, no clan vars,
no fleet policy.

## Consuming

```nix
inputs.pkgs.url = "github:external-systems/pkgs/<immutable-rev>";
```

- **Packages** — `packages.x86_64-linux.<name>` for direct builds:
  `nix build github:external-systems/pkgs#rke2`
- **Overlay** — `overlays.default` applied onto your own nixpkgs package set
  gives you the pinned artifacts as `pkgs.rke2` / `pkgs.k3s`. The builders
  come from the consumer's nixpkgs (any nixpkgs shipping
  `pkgs/applications/networking/cluster/rke2/builder.nix` and `k3s_1_37`
  works); versions and hashes are pinned here.
- **Version metadata** — `lib.versions` exposes the pinned `kubernetes`,
  `k3s`/`rke2` versions and upstream commits.

## Current artifacts

| Output | Version | Construction |
|---|---|---|
| `rke2` | v1.37.1+rke2r1 | Source-built on nixpkgs' own rke2 builder; version table `pkgs/rke2/versions.nix` (ldflags match the release's `scripts/version.sh`) |
| `k3s` | v1.37.1+k3s1 | Source-built nixpkgs `k3s_1_37`, re-exported as the pinned artifact |

Both distro runtimes package the same Kubernetes release (1.37.1), enforced
by `checks.k8s-version-parity`. Helm charts, OCI images and CRD payloads
follow in later steps.

## Development

```bash
nix fmt .              # alejandra
nix flake check        # lint gate (alejandra + statix + deadnix) + parity
```

`git add` new files before evaluating — Nix reads the git tree.
The nixpkgs pin tracks clan-core main's nixpkgs revision (one nixpkgs
decision for the org; its default Go satisfies the distro go.mod floors).
