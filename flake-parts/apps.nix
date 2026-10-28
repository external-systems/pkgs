{
  self,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: {
    apps = {
      # Regenerate every committed base manifest from the pinned charts and
      # profiles (SPEC D26: inflation is an update-time act committed as
      # source). Run from the repo root; review the git diff before commit.
      update-manifests = {
        type = "app";
        meta.description = "Regenerate committed manifests from pinned charts";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "update-manifests";
          runtimeInputs = [pkgs.nix pkgs.git];
          text = ''
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: artifact: ''
                echo "rendering ${name} -> manifests/${artifact.path}"
                out=$(nix build "${self}#${artifact.package}" --no-link --print-out-paths)
                install -Dm644 "$out" "manifests/${artifact.path}"
              '')
              self.lib.manifestArtifacts)}
            echo "done — review with: git diff manifests/"
          '';
        });
      };

      # Bump one rke2 minor to its latest upstream patch (SPEC D34): resolves
      # the newest tag for the minor, pins commit + tarball hash, extracts
      # the ldflag component versions from the tag's scripts/version.sh, and
      # resolves the Go vendor hash via the placeholder-hash build dance.
      # Usage: nix run .#update-rke2 -- 1.35   (run from the repo root)
      update-rke2 = {
        type = "app";
        meta.description = "Update one pinned RKE2 minor to its latest patch";
        program = lib.getExe (pkgs.writeShellApplication {
          name = "update-rke2";
          runtimeInputs = with pkgs; [nix git curl python3 gnugrep];
          text = ''
                        set -euo pipefail
                        minor="''${1:?usage: update-rke2 <minor, e.g. 1.35>}"
                        minor_us="''${minor//./_}"
                        table="pkgs/rke2/versions/''${minor_us}.nix"

                        echo "resolving latest rke2 patch for $minor"
                        tag=$(curl -sf "https://api.github.com/repos/rancher/rke2/releases?per_page=100" \
                          | python3 -c "
            import json, re, sys
            minor = '$minor'
            for r in json.load(sys.stdin):
                t = r['tag_name']
                if re.fullmatch(r'v' + re.escape(minor) + r'\.\d+\+rke2r1', t):
                    print(t)
                    break
            else:
                sys.exit('no rke2r1 release found for minor ' + minor)
            ")
                        echo "latest tag: $tag"

                        commit=$(curl -sf "https://api.github.com/repos/rancher/rke2/git/refs/tags/$(python3 -c "import urllib.parse; print(urllib.parse.quote(\"$tag\", safe=\"\"))")" \
                          | python3 -c "import json, sys; d = json.load(sys.stdin); assert d['object']['type'] == 'commit', 'annotated tag: dereference manually'; print(d['object']['sha'])")
                        echo "commit: $commit"

                        echo "hashing tag tarball (unpacked)"
                        tarball_hash=$(nix store prefetch-file --unpack --json "https://github.com/rancher/rke2/archive/refs/tags/$tag.tar.gz" \
                          | python3 -c "import json, sys; print(json.load(sys.stdin)['hash'])")

                        echo "extracting ldflag versions from scripts/version.sh at $tag"
                        version_sh=$(mktemp)
                        curl -sf "https://raw.githubusercontent.com/rancher/rke2/$tag/scripts/version.sh" > "$version_sh"
                        field() { grep -oP "^$1=\\$\\{$2:-\\K[^}]+" "$version_sh" | head -1; }
                        k8s_image_tag=$(field KUBERNETES_IMAGE_TAG KUBERNETES_IMAGE_TAG)
                        etcd_version=$(field ETCD_IMAGE_TAG ETCD_VERSION)
                        pause_version=$(field PAUSE_VERSION PAUSE_VERSION)
                        ccm_version=$(field CCM_VERSION CCM_VERSION)
                        helm_job_version=$(field KLIPPERHELM_VERSION KLIPPERHELM_VERSION)
                        dockerized_version="v$(echo "''${tag#v}" | tr '+' '-')"
                        version="''${tag#v}"
                        for v in k8s_image_tag etcd_version pause_version ccm_version helm_job_version; do
                          if [ -z "''${!v}" ]; then echo "failed to extract $v from version.sh" >&2; exit 1; fi
                        done

                        encoded_tag="''${tag//+/%2B}"
                        core_amd64_url="https://github.com/rancher/rke2/releases/download/$encoded_tag/rke2-images-core.linux-amd64.tar.zst"
                        core_arm64_url="https://github.com/rancher/rke2/releases/download/$encoded_tag/rke2-images-core.linux-arm64.tar.zst"
                        echo "hashing core airgap images"
                        core_amd64_hash=$(nix store prefetch-file --json "$core_amd64_url" | python3 -c "import json, sys; print(json.load(sys.stdin)['hash'])")
                        core_arm64_hash=$(nix store prefetch-file --json "$core_arm64_url" | python3 -c "import json, sys; print(json.load(sys.stdin)['hash'])")

                        write_table() {
                          local vendor_hash="$1"
                          cat > "$table" <<EOF
                        # Version table for the overlay-built rke2 $minor ($tag), generated by
                        # \`nix run .#update-rke2 -- $minor\`. Values are taken from the release's
                        # own scripts/version.sh of the pinned tag so the binary's embedded image
                        # ldflags match exactly what rke2's release CI embeds. rke2VendorHash pins
                        # the Go vendor tree (placeholder-hash build dance, resolved by the updater).
                        {
                          rke2Version = "$version";
                          rke2Commit = "$commit";
                          rke2TarballHash = "$tarball_hash";
                          rke2VendorHash = "$vendor_hash";

                          k8sImageTag = "$k8s_image_tag";
                          etcdVersion = "$etcd_version";
                          pauseVersion = "$pause_version";
                          ccmVersion = "$ccm_version";
                          dockerizedVersion = "$dockerized_version";
                          helmJobVersion = "$helm_job_version";

                          imagesVersions = {
                            images-core-linux-amd64-tar-zst = {
                              url = "$core_amd64_url";
                              sha256 = "$core_amd64_hash";
                            };
                            images-core-linux-arm64-tar-zst = {
                              url = "$core_arm64_url";
                              sha256 = "$core_arm64_hash";
                            };
                          };
                        }
                        EOF
                        }

                        write_table "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
                        git add "$table"
                        echo "resolving vendor hash (placeholder build)"
                        vendor_hash=$(nix build ".#rke2_$minor_us" 2>&1 | grep -oP 'got:\s+\Ksha256-\S+' | head -1)
                        if [ -z "$vendor_hash" ]; then echo "vendor hash dance failed" >&2; exit 1; fi
                        write_table "$vendor_hash"
                        git add "$table"

                        echo "verifying final build"
                        nix build ".#rke2_$minor_us" --no-link
                        echo "updated $table to $tag"
          '';
        });
      };
    };
  };
}
