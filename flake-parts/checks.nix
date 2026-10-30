{
  self,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: {
    # Per minor, both distro runtimes must package the SAME Kubernetes
    # release (SPEC D34). Formatting and lint are checks.treefmt, from
    # flakeModules.treefmt in the dev partition.
    checks =
      lib.mapAttrs' (minor: versions:
        lib.nameValuePair "k8s-version-parity-${minor}" (pkgs.runCommand "k8s-version-parity-${minor}" {
            k3sK8s = versions.kubernetes;
            rke2K8s = builtins.head (builtins.split ''\+'' (lib.removePrefix "v" versions.rke2));
          } ''
            if [ "$k3sK8s" != "$rke2K8s" ]; then
              echo "Kubernetes version mismatch on $minor: k3s packages $k3sK8s, rke2 packages $rke2K8s" >&2
              exit 1
            fi
            touch $out
          ''))
      self.lib.versions.matrix;
  };
}
