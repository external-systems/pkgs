# Dev partition: formatter, checks, maintainer apps, docs and slides, and
# the code-agent image. A consumer of packages, overlays or lib never
# evaluates it.
{inputs, ...}: {
  # By path, not self.flakeModules.dev: reading self here would recurse.
  imports = [
    (import ../flakeModules/dev.nix {orgInputs = inputs;})
    ../documentation/flake-module.nix
    ../images/code-agent/flake-module.nix
  ];
}
