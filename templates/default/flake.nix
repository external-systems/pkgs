{
  description = "CHANGE ME: one line on what this repo provides";

  inputs = {
    # Shared-input authority for the org: consumers that already follow
    # pkgs lock nothing new.
    pkgs.url = "github:external-systems/pkgs";
    nixpkgs.follows = "pkgs/nixpkgs";
    flake-parts.follows = "pkgs/flake-parts";
    import-tree.follows = "pkgs/import-tree";

    # Consumer-facing inputs only; each follows nixpkgs/flake-parts.
    # Dev-only inputs go in dev/flake.nix.
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        inputs.flake-parts.flakeModules.partitions
        (inputs.import-tree ./flake-parts)
      ];

      # Apps, checks and the formatter are evaluated only on demand; a
      # consumer of this flake never fetches dev/flake.nix's inputs.
      # The dev shell is devenv (devenv.yaml), not a flake output.
      partitionedAttrs = {
        apps = "dev";
        checks = "dev";
        formatter = "dev";
        # Docs/slides: `nix build .#documentation` (flakeModules.dev).
        legacyPackages = "dev";
      };

      partitions.dev = {
        module = ./dev/flake-module.nix;
        extraInputsFlake = ./dev;
      };
    };
}
