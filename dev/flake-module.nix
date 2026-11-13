# Dev partition: formatter, checks, maintainer apps, docs and slides, and
# the code-agent image. A consumer of packages, overlays or lib never
# evaluates it.
{inputs, ...}: {
  # By path, not self.flakeModules.default: reading self here would recurse.
  imports = [
    (import ../flakeModules/dev.nix {orgInputs = inputs;})
    ../documentation/flake-module.nix
    ../images/code-agent/flake-module.nix
  ];

  # pkgs owns the vm-test runner: test it with stub tests (no VM).
  vmTests.runnerSelfTest.enable = true;
}
