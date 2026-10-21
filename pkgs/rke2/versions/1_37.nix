# Version table for the overlay-built rke2 (v1.37.1+rke2r1), pattern from
# andrewthomaslee/borg lib/mk-rke2.nix.
#
# nixpkgs (pinned 26.11pre) does not carry rke2 1.37 — the overlay
# (overlays/default.nix) reuses nixpkgs' own rke2 builder with this table.
# Values are taken from the release's own scripts/version.sh of the pinned
# tag so the binary's embedded image ldflags match exactly what rke2's
# release CI embeds.
#
# rke2TarballHash is the hash of the unpacked tag tarball (the same URL the
# builder's fetchzip fetches); rke2VendorHash pins the Go vendor tree
# (resolved via the placeholder-hash build dance — the same mechanism
# nixpkgs' own update script uses).
{
  rke2Version = "1.37.1+rke2r1";
  rke2Commit = "bb33a3e8f191b46f773bd4eae2fe471927126c1b";
  rke2TarballHash = "sha256-ezTW6Xhf3hxizz6Lv/aa9NjaXa0z9fANAsaoEY1W6v4=";
  rke2VendorHash = "sha256-yDewXbR7nk3bhGIxVVf1B6XEmC3C5hmjCVju21+VAD4=";

  # Component image versions embedded as ldflags (rancher hardened registry
  # images), from scripts/version.sh at the pinned tag.
  k8sImageTag = "v1.37.1-rke2r1-build20260924";
  etcdVersion = "v3.7.1-k3s3-build20260915";
  pauseVersion = "3.10.2";
  ccmVersion = "v1.37.1-0.20260915225838-315ede265f11-build20260916";
  dockerizedVersion = "v1.37.1-rke2r1";
  helmJobVersion = "v0.13.3-build20260909";

  # Unused: the nixpkgs builder's fetchurl'd per-release image-tarball
  # passthru attrs — airgap image tarballs will be exported as their own
  # granular flake outputs in a later step.
  imagesVersions = {};
}
