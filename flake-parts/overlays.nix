_: {
  flake.overlays = {
    default = import ../overlays/default.nix;
    ifstate = import ../overlays/ifstate.nix;
    kubernetes = import ../overlays/kubernetes.nix;
  };
}
