{
  description = "Development-only inputs for pkgs (the dev partition)";

  # Locked in dev/flake.lock, never in the main flake.lock. dev-nixpkgs
  # must lock the same rev as the root nixpkgs (checks.dev-lock-sync):
  #   nix flake lock ./dev --override-input dev-nixpkgs github:NixOS/nixpkgs/<rev>
  inputs = {
    dev-nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "dev-nixpkgs";
    };

    # nixpkgs NOT followed: devenv's own pin is what devenv.cachix.org
    # serves.
    devenv.url = "github:cachix/devenv?ref=v2.4.0";
  };

  outputs = _: {};
}
