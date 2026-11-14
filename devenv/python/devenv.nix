# The org Python shell, imported next to org-pkgs/devenv by a Python
# repo's devenv.yaml (`imports: [org-pkgs/devenv, org-pkgs/devenv/python]`).
# It puts the uv workspace's editable venv on PATH, built by the same
# builder as the flake (lib.python.mkWorkspace, flakeModules.python), so
# the shell, the checks and the package share one Python set. Workspace
# projects import from the checkout (edits need no rebuild); the venv is
# rebuilt only when pyproject.toml or uv.lock change.
#
# Editors read the venv through .devenv/profile (python, ty, ruff); see
# the repo template's .vscode/settings.json. uv only edits uv.lock: the
# venv is Nix's, never `uv sync`'s.
#
# devenv passes the consumer's inputs; this module needs the org input
# under its org name, `org-pkgs`.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.org.python;
  ws = inputs.org-pkgs.lib.python.mkWorkspace {
    inherit pkgs;
    inherit (cfg) overrides python;
    # An absolute path, not a store copy: the editable install points at
    # the checkout itself, so `import <project>` works with or without
    # $DEVENV_ROOT set (an IDE, another repo's shell).
    root = /. + config.devenv.root;
    editableRoot = config.devenv.root;
  };
in {
  options.org.python = {
    overrides = lib.mkOption {
      type = lib.types.nullOr lib.types.raw;
      default = null;
      description = ''
        Fixups uv.lock cannot express, as in flakeModules.python (an overlay
        or a path to `{pkgs}: final: prev: {...}`). Default:
        flake-parts/_python/overrides.nix when present.
      '';
    };
    python = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Interpreter; default the first nixpkgs Python inside requires-python.";
    };
    workspace = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      default = ws;
      description = "The built workspace (lib.python.mkWorkspace result).";
    };
  };

  config = {
    # One version of each tool, the org nixpkgs' (also treefmt's and the
    # checks'); never add ruff or ty to the uv dev group.
    packages = [ws.devVenv pkgs.uv pkgs.ruff pkgs.ty];

    env = {
      # uv edits uv.lock only: no .venv, no downloaded interpreters.
      UV_NO_SYNC = "1";
      UV_PYTHON = ws.python.interpreter;
      UV_PYTHON_DOWNLOADS = "never";
      UV_PYTHON_PREFERENCE = "only-system";
      # A `uv run` uses the Nix venv instead of creating .venv.
      UV_PROJECT_ENVIRONMENT = "${ws.devVenv}";
    };

    # nixpkgs Python setup hooks leak PYTHONPATH; it beats the venv.
    enterShell = "unset PYTHONPATH";
  };
}
