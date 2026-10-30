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
    nixf-diagnose = {
      enable = true;
      autoFix = false;
      only = "sema-primop-removed-prefix";
    };
    shellcheck.enable = true;
    sizelint.enable = true;
    statix.enable = true;
  };
}
