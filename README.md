# pkgs

External Systems' artifact flake: pinned, source-built packages and source
materials (charts, images, rendered manifests) for downstream flakes —
primarily [external-systems/clanServices](../clanServices) — to consume via a
locked flake input. This repo contains packaging only: no inventory, no clan
vars, no fleet policy.

The consuming contract is defined by clanServices `SPEC.md` (D26 two-layer
rendering, D34 version policy, D40 Cilium lifecycle, D41 Node IPAM, §8 phase
2). Scope after the round-13 narrowing: **only** the distro runtimes (last 3
Kubernetes minors per distro), the IfState package overlay, the Cilium chart +
committed inflated manifest + airgap image set, the CoreDNS image (D46 uniform
clan-rendered CoreDNS), and the go-httpbin test fixture. Everything day-2
(Envoy Gateway, cert-manager, Flux, external-dns, Multus, Sealed Secrets) is
GitOps-owned (SPEC §3.3) and no longer carried here.

## Consuming

```nix
inputs.pkgs.url = "github:external-systems/pkgs/<immutable-rev>";
```

- **Packages** — `packages.<system>.<name>` for direct builds on
  `x86_64-linux` and `aarch64-linux`:
  `nix build github:external-systems/pkgs#rke2`
- **Overlays** — `overlays.default` composes the Kubernetes and IfState
  artifact overlays; `overlays.kubernetes` and `overlays.ifstate` are also
  exported separately. Applying the default overlay gives you the pinned
  artifacts as `pkgs.rke2` / `pkgs.k3s_1_36` / `pkgs.ifstate`. The builder
  expressions come from the consumer's nixpkgs: rke2 needs any nixpkgs
  shipping `pkgs/applications/networking/cluster/rke2/builder.nix` (all
  version data is pinned locally in `pkgs/rke2/versions/`); k3s rides the
  consumer's `k3s_1_35`/`k3s_1_36`/`k3s_1_37` builders, so consumer nixpkgs
  must ship those minors at the pinned patches. Following this flake's
  `nixpkgs` input is the supported way to keep that contract aligned.
- **Artifact metadata** — `lib.versions.matrix` exposes the full
  last-3-minors matrix per distro (`kubernetes`, `k3s`, `rke2`, commits per
  minor); `lib.versions.kubernetes` / `.k3s` / `.rke2` are latest-minor
  aliases. `lib.cilium.manifest` is the committed base manifest,
  `lib.cilium.imagePackageNames` lists its per-system tarball outputs, and
  `lib.coredns.imageRef` is the digest-pinned CoreDNS reference.

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
failure) when Cilium's upstream support matrix does not list a pinned k8s
minor. Today: no warnings — Cilium 1.20 supports 1.33–1.37.

## Committed manifests (SPEC D26 layer 1)

The Cilium chart is rendered at **update time** with the canonical
fleet-uniform profile and **committed as source** under `manifests/`.
Consumers read the committed file (`builtins.readFile` / kubenix
`importYAML`); nothing in this repo's outputs requires a build at consumer
eval time — zero IFD downstream. Per-cluster variation is layer 2 (kubenix
module merging in clanServices), never re-run helm values here.

| Component | Artifacts |
|---|---|
| `manifests/cilium/1.20.3.yaml` | Cilium 1.20.3, canonical profile (`pkgs/cilium/values.nix`): KPR, native routing, multi-pool IPAM, auto-direct-node-routes off, Cilium iptables rules off, BPF masquerade+tproxy, Maglev, pmtu, dual-stack, clustermesh-apiserver, Gateway/Ingress off (D1) |

The committed manifest is guarded by `checks.manifest-cilium-freshness`: the
committed file must be byte-identical to a fresh render of the pin. This is
the artifact-side publish-freshness gate (D26/D40).

## Images and airgap

Every container image the committed Cilium manifest references is exported as
a digest-pinned docker-archive tarball (dockerTools.pullImage):
`image-cilium-agent`, `image-cilium-envoy`, `image-cilium-operator`,
`image-cilium-clustermesh-apiserver`, plus the aggregate
`cilium-airgap-images` directory for VM tests to preload. Each supported
system selects its matching amd64 or arm64 image and output hash.
`checks.cilium-airgap-completeness` enforces that the pinned set in
`pkgs/cilium/versions.nix` matches the manifest's image references exactly.

CoreDNS (SPEC D46): `image-coredns` — the digest-pinned upstream
`registry.k8s.io/coredns/coredns` tarball for the clan-rendered
cluster.local DNS.

Test fixture (SPEC §6): `go-httpbin` (source-built v2.26.0) +
`image-go-httpbin`.

## Updating

```bash
nix run .#update-rke2 -- 1.35   # bump one rke2 minor to its latest patch:
                                # tag, commit, tarball hash, ldflags from the
                                # tag's scripts/version.sh, vendor-hash dance,
                                # verifying build — one atomic table rewrite
nix run .#update-manifests      # re-render the committed manifest from the
                                # current pins; review with git diff
```

Cilium chart bumps: edit `pkgs/cilium/versions.nix` (new version + hash via
`nix store prefetch-file --json <url>`, refresh `images` from a fresh
render's image references), then `nix run .#update-manifests`. k3s bumps ride
`nix flake update nixpkgs` — verify the minors' patches still match upstream
latest afterwards.

## Development

```bash
nix fmt .              # alejandra
nix flake check        # lint gate (alejandra + statix + deadnix),
                       # per-minor k8s parity, manifest freshness,
                       # cilium airgap completeness
```

`git add` new files before evaluating — Nix reads the git tree. This repo is
the organization's nixpkgs authority: downstream flakes follow `pkgs/nixpkgs`
so routine artifact and nixpkgs updates remain independent of consumer update
lifecycles. Every fetch is a fixed-output derivation from a public URL with a
committed hash; airgap image sets cover the committed Cilium manifest.
