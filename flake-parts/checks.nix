{
  self,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}: {
    checks = {
      # Format/lint gate — fails `nix flake check`, which CI runs.
      lint =
        pkgs.runCommand "lint" {
          nativeBuildInputs = with pkgs; [alejandra statix deadnix];
        } ''
          cd ${lib.sources.sourceFilesBySuffices self [".nix"]}
          alejandra --check .
          statix check .
          deadnix --fail .
          touch $out
        '';

      # Both distro runtimes must package the SAME Kubernetes release.
      k8s-version-parity =
        pkgs.runCommand "k8s-version-parity" {
          k3sK8s = self.lib.versions.kubernetes;
          rke2K8s = builtins.head (builtins.split ''\+'' (lib.removePrefix "v" self.lib.versions.rke2));
        } ''
          if [ "$k3sK8s" != "$rke2K8s" ]; then
            echo "Kubernetes version mismatch: k3s packages $k3sK8s, rke2 packages $rke2K8s" >&2
            exit 1
          fi
          touch $out
        '';
    };
  };
}
