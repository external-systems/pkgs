# Dev partition: formatter, checks, maintainer apps, docs and slides. A
# consumer of this flake never evaluates it.
{inputs, ...}: {
  imports = [
    inputs.org-pkgs.flakeModules.dev
    ../documentation/flake-module.nix
  ];
}
