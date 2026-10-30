# Dev partition: formatter, checks, maintainer apps and the devenv shell.
# A consumer of packages, overlays or lib never evaluates it.
_: {
  # By path, not self.flakeModules.dev: reading self here would recurse.
  imports = [../flakeModules/dev.nix];

  perSystem.devenv.shells.default.imports = [../devenv];
}
