# CoreDNS component (SPEC D46): the digest-pinned upstream CoreDNS image as
# a docker-archive tarball for cluster-side loading (airgap) instead of
# registry pulls. Consumed by clanServices' bootstrap bundle; the pins live
# in pkgs/coredns/versions.nix.
_: {
  perSystem = {pkgs, ...}: let
    versions = import ../../pkgs/coredns/versions.nix;
  in {
    packages.image-coredns = pkgs.dockerTools.pullImage {
      inherit (versions) sha256;
      imageName = versions.repo;
      imageDigest = versions.digest;
      finalImageName = versions.repo;
      finalImageTag = versions.tag;
      os = "linux";
      arch = "amd64";
    };
  };
}
