{
  description = "external-systems artifact flake — pinned, source-built packages and source materials for downstream flakes";

  inputs = {
    # One nixpkgs decision for the org: the same revision clan-core main
    # pins (and external-systems/clanServices thereby consumes). Its default
    # go (1.26.8) satisfies the rke2/k3s 1.37 go.mod floor.
    nixpkgs.url = "github:NixOS/nixpkgs/319e4cebef10cbb636c6ea392137b52ad105336a";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:denful/import-tree";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];
      imports = [(inputs.import-tree ./flake-parts)];
    };
}
