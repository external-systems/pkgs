# Dev partition: formatter, checks, maintainer apps, docs and slides. A
# consumer of packages, overlays or lib never evaluates it.
_: {
  # By path, not self.flakeModules.dev: reading self here would recurse.
  imports = [
    ../flakeModules/dev.nix
    ../documentation/module.nix
  ];
}
