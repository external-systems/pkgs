{inputs, ...}: let
  rke2Versions = import ../pkgs/rke2/versions.nix;
  k3sVersions =
    import
    (inputs.nixpkgs + "/pkgs/applications/networking/cluster/k3s/1_37/versions.nix");
  # "1.37.1+rke2r1" -> "1.37.1"
  k8sOf = v: builtins.head (builtins.split ''\+'' v);
in {
  flake.lib.versions = {
    # The Kubernetes release both distro runtimes are pinned to — consumers
    # must keep these in lockstep (enforced by checks.k8s-version-parity).
    kubernetes = k8sOf k3sVersions.k3sVersion;
    k3s = "v${k3sVersions.k3sVersion}";
    rke2 = "v${rke2Versions.rke2Version}";
    inherit (k3sVersions) k3sCommit;
    inherit (rke2Versions) rke2Commit;
  };
}
