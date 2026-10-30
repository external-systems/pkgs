# Org flake standard, exported once so every external-systems repo imports
# it instead of copying it. Each module reads the CONSUMER's inputs
# (treefmt-nix, devenv), which the consumer declares in its dev/flake.nix,
# so this flake gains no input and no consumer's main flake.lock grows.
{inputs, ...}: {
  imports = [inputs.flake-parts.flakeModules.flakeModules];

  flake.flakeModules = {
    # Org linters as treefmt programs: formatter + checks.treefmt.
    treefmt = ../flakeModules/treefmt.nix;
    # devenv flake-mode defaults for devShells.default.
    devenv = ../flakeModules/devenv.nix;
    # Both, plus treefmt in the shell and checks.dev-lock-sync. The one
    # import a repo's dev partition needs.
    dev = ../flakeModules/dev.nix;
  };
}
