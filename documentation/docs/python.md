# Python

Every org Python project is a **uv workspace** (`pyproject.toml` +
`uv.lock`) built by Nix with [uv2nix](https://github.com/pyproject-nix/uv2nix),
checked with Astral's tools ([uv](https://docs.astral.sh/uv/),
[ruff](https://docs.astral.sh/ruff/), [ty](https://docs.astral.sh/ty/)),
and edited in VS Code or VSCodium against the same environment.

A repo writes Python and, at most, a few `python.*` settings. Everything
else comes from pkgs:

| Piece | Gives |
|---|---|
| `flakeModules.python` (in `flakeModules.default`) | On when `pyproject.toml` and `uv.lock` are at the repo root: packages, apps, checks, ruff in treefmt, a VM test |
| `org-pkgs/devenv/python` (in `devenv.yaml`) | The editable dev venv, `uv`, `ruff`, `ty` and the uv settings |
| `lib.python.mkWorkspace` | The builder both use, for anything custom |

A Python repo declares **no** uv2nix input: the module is bound to pkgs'
own `uv2nix`, `pyproject-nix` and `pyproject-build-systems` pins.

## What a repo gets

```text
packages.<project>        each workspace project: its [project.scripts]
                          wrapped (or a venv for a library),
                          version <major>.<minor>.<commit count>
packages.default          the root project
packages.<project>-venv   the shipped virtualenv
apps.<script>             nix run .#<script>
checks.python-pytest      pytest on the installed package (when tests/ exists)
checks.python-ty          ty check, warnings fail
checks.python-uv-lock     uv.lock matches pyproject.toml
checks.python-version     pyproject <major>.<minor> = ci.yml's major/minor
checks.treefmt            + ruff check --fix, ruff format
vmTests.python-cli        every script --version and --help, as a user, offline
legacyPackages.python     pythonSet, shipSet, venv, testVenv (inspection)
```

Settings, all optional (`flake-parts/python.nix` by convention):

```nix
_: {
  perSystem = {pkgs, ...}: {
    python = {
      runtimeInputs = [pkgs.gum pkgs.mpv]; # programs the scripts exec
      checkInputs = [pkgs.which];          # extra PATH for the checks
      checks.docs-examples = "python -m doctest README.md";
      # ty.args = [];                      # let ty warnings pass
      # python = pkgs.python314;           # default: first in requires-python
    };
  };
  # python.vmTest.enable = false;          # top level: no python-cli test
}
```

Build fixups uv.lock cannot express (native libraries, sdist build
systems) go in `flake-parts/_python/overrides.nix`, a
`{pkgs}: final: prev: {...}` overlay; the flake module and the devenv
module both load it. Recipes: the uv2nix skill's `overrides.md`.

## Versions

The org release number is `<major>.<minor>.<git rev-list --count HEAD>`
(CI tags every `main` commit). Python follows it:

- `pyproject.toml` holds `version = "<major>.<minor>.0"`, the same major
  and minor as `.github/workflows/ci.yml` (`checks.python-version`).
  Bump them together.
- Nix stamps the patch: with the flake's `self.revCount`, the shipped
  package, its store name and `importlib.metadata.version()` read
  `<major>.<minor>.<commits>`. The checks build the unstamped set, so they
  do not rebuild on every commit.
- `self.revCount` exists for a clean git checkout (`nix build .`) and for
  `git+https://` inputs, not for `github:` inputs or a dirty tree, which
  keep `X.Y.0`.
- Every CLI answers `--version` with `<project> <version>` (the
  `python-cli` VM test asserts it). With Typer:

```python
from importlib.metadata import version
from typing import Annotated

import typer


def _print_version(value: bool | None) -> None:
    if value:
        typer.echo(f"myproject {version('myproject')}")
        raise typer.Exit


VersionOption = Annotated[
    bool | None,
    typer.Option("--version", callback=_print_version, is_eager=True,
                 help="Show the version and exit."),
]


@app.command()
def main(_version: VersionOption = None) -> None: ...
```

## Consuming org Python packages

| Consumer | How | Version |
|---|---|---|
| Nix (an app or CLI in a NixOS or home-manager config) | pkgs takes the repo as `git+https://github.com/<owner>/<repo>?ref=main` with `inputs.org-pkgs.follows = ""` and names the package in its overlay | exact |
| Python code in another repo (a library) | `uv add git+https://github.com/<owner>/<repo> --tag <release>`: a uv git source, pinned to a commit in `uv.lock`; no flake input | exact (stamped from the fetched commit count) |

- Libraries reach other Python code through `uv.lock` only, never through
  a flake overlay: one resolution, one pin.
- The dependency line stays unversioned (`"mylib"`); the tag in
  `[tool.uv.sources]` is the pin. uv reads `X.Y.0` from the source and
  would reject `mylib>=X.Y.N`.
- A library's own git sources (another org library) are followed by uv:
  consumers do not repeat them.
- Upgrade: `uv add git+https://github.com/<owner>/<repo> --tag <newer>`.
- Private repos: uv and Nix's git fetcher use git credentials
  (`gh auth setup-git` once); keep the URLs `https://`.
- To work on a library and its consumer together, point the source at a
  checkout for a while (`{ path = "../mylib", editable = true }`); never
  commit it (uv2nix only accepts paths inside the repo).

## The devenv shell

```yaml
# devenv.yaml
imports:
  - org-pkgs/devenv
  - org-pkgs/devenv/python
```

- The venv on PATH is the uv2nix set with the workspace projects
  **editable**: imports resolve to the checkout (a literal path, so it
  works without `$DEVENV_ROOT`), and only `pyproject.toml`/`uv.lock`
  changes rebuild it.
- `uv`, `ruff`, `ty` are the org nixpkgs' versions, the same as treefmt
  and the checks. Never add ruff or ty to a uv dependency group.
- uv only edits the lock: `UV_NO_SYNC=1`, no downloaded interpreters, and
  `UV_PROJECT_ENVIRONMENT` points `uv run` at the Nix venv (no `.venv`).

Tool loop:

```sh
uv add httpx                      # or edit pyproject.toml, then: uv lock
uv lock --upgrade-package httpx   # bump one dependency
git add -A && fmt && check        # ruff, ty, pytest, uv-lock, version
nix build && ./result/bin/<script> --version
vm-test python-cli --remote
```

## Editors

VS Code and VSCodium use the same files. Every extension is on Open VSX
(VSCodium) and the Marketplace; Pylance is not needed, ty is the language
server.

`.vscode/extensions.json` recommendations: `jnoortheen.nix-ide`,
`astral-sh.ty`, `charliermarsh.ruff`, `ms-python.python`,
`ms-python.debugpy` (unwanted: `ms-python.vscode-pylance`).

`.vscode/settings.json` (the repo template has them):

```jsonc
"python.defaultInterpreterPath": "${workspaceFolder}/.devenv/profile/bin/python",
"python.languageServer": "None",
"python.terminal.activateEnvironment": false,
"python.testing.pytestEnabled": true,
"ty.path": ["${workspaceFolder}/.devenv/profile/bin/ty"],
"ty.diagnosticMode": "workspace",
"ruff.path": ["${workspaceFolder}/.devenv/profile/bin/ruff"],
"[python]": {
  "editor.defaultFormatter": "charliermarsh.ruff",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {"source.fixAll": "explicit", "source.organizeImports": "explicit"}
}
```

`.devenv/profile` exists after the first `devenv shell`. A manually
picked interpreter overrides `defaultInterpreterPath` for that workspace.

- **ty** reads `[tool.ty]` in `pyproject.toml`. It does not follow the
  editable venv's `.pth` files (they are `import` lines), so first-party
  code resolves through ty's own roots: `src/` works out of the box;
  workspace members elsewhere go in `[tool.ty.environment] root`. ty is
  beta (0.0.x): each nixpkgs bump may add diagnostics.
- **ruff** uses Astral's default rules (no `select`; add rules with
  `extend-select`) and `requires-python` as its target.

## nixd

The template's nixd settings evaluate nixpkgs with the org overlay, so
hover and completion show org packages (version, description) in every
repo:

```json
"expr": "let f = builtins.getFlake (builtins.toString ./.); in import f.inputs.nixpkgs { overlays = [ f.inputs.org-pkgs.overlays.default ]; }"
```

A package shows its version when it has `pname`/`version`, which
`flakeModules.python` packages always do. The `python.*` perSystem options
show through the `flake-parts-perSystem` options provider.
