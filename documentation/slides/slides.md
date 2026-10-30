# external-systems pkgs

Artifacts and the org flake standard.

Note: Press `S` for the speaker view, `F` for fullscreen.

---

## Artifacts

- Distro runtimes: rke2 and k3s, last 3 Kubernetes minors
- Cilium chart, committed manifest, airgap images
- IfState overlay, CoreDNS image

---

## Org flake standard

- Inputs follow pkgs
- Dev partition: treefmt, docs, checks
- devenv CLI shell: `fmt`, `check`, `devenv up`

--

## New repo

```sh
nix flake init -t github:external-systems/pkgs
```

---

# Thanks
