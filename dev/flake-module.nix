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

  # flakeModules.python's builder on a one-CLI fixture workspace: the
  # shipped set stamps the commit count into the store name and the wheel
  # metadata; the check set keeps the pyproject version.
  perSystem = {pkgs, ...}: let
    ws = inputs.self.lib.python.mkWorkspace {
      inherit pkgs;
      root = ../flakeModules/python/fixture;
      revCount = 7;
    };
  in {
    checks.python-module = pkgs.runCommand "python-module" {} ''
      test "${ws.shipSet.fixture.version}" = 0.1.7
      test "${ws.pythonSet.fixture.version}" = 0.1.0
      test "$(${ws.venv}/bin/fixture)" = "fixture 0.1.7"
      touch $out
    '';
  };
}
