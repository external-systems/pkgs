# devenv in flake mode: devenv.shells.default becomes devShells.default.
# The repo's own shell lives in devenv/default.nix and is imported by the
# repo's dev partition. Needs `devenv` among the consumer's inputs (its
# dev/flake.nix), so the main flake.lock never carries devenv.
{
  inputs,
  lib,
  ...
}: {
  imports = [inputs.devenv.flakeModule];

  perSystem.devenv.shells.default = {
    # devenv 2.x derives its root from PWD, which is empty under pure
    # eval (nix flake check, CI, plain `nix develop`). Fall back to a
    # writable scratch root there; impure evals resolve the worktree.
    devenv.root = let
      pwd = builtins.getEnv "PWD";
    in
      lib.mkDefault (
        if pwd == ""
        then "/tmp/devenv-pure-root"
        else pwd
      );

    # Flake mode generates container outputs that throw unless
    # nix2container and mk-shell-bin are inputs. mkForce because devenv
    # declares them at normal priority; a repo that builds containers
    # adds those inputs and overrides with lib.mkOverride 40.
    containers = lib.mkForce {};
  };
}
