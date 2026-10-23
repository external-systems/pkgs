# Test fixtures (SPEC §6): source-built workloads and minimal container
# images for downstream Kubernetes e2e tests.
#
# - go-httpbin: request-inspection backend (HTTP/1+2), also layered into
#   image-go-httpbin.
_: {
  perSystem = {pkgs, ...}: let
    versions = import ../../pkgs/go-httpbin/versions.nix;
    go-httpbin = pkgs.buildGoModule {
      pname = "go-httpbin";
      inherit (versions) version;
      # v2.26.0's go.mod has no external requires — nothing to vendor.
      vendorHash = null;
      src = pkgs.fetchFromGitHub {
        inherit (versions) owner repo rev hash;
      };
      subPackages = ["cmd/go-httpbin"];
    };
  in {
    packages = {
      inherit go-httpbin;

      image-go-httpbin = pkgs.dockerTools.buildImage {
        name = "go-httpbin";
        tag = "v${versions.version}";
        copyToRoot = pkgs.buildEnv {
          name = "image-go-httpbin-root";
          paths = [go-httpbin pkgs.cacert];
        };
        config = {
          # The binary listens on 0.0.0.0:8080 by default; no flags needed.
          Cmd = ["${go-httpbin}/bin/go-httpbin"];
          ExposedPorts = {"8080/tcp" = {};};
        };
      };
    };
  };
}
