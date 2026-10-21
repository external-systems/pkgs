# Test fixtures (SPEC §6): source-built workloads and minimal container
# images for downstream Kubernetes e2e tests.
#
# - go-httpbin: request-inspection backend (HTTP/1+2), also layered into
#   image-go-httpbin.
# - image-curl-http3: HTTP/3 test client. The pinned nixpkgs dropped the
#   curlHTTP3 alias (curl builds with HTTP/3 by default), so the image
#   layers plain curl.
# - image-caddy: QUIC-passthrough server fixture; the test mounts its
#   Caddyfile at /etc/caddy/Caddyfile.
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

      image-curl-http3 = pkgs.dockerTools.buildImage {
        name = "curl-http3";
        tag = pkgs.curl.version;
        copyToRoot = pkgs.buildEnv {
          name = "image-curl-http3-root";
          paths = [pkgs.curl pkgs.cacert];
        };
        config = {
          # buildEnv links binaries under /bin; curl's default CA path is
          # not where cacert puts the bundle.
          Env = [
            "PATH=/bin"
            "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
          ];
          Cmd = ["curl"];
        };
      };

      image-caddy = pkgs.dockerTools.buildImage {
        name = "caddy";
        tag = pkgs.caddy.version;
        copyToRoot = pkgs.buildEnv {
          name = "image-caddy-root";
          paths = [pkgs.caddy pkgs.cacert];
        };
        config = {
          Env = [
            "PATH=/bin"
            "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
          ];
          ExposedPorts = {
            "80/tcp" = {};
            "443/tcp" = {};
            "443/udp" = {};
          };
          Cmd = [
            "caddy"
            "run"
            "--config"
            "/etc/caddy/Caddyfile"
          ];
        };
      };
    };
  };
}
