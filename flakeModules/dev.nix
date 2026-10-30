# The org dev partition base: treefmt + devenv, treefmt in the shell, and a
# check that dev/flake.lock pins the same nixpkgs as flake.lock.
# Consumer: partitions.dev.module = ./dev/flake-module.nix, which imports
# inputs.pkgs.flakeModules.dev.
{
  lib,
  self,
  ...
}: let
  lockOf = file: builtins.fromJSON (builtins.readFile file);

  # Node a root input resolves to, following `follows` paths (lists,
  # always relative to the root node).
  resolve = lock: path:
    lib.foldl' (node: name: let
      ref = lock.nodes.${node}.inputs.${name};
    in
      if builtins.isList ref
      then resolve lock ref
      else ref)
    lock.root
    path;

  revOf = lock: name: lock.nodes.${resolve lock [name]}.locked.rev or "missing";

  rootRev = revOf (lockOf "${self}/flake.lock") "nixpkgs";
  devRev = revOf (lockOf "${self}/dev/flake.lock") "dev-nixpkgs";
in {
  imports = [
    ./treefmt.nix
    ./devenv.nix
  ];

  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devenv.shells.default.packages = [config.treefmt.build.wrapper];

    checks.dev-lock-sync = pkgs.runCommand "dev-lock-sync" {} (
      if rootRev == devRev
      then "touch $out"
      else ''
        echo "dev/flake.lock dev-nixpkgs is ${devRev}, flake.lock nixpkgs is ${rootRev}." >&2
        echo "Fix: nix flake lock ./dev --override-input dev-nixpkgs github:NixOS/nixpkgs/${rootRev}" >&2
        exit 1
      ''
    );
  };
}
