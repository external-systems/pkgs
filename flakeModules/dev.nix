# The org dev base: treefmt, docs and slides (flakeModules.docs), NixOS
# VM tests and the vm-test runner (flakeModules.vmTests), Python repos on
# uv2nix (flakeModules.python, on when pyproject.toml + uv.lock exist), the lock-sync
# check and app, and the docs build as checks. A repo imports
# inputs.org-pkgs.flakeModules.default in its flake.nix; no dev/flake.nix.
#
# The lockfiles must agree on nixpkgs: flake.lock, devenv.lock (the
# devenv CLI shell, nixpkgs following org-pkgs/nixpkgs) and, in a
# repo with a dev partition (none today), dev/flake.lock's dev-nixpkgs.
# devenv.lock's git-hooks (the org shell's hooks) must also match the
# git-hooks that flake.lock resolves through org-pkgs (in pkgs, its own
# input). checks.lock-sync fails when they drift; `sync-locks` (devenv
# script, or nix run .#sync-locks) re-pins devenv.yaml (and
# dev/flake.lock) to flake.lock.
#
# checks.git-hooks: a repo with a devenv shell always has the org git
# hooks: devenv.yaml follows org-pkgs/git-hooks (devenv reads inputs from
# the repo's own devenv.yaml only) and .gitignore lists the generated
# .pre-commit-config.yaml.
{orgInputs}: {
  lib,
  self,
  ...
}: let
  lockOf = file: builtins.fromJSON (builtins.readFile file);

  # Node an input path resolves to, following `follows` paths (lists,
  # always relative to the root node); null when an input is missing.
  resolve = lock: path:
    lib.foldl' (node: name: let
      ref = lock.nodes.${node}.inputs.${name} or null;
    in
      if node == null
      then null
      else if builtins.isList ref
      then resolve lock ref
      else ref)
    lock.root
    path;

  revAt = lock: path: let
    node = resolve lock path;
  in
    if node == null
    then "missing"
    else lock.nodes.${node}.locked.rev or "missing";

  revOf = lock: name: revAt lock [name];

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

  # git-hooks: every repo with a devenv shell has it.
  devenvLock = lockOf "${self}/devenv.lock";
  hasGitHooks = hasDevenv && devenvLock.nodes.${devenvLock.root}.inputs ? git-hooks;
  gitHooksPath = lib.optional (pkgsInput != null) pkgsInput ++ ["git-hooks"];
  gitHooksRev = revAt rootLock gitHooksPath;
  devenvGitHooksRev = revOf devenvLock "git-hooks";
  gitHooksDrifted = hasGitHooks && devenvGitHooksRev != gitHooksRev;

  gitignoreFile = "${self}/.gitignore";
  gitignored = name:
    builtins.pathExists gitignoreFile
    && lib.elem name (map lib.trim (lib.splitString "\n" (builtins.readFile gitignoreFile)));
  gitHooksProblems = lib.optionals hasDevenv (
    lib.optional (!hasGitHooks) "devenv.yaml has no git-hooks input"
    ++ lib.optional (hasGitHooks && pkgsInput != null && devenvLock.nodes.${devenvLock.root}.inputs.git-hooks != gitHooksPath)
    "devenv.yaml git-hooks does not follow ${pkgsInput}/git-hooks"
    ++ lib.optional (!gitignored ".pre-commit-config.yaml") ".gitignore does not list .pre-commit-config.yaml"
  );
in {
  key = "external-systems/pkgs#flakeModules.dev";
  imports = [
    (import ./treefmt.nix {inherit orgInputs;})
    (import ./docs.nix {inherit orgInputs;})
    (import ./vm-tests.nix {inherit orgInputs;})
    (import ./python.nix {inherit orgInputs;})
    (import ./eval-warnings.nix {inherit orgInputs;})
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
          else
            ''
              sed -i -E 's#(url: github:NixOS/nixpkgs)[^[:space:]]*#\1/${rootRev}#' devenv.yaml
              devenv update nixpkgs
            ''
            + lib.optionalString hasGitHooks ''
              sed -i -E 's#(url: github:cachix/git-hooks.nix)[^[:space:]]*#\1/${gitHooksRev}#' devenv.yaml
              devenv update git-hooks
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
          if drifted == {} && !gitHooksDrifted
          then "touch $out"
          else
            lib.optionalString (drifted != {}) ''
              echo "nixpkgs drifted from flake.lock (${rootRev}):" >&2
              ${lib.concatLines (lib.mapAttrsToList (name: rev: "echo '  ${name} = ${rev}' >&2") drifted)}
            ''
            + lib.optionalString gitHooksDrifted ''
              echo "git-hooks drifted from flake.lock (${gitHooksRev}):" >&2
              echo "  devenv.lock git-hooks = ${devenvGitHooksRev}" >&2
            ''
            + ''
              echo "Fix: sync-locks (devenv shell) or nix run .#sync-locks" >&2
              exit 1
            ''
        );

        git-hooks = pkgs.runCommand "git-hooks" {} (
          if gitHooksProblems == []
          then "touch $out"
          else ''
            echo "The org git hooks are not set up:" >&2
            ${lib.concatMapStrings (p: "echo ${lib.escapeShellArg "  - ${p}"} >&2\n") gitHooksProblems}
            echo "Fix: in devenv.yaml under inputs add" >&2
            echo "  git-hooks:" >&2
            echo "    follows: org-pkgs/git-hooks" >&2
            echo "and add .pre-commit-config.yaml to .gitignore; then devenv shell -- true" >&2
            exit 1
          ''
        );
      }
      # Docs and slides build on every flake check (mkdocs strict mode
      # fails on broken links).
      // docs;

    # Mirror for flakes that partition docs away from the root (pkgs
    # itself): nix falls back from
    # packages to legacyPackages, so `nix build .#documentation` works
    # there too.
    legacyPackages = docs;
  };
}
