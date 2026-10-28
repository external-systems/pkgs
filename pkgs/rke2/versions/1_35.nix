# Version table for the overlay-built rke2 1.35 minor (v1.35.9+rke2r1).
# nixpkgs (pinned 26.11pre) still carries 1.35.8 — SPEC D34 wants the latest
# patch per minor, so this local table supersedes it. Same conventions as
# 1_37.nix: values from scripts/version.sh at the pinned tag.
{
  rke2Version = "1.35.9+rke2r1";
  rke2Commit = "8229013e2b1a73eef1b41dd93708fa96cf11f11f";
  rke2TarballHash = "sha256-WR4Gs7I0tmru0bZfNPhddUqBhj3c2TZmA4jYM4vcfZU=";
  rke2VendorHash = "sha256-WUha49sjWT2klCalewVZGJZ/sasoUZI8eSxibAD4WIM=";

  k8sImageTag = "v1.35.9-rke2r1-build20260923";
  etcdVersion = "v3.6.14-k3s3-build20260915";
  pauseVersion = "3.10.2";
  ccmVersion = "v1.35.9-0.20260915234130-a341ba01f9eb-build20260916";
  dockerizedVersion = "v1.35.9-rke2r1";
  helmJobVersion = "v0.13.3-build20260909";

  imagesVersions = {
    images-core-linux-amd64-tar-zst = {
      url = "https://github.com/rancher/rke2/releases/download/v1.35.9%2Brke2r1/rke2-images-core.linux-amd64.tar.zst";
      sha256 = "sha256-+eHJ9mVFYYsa5zakCwHACHsX6auYsNdHvJHvTG2lar0=";
    };
    images-core-linux-arm64-tar-zst = {
      url = "https://github.com/rancher/rke2/releases/download/v1.35.9%2Brke2r1/rke2-images-core.linux-arm64.tar.zst";
      sha256 = "sha256-e0cvcNRaDwzZQIvpLqxI/xl89xPjhnezLm35KSVjNkw=";
    };
  };
}
