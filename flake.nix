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
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux"];
      imports = [(inputs.import-tree ./flake-parts)];
    };
}
