{
  description = "external-systems artifact flake — pinned, source-built packages and source materials for downstream flakes";

  inputs = {
    # Artifact and downstream nixpkgs authority. Downstream flakes follow
    # this input so artifact updates do not require a second nixpkgs update.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:denful/import-tree";

    # ------ Org flake modules (flakeModules.treefmt / .docs) ------ #
    # Bound to this flake by flake-parts/flakeModules.nix, so every repo
    # gets formatting, docs and slides from its one org-pkgs input. Lazy:
    # a consumer that only reads packages or overlays never fetches them.
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # reveal.js, source only. Release tags commit the prebuilt `dist/`, so
    # decks need zero npm. Upgrade: bump the tag, `nix flake update reveal-js`.
    reveal-js = {
      url = "github:hakimel/reveal.js?ref=6.0.2";
      flake = false;
    };

    # ------ Third-party flakes (overlays.third-party) ------ #
    # Packages that only ship as flakes. Lazy: a consumer that never reads
    # pkgs.zen-browser / pkgs.moscripts never fetches them.
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    moscripts = {
      url = "https://flakehub.com/f/andrewthomaslee/moscripts/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      # Exposes debug.options / currentSystem.options, which nixd
      # (.vscode/settings.json) reads for flake-parts option hints.
      debug = true;

      systems = ["x86_64-linux" "aarch64-linux"];

      imports = [
        inputs.flake-parts.flakeModules.partitions
        (inputs.import-tree ./flake-parts)
      ];

      # Apps, checks and the formatter are evaluated only on demand; a
      # consumer reading packages, overlays or lib never fetches the dev
      # inputs (dev/flake.nix). packages stays here: consumers build them.
      # The dev shell is devenv (devenv.yaml), not a flake output.
      partitionedAttrs = {
        apps = "dev";
        checks = "dev";
        formatter = "dev";
        # Docs/slides: `nix build .#documentation` (flakeModules.docs).
        legacyPackages = "dev";
      };

      partitions.dev = {
        module = ./dev/flake-module.nix;
        extraInputsFlake = ./dev;
      };
    };
}
