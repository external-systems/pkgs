# Org-sanctioned formatters and linters. `nix fmt` runs all of them;
# treefmt-nix also adds checks.treefmt, the CI gate.
# Needs `treefmt-nix` among the consumer's inputs (its dev/flake.nix).
{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];

  perSystem.treefmt.programs = {
    alejandra.enable = true;
    deadnix = {
      enable = true;
      no-lambda-pattern-names = true;
    };
    # Every nixf diagnostic, the same set nixd (the Nix language server)
    # shows in editors, so `nix fmt` fails on what VS Code underlines.
    # Report only: nixf's fixes rename or delete code, so a person
    # applies them.
    nixf-diagnose = {
      enable = true;
      autoFix = false;
    };
    shellcheck.enable = true;
    sizelint.enable = true;
    statix.enable = true;
  };
}
