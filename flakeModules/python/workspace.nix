# The org's uv workspace builder: a uv workspace (pyproject.toml + uv.lock)
# as pyproject.nix Python sets and virtualenvs. One plain function shared
# by flakeModules.python (packages, checks, VM test), the devenv module
# org-pkgs/devenv/python (the editable dev venv) and lib.python, so the
# shell, the checks and the shipped package build from one set.
#
# Bound to this flake's uv2nix pins by flake-parts/lib-python.nix:
#   lib.python.mkWorkspace {pkgs; root = ./.; revCount = self.revCount or null;}
#
# Versioning (the org standard): pyproject.toml keeps "<major>.<minor>.0";
# the shipped set stamps the patch with the git commit count, which is the
# org release number (<major>.<minor>.<git rev-list --count HEAD>):
# - the workspace's own projects get `revCount` (the flake's
#   self.revCount; null leaves the pyproject version);
# - git dependencies from the stamped owners (another org repo's Python
#   library, locked by uv) get their own commit count, from the
#   builtins.fetchGit uv2nix runs on the locked rev.
# The stamp rewrites the [project] version in pyproject.toml before the
# build, so the wheel metadata (importlib.metadata) and the store name
# agree. pythonSet stamps git dependencies only, so checks built from it
# do not rebuild on every commit; shipSet also stamps the own projects.
{
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}: {
  pkgs,
  # The workspace root: a path (a flake's self, or an absolute path for
  # the devenv shell).
  root,
  # Commit count for the own projects' patch version; null keeps X.Y.0.
  revCount ? null,
  # Fixups uv.lock cannot express: an overlay, or a path to a file
  # `{pkgs}: final: prev: {...}`. Default: flake-parts/_python/overrides.nix
  # when the workspace has one.
  overrides ? null,
  # Editable root for devVenv: an absolute, non-store path string. null:
  # no editable set (devVenv is then the plain test venv).
  editableRoot ? null,
  sourcePreference ? "wheel",
  # Interpreter; default the first nixpkgs Python inside requires-python.
  python ? null,
  # GitHub owners whose git dependencies follow the org versioning.
  stampOwners ? ["external-systems" "andrewthomaslee"],
}: let
  inherit (pkgs) lib;

  workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = root;};
  lock = lib.importTOML (root + "/uv.lock");
  rootPyproject = lib.importTOML (root + "/pyproject.toml");

  # Workspace members uv builds (editable sources in the lock), by name ->
  # directory relative to the root. Virtual members are not packages.
  projects =
    lib.listToAttrs (map (p: lib.nameValuePair p.name p.source.editable)
      (lib.filter (p: p.source ? editable) lock.package));
  projectPyproject = name: lib.importTOML (root + "/${projects.${name}}/pyproject.toml");

  # Git dependencies by name, from the lock (static names: deciding from
  # the derivations would recurse through the overlay).
  ownerOf = url: let
    m = builtins.match "(git\\+)?(https|ssh)://(git@)?github\\.com[/:]([^/]+)/.*" url;
  in
    if m == null
    then null
    else lib.elemAt m 3;
  gitDeps = map (p: p.name) (lib.filter (p:
    p.source ? git && lib.elem (ownerOf p.source.git) stampOwners)
  lock.package);

  interpreter =
    if python != null
    then python
    else
      lib.head (pyproject-nix.lib.util.filterPythonInterpreters {
        inherit (workspace) requires-python;
        inherit (pkgs) pythonInterpreters;
      });

  overridesFile = root + "/flake-parts/_python/overrides.nix";
  overridesOverlay =
    if overrides == null
    then
      if builtins.pathExists overridesFile
      then import overridesFile {inherit pkgs;}
      else _: _: {}
    else if builtins.isPath overrides || builtins.isString overrides
    then import overrides {inherit pkgs;}
    else overrides;

  # X.Y of a version, the patch replaced by `count`.
  stampVersion = version: count: let
    parts = lib.splitVersion version;
  in
    if lib.length parts < 2
    then throw "python: cannot stamp version ${version}: expected <major>.<minor>.<patch>"
    else "${lib.elemAt parts 0}.${lib.elemAt parts 1}.${toString count}";

  # Rewrite the first `version = "..."` inside [project] of the package's
  # own pyproject.toml (the source root), then build as usual.
  stamp = count: drv:
    drv.overrideAttrs (old: let
      version = stampVersion old.version count;
    in {
      # Same source, new version: `src` restated so nixpkgs does not warn
      # that the version changed without it.
      inherit version;
      inherit (old) src;
      passthru = (old.passthru or {}) // {unstampedVersion = old.version;};
      postPatch =
        (old.postPatch or "")
        + ''
          ${interpreter.interpreter} - <<'PY'
          import pathlib, re
          p = pathlib.Path("pyproject.toml")
          t, n = re.subn(r'(?ms)(^\[project\]\s*$.*?^version\s*=\s*")[^"]*(")', r"\g<1>${version}\g<2>", p.read_text(), count=1)
          assert n == 1, "no [project] version in pyproject.toml"
          p.write_text(t)
          PY
        '';
    });

  stampGitDeps = _final: prev:
    lib.genAttrs (lib.filter (name: prev ? ${name}) gitDeps) (name:
      if prev.${name}.src ? revCount
      then stamp prev.${name}.src.revCount prev.${name}
      else prev.${name});

  stampOwn = _final: prev:
    lib.optionalAttrs (revCount != null)
    (lib.genAttrs (lib.filter (name: prev ? ${name}) (lib.attrNames projects))
      (name: stamp revCount prev.${name}));

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {python = interpreter;}).overrideScope
    (lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay {inherit sourcePreference;})
      stampGitDeps
      overridesOverlay
    ]);

  shipSet = pythonSet.overrideScope stampOwn;

  # Editable members built from the files an editable build reads: their
  # pyproject.toml, readme/licence files and every __init__.py under src/.
  # Python edits then rebuild nothing; only metadata changes do.
  editableSrc = name: let
    dir = root + "/${projects.${name}}";
    topFiles =
      lib.filter (f: builtins.match "(README|LICEN[CS]E|COPYING|NOTICE).*" f != null)
      (lib.attrNames (lib.filterAttrs (_: t: t == "regular") (builtins.readDir dir)));
  in
    lib.fileset.toSource {
      root = dir;
      fileset = lib.fileset.unions (
        [(dir + "/pyproject.toml")]
        ++ map (f: dir + "/${f}") topFiles
        ++ lib.optional (builtins.pathExists (dir + "/src"))
        (lib.fileset.fileFilter (f: f.name == "__init__.py" || f.name == "py.typed") (dir + "/src"))
      );
    };
  editableSet =
    if editableRoot == null
    then null
    else
      pythonSet.overrideScope (lib.composeManyExtensions [
        (workspace.mkEditablePyprojectOverlay {root = editableRoot;})
        (_final: prev:
          lib.genAttrs (lib.filter (name: prev ? ${name} && builtins.pathExists (root + "/${projects.${name}}/src")) (lib.attrNames projects))
          (name: prev.${name}.overrideAttrs {src = editableSrc name;}))
      ]);

  name = rootPyproject.project.name or (baseNameOf (toString root));
in {
  inherit workspace lock projects projectPyproject interpreter pythonSet shipSet editableSet stamp gitDeps;
  python = interpreter;
  # The shipped runtime (default dependencies), stamped.
  venv = shipSet.mkVirtualEnv "${name}-env" workspace.deps.default;
  # Every extra and group (pytest, ...): for checks.
  testVenv = pythonSet.mkVirtualEnv "${name}-test-env" workspace.deps.all;
  # The devenv shell's venv: editable when editableRoot is set.
  devVenv =
    (
      if editableSet == null
      then pythonSet
      else editableSet
    ).mkVirtualEnv "${name}-dev-env"
    workspace.deps.all;
}
