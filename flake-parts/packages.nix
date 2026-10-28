{self, ...}: {
  perSystem = {pkgs, ...}: let
    # The flake's own packages are the overlay applied to the pinned nixpkgs
    # — one construction, two surfaces (packages.<system>.* for direct
    # builds, overlays.default for consumers).
    artifactPkgs = pkgs.extend self.overlays.default;
  in {
    packages = {
      inherit
        (artifactPkgs)
        ifstate
        rke2
        rke2_1_35
        rke2_1_36
        rke2_1_37
        k3s
        k3s_1_35
        k3s_1_36
        k3s_1_37
        ;
    };
  };
}
