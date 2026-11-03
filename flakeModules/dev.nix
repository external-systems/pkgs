# The org dev base: treefmt, docs and slides (flakeModules.docs), the
# lock-sync check and app, and the docs build as checks. A repo imports
# inputs.org-pkgs.flakeModules.dev in its flake.nix; no dev/flake.nix.
#
# The lockfiles must agree on nixpkgs: flake.lock, devenv.lock (the
# devenv CLI shell, nixpkgs following org-pkgs/nixpkgs) and, only in a
# repo that still has one (pkgs itself), dev/flake.lock's dev-nixpkgs.
# checks.lock-sync fails when they drift; `sync-locks` (devenv script, or
# nix run .#sync-locks) re-pins devenv.yaml (and dev/flake.lock) to
# flake.lock.
{orgInputs}: {
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

  rootLock = lockOf "${self}/flake.lock";
  hasDevenv = builtins.pathExists "${self}/devenv.lock";
  devLockFile = "${self}/dev/flake.lock";
  devLock = lockOf devLockFile;
  hasDevNixpkgs = builtins.pathExists devLockFile && devLock.nodes.${devLock.root}.inputs ? dev-nixpkgs;

  # pkgs itself owns nixpkgs; every other repo pins nixpkgs through the
  # org-pkgs input (`pkgs` in repos not yet renamed).
  rootInputs = rootLock.nodes.${rootLock.root}.inputs;
  pkgsInput = lib.findFirst (name: rootInputs ? ${name}) null ["org-pkgs" "pkgs"];
  pkgsRev =
    if pkgsInput != null
    then revOf rootLock pkgsInput
    else null;

  revs =
    {
      "flake.lock nixpkgs" = revOf rootLock "nixpkgs";
    }
    // lib.optionalAttrs hasDevNixpkgs {
      "dev/flake.lock dev-nixpkgs" = revOf devLock "dev-nixpkgs";
    }
    // lib.optionalAttrs hasDevenv {
      "devenv.lock nixpkgs" = revOf (lockOf "${self}/devenv.lock") "nixpkgs";
    };
  rootRev = revs."flake.lock nixpkgs";
  drifted = lib.filterAttrs (_: rev: rev != rootRev) revs;
in {
  key = "external-systems/pkgs#flakeModules.dev";
  imports = [
    (import ./treefmt.nix {inherit orgInputs;})
    (import ./docs.nix {inherit orgInputs;})
  ];

  perSystem = {
    config,
    pkgs,
    ...
  }: let
    docs =
      lib.getAttrs
      (lib.intersectLists ["documentation" "slides"] (lib.attrNames config.packages))
      config.packages;

    sync-locks = pkgs.writeShellApplication {
      name = "sync-locks";
      runtimeInputs = [pkgs.git pkgs.gnused];
      text =
        ''
          cd "$(git rev-parse --show-toplevel)"
        ''
        + lib.optionalString hasDevNixpkgs ''
          nix flake lock ./dev --override-input dev-nixpkgs github:NixOS/nixpkgs/${rootRev}
        ''
        + ''
          if [ -f devenv.yaml ]; then
        ''
        + (
          if pkgsRev != null
          then ''
            sed -i -E 's#(url: github:external-systems/pkgs)[^[:space:]]*#\1/${pkgsRev}#' devenv.yaml
            devenv update org-pkgs
          ''
          else ''
            sed -i -E 's#(url: github:NixOS/nixpkgs)[^[:space:]]*#\1/${rootRev}#' devenv.yaml
            devenv update nixpkgs
          ''
        )
        + ''
          fi
          git status --short flake.lock devenv.yaml devenv.lock ${lib.optionalString hasDevNixpkgs "dev/flake.lock"}
        '';
    };
  in {
    apps.sync-locks = {
      type = "app";
      program = lib.getExe sync-locks;
      meta.description = "Pin devenv.lock (and dev/flake.lock) to the flake.lock nixpkgs";
    };

    checks =
      {
        lock-sync = pkgs.runCommand "lock-sync" {} (
          if drifted == {}
          then "touch $out"
          else ''
            echo "nixpkgs drifted from flake.lock (${rootRev}):" >&2
            ${lib.concatLines (lib.mapAttrsToList (name: rev: "echo '  ${name} = ${rev}' >&2") drifted)}
            echo "Fix: sync-locks (devenv shell) or nix run .#sync-locks" >&2
            exit 1
          ''
        );
      }
      # Docs and slides build on every flake check (mkdocs strict mode
      # fails on broken links).
      // docs;

    # Mirror for flakes that partition docs away from the root (pkgs
    # itself, and repos not yet off presenting): nix falls back from
    # packages to legacyPackages, so `nix build .#documentation` works
    # there too.
    legacyPackages = docs;
  };
}
