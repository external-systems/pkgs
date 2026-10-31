{
  description = "CHANGE ME: one line on what this repo provides";

  inputs = {
    # Shared-input authority for the org: consumers that already follow
    # it lock nothing new. Named org-pkgs, never pkgs, in every flake.nix
    # and devenv.yaml: `pkgs` is the nixpkgs package set everywhere else
    # (module args, perSystem), and devenv shadows it with an input of
    # that name.
    org-pkgs.url = "github:external-systems/pkgs";
    nixpkgs.follows = "org-pkgs/nixpkgs";
    flake-parts.follows = "org-pkgs/flake-parts";
    import-tree.follows = "org-pkgs/import-tree";

    # Consumer-facing inputs only; each follows nixpkgs/flake-parts.
    # Dev-only inputs go in dev/flake.nix.
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      # Exposes debug.options / currentSystem.options, which nixd
      # (.vscode/settings.json) reads for flake-parts option hints.
      debug = true;

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
