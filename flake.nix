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

    # ------ VS Code extensions (overlays.vscode-extensions) ------ #
    # Every VS Code Marketplace and Open VSX extension, re-indexed daily
    # upstream: `nix flake update nix-vscode-extensions` updates them all.
    # Lazy: only a consumer that reads pkgs.open-vsx* /
    # pkgs.vscode-marketplace* fetches and evaluates it.
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ------ AI coding agents (overlays.llm-agents) ------ #
    # numtide/llm-agents.nix: claude-code, claude-desktop, pi, kimi-code and opencode v2,
    # updated daily upstream: `nix flake update llm-agents`. Follows the
    # org nixpkgs (one nixpkgs), so cache.numtide.com only hits when our
    # nixpkgs revision matches theirs; otherwise they build locally or on
    # the remote builder. Lazy: only a consumer that reads one of the
    # agent packages fetches and evaluates it.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # ------ Python: uv.lock -> Nix (uv2nix) ------ #
    # One org pin for uv2nix, pyproject.nix and build-system-pkgs. Python
    # repos follow these (`uv2nix.follows = "org-pkgs/uv2nix"` and the
    # other two, in flake.nix and devenv.yaml) so `sync-locks` keeps them
    # aligned; see the uv2nix skill. Lazy: nothing here reads them yet, and
    # a consumer that never reads them never fetches them.
    # Upgrade: `nix flake update pyproject-nix uv2nix pyproject-build-systems`.
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        nixpkgs.follows = "nixpkgs";
      };
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
