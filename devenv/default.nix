# pkgs dev shell, a plain devenv module. Never reference flake inputs or
# self' here: it evaluates in devenv's module system. The org linters
# (treefmt) are added by flakeModules.dev.
{pkgs, ...}: {
  packages = with pkgs; [
    git
    jq
  ];
}
