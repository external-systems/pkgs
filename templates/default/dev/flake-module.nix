# Dev partition: formatter, checks, maintainer apps, docs and slides. A
# consumer of this flake never evaluates it.
{inputs, ...}: {
  imports = [
    inputs.pkgs.flakeModules.dev
    ../documentation/module.nix
  ];
}
