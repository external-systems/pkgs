# pkgs

External Systems' artifact flake: pinned, source-built packages and source
materials (charts, images, CRDs, rendered manifests) for downstream flakes —
primarily [external-systems/clanServices](../clanServices) — to consume via a
locked flake input. This repo contains packaging only: no inventory, no clan
vars, no fleet policy.

The consuming contract is defined by clanServices `SPEC.md` (D26 two-layer
rendering, D29 Flux Kustomization handoff, D34 version policy, §7 phase 2).

## Consuming

```nix
inputs.pkgs.url = "github:external-systems/pkgs/<immutable-rev>";
```

- **Packages** — `packages.x86_64-linux.<name>` for direct builds:
  `nix build github:external-systems/pkgs#rke2`
- **Overlay** — `overlays.default` applied onto your own nixpkgs package set
  gives you the pinned artifacts as `pkgs.rke2` / `pkgs.k3s_1_36` / …. The
  builder expressions come from the consumer's nixpkgs: rke2 needs any
  nixpkgs shipping `pkgs/applications/networking/cluster/rke2/builder.nix`
  (all version data is pinned locally in `pkgs/rke2/versions/`); k3s rides
  the consumer's `k3s_1_35`/`k3s_1_36`/`k3s_1_37` builders, so consumer
  nixpkgs must ship those minors at the pinned patches (the pinned nixpkgs
  here is the reference).
- **Version metadata** — `lib.versions.matrix` exposes the full last-3-minors
  matrix per distro (`kubernetes`, `k3s`, `rke2`, commits per minor);
  `lib.versions.kubernetes` / `.k3s` / `.rke2` are latest-minor aliases;
  `lib.versions.latestMinor` names the default.

## Version matrix (SPEC D34)

The last 3 Kubernetes minors per distro, latest patch each, with per-minor
parity enforced by `checks.k8s-version-parity-<minor>`:

| minor | rke2 | k3s |
|---|---|---|
| 1.35 | v1.35.9+rke2r1 (source-built, local table) | v1.35.9+k3s1 (nixpkgs) |
| 1.36 | v1.36.5+rke2r1 (source-built, local table) | v1.36.5+k3s1 (nixpkgs) |
| 1.37 | v1.37.1+rke2r1 (source-built, local table) | v1.37.1+k3s1 (nixpkgs) |

`packages.rke2` / `packages.k3s` alias the latest minor; per-minor attrs are
`rke2_1_35` / `k3s_1_35` / …. Release-tag pins only. rke2 ldflag component
versions come from each tag's own `scripts/version.sh`.

Support-window gate (D34): `lib.versions` emits an eval **warning** (never a
failure) when a pinned component's upstream support matrix does not list a
pinned k8s minor. Today: cert-manager 1.21 and Envoy Gateway 1.9 top out at
k8s 1.36 — accepted bleeding-edge risk for 1.37.

## Committed manifests (SPEC D26 layer 1)

Charts are rendered at **update time** with the canonical fleet-uniform
profile and **committed as source** under `manifests/`. Consumers read the
committed files (`builtins.readFile` / kubenix `importYAML`); nothing in this
repo's outputs requires a build at consumer eval time — zero IFD downstream.
Per-cluster variation is layer 2 (kubenix module merging in clanServices),
never re-run helm values here.

| Component | Artifacts |
|---|---|
| `manifests/cilium/1.20.3.yaml` | Cilium 1.20.3, canonical profile (`pkgs/cilium/values.nix`): KPR, VXLAN, multi-pool IPAM, BPF masquerade+tproxy, Maglev, pmtu, dual-stack, clustermesh-apiserver, Gateway/Ingress off (D1) |
| `manifests/gateway-envoy/` | Envoy Gateway v1.9.2 render + EG/Gateway-API CRDs (`v1.9.2-crds.yaml`), Gateway API v1.6.1 standard + experimental CRDs |
| `manifests/cert-manager/` | cert-manager v1.21.2 render + CRDs artifact |
| `manifests/sealed-secrets/` | sealed-secrets chart 2.20.0 render + CRDs |
| `manifests/external-dns/` | external-dns chart 1.23.0 render + CRDs (`policy=upsert-only` — chart schema requires an explicit policy; non-destructive default) |
| `manifests/flux/` | flux-operator 0.61.0 render (CRDs inline — the chart ships no `crds/` dir) + Flux distribution install.yaml v2.9.6 |
| `manifests/multus/4.3.1.yaml` | multus-cni thick-plugin daemonset, pinned upstream file |

CRDs are separate atomic artifacts wherever the chart ships them as such —
CRDs-first ordering is the consumer's contract (D29).

Every committed manifest is guarded by a `checks.*-freshness` gate: the
committed file must be byte-identical to a fresh render/fetch of the pin.
This is the artifact-side publish-freshness gate (D26/D29).

## Images and airgap

Pinned image tarballs (dockerTools, digest-locked) are flake packages:
`image-envoy`, `image-cert-manager-{controller,webhook,cainjector}`,
`image-flux-*` (8 images), and the aggregate `flux-airgap-images` directory.
Test fixtures (SPEC §6): `go-httpbin` (source-built v2.26.0) +
`image-go-httpbin`, `image-curl-http3` (HTTP/3 client; nixpkgs curl now
enables HTTP/3 by default, so this layers plain `curl`), `image-caddy`
(QUIC-passthrough server fixture).

## Updating

```bash
nix run .#update-rke2 -- 1.35   # bump one rke2 minor to its latest patch:
                                # tag, commit, tarball hash, ldflags from the
                                # tag's scripts/version.sh, vendor-hash dance,
                                # verifying build — one atomic table rewrite
nix run .#update-manifests      # re-render every committed manifest from the
                                # current pins; review with git diff
```

Chart bumps: edit the component's `pkgs/<component>/versions.nix` (new
version + hash via `nix store prefetch-file --json <url>`), then
`nix run .#update-manifests`. k3s bumps ride `nix flake update nixpkgs` —
verify the minors' patches still match upstream latest afterwards.

## Development

```bash
nix fmt .              # alejandra
nix flake check        # lint gate (alejandra + statix + deadnix),
                       # per-minor k8s parity, manifest freshness
```

`git add` new files before evaluating — Nix reads the git tree. The nixpkgs
pin tracks clan-core main's nixpkgs revision (one nixpkgs decision for the
org; its default Go satisfies the distro go.mod floors). Every fetch is
hash-pinned; airgap image sets cover the base components.
