{self, ...}: {
  perSystem = {pkgs, ...}: let
    # The flake's own packages are the overlay applied to the pinned nixpkgs
    # — one construction, two surfaces (packages.<system>.* for direct
    # builds, overlays.default for consumers).
    artifactPkgs = pkgs.extend self.overlays.default;
  in {
    packages = {
      inherit (artifactPkgs) rke2 k3s;
    };
  };
}
