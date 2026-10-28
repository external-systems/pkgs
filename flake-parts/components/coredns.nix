# CoreDNS component (SPEC D46): the digest-pinned upstream CoreDNS image as
# a docker-archive tarball for cluster-side loading (airgap) instead of
# registry pulls. Consumed by clanServices' bootstrap bundle; the pins live
# in pkgs/coredns/versions.nix.
_: let
  versions = import ../../pkgs/coredns/versions.nix;
in {
  flake.lib.coredns.imageRef = "${versions.repo}:${versions.tag}@${versions.digest}";

  perSystem = {pkgs, ...}: let
    arch =
      if pkgs.stdenv.hostPlatform.isx86_64
      then "amd64"
      else if pkgs.stdenv.hostPlatform.isAarch64
      then "arm64"
      else throw "unsupported CoreDNS airgap system ${pkgs.stdenv.hostPlatform.system}";
  in {
    packages.image-coredns = pkgs.dockerTools.pullImage {
      sha256 = versions.sha256.${arch};
      imageName = versions.repo;
      imageDigest = versions.digest;
      finalImageName = versions.repo;
      finalImageTag = versions.tag;
      os = "linux";
      inherit arch;
    };
  };
}
