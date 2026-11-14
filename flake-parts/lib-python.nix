# lib.python.mkWorkspace: the org uv workspace builder
# (flakeModules/python/workspace.nix) bound to this flake's uv2nix,
# pyproject.nix and build-system-pkgs pins. flakeModules.python and the
# devenv module org-pkgs/devenv/python use it, so a Python repo declares
# no uv2nix input of its own.
{inputs, ...}: {
  flake.lib.python.mkWorkspace = import ../flakeModules/python/workspace.nix {
    inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
  };
}
