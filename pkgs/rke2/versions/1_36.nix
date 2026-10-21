# Version table for the overlay-built rke2 1.36 minor (v1.36.5+rke2r1).
# nixpkgs (pinned 26.11pre) still carries 1.36.4 — SPEC D34 wants the latest
# patch per minor, so this local table supersedes it. Same conventions as
# 1_37.nix: values from scripts/version.sh at the pinned tag.
{
  rke2Version = "1.36.5+rke2r1";
  rke2Commit = "e1d699d2c3a3d3c1f3247c4f9eb140f20d369776";
  rke2TarballHash = "sha256-8zhsfc00WxqfptCNghaXHSHV8XOYfWrQAF/jolZEimw=";
  rke2VendorHash = "sha256-+0QuvtZtO18iax+Me6ct5dLzLG1Vw1ui6NFeBPYjK60=";

  k8sImageTag = "v1.36.5-rke2r1-build20260923";
  etcdVersion = "v3.6.14-k3s3-build20260915";
  pauseVersion = "3.10.2";
  ccmVersion = "v1.36.5-0.20260915232631-dca49392c395-build20260916";
  dockerizedVersion = "v1.36.5-rke2r1";
  helmJobVersion = "v0.13.3-build20260909";

  imagesVersions = {};
}
