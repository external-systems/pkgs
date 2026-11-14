# Python repos on uv2nix, by convention: a repo with pyproject.toml and
# uv.lock at its root gets, with no Nix of its own,
#   packages.<project> / .default   each workspace project, wrapped:
#                                   its [project.scripts] (or a venv for
#                                   a library), version <major>.<minor>.
#                                   <commit count> (self.revCount)
#   packages.<project>-venv         the shipped virtualenv
#   apps.<script>                   every [project.scripts] entry
#   checks.python-pytest            pytest on the installed package (tests/)
#   checks.python-ty                ty check, warnings fail
#   checks.python-uv-lock           uv.lock matches pyproject.toml
#   checks.python-version           pyproject <major>.<minor> = ci.yml's
#   checks.python-<name>            python.checks.<name> scripts
#   treefmt ruff-check + ruff-format (fmt, checks.treefmt)
#   vmTests.python-cli              every script --version/--help in a VM
#   legacyPackages.python           the sets and venvs, for inspection
# The builder is ./python/workspace.nix (also lib.python.mkWorkspace and
# the devenv module org-pkgs/devenv/python), bound to THIS flake's uv2nix
# pins: a Python repo declares no uv2nix input. Lazy: a repo without
# pyproject.toml never fetches uv2nix.
{orgInputs}: {
  config,
  lib,
  self,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.python;
  root = self;
  has = file: builtins.pathExists "${root}/${file}";
  mkWorkspace = import ./python/workspace.nix {
    inherit (orgInputs) uv2nix pyproject-nix pyproject-build-systems;
  };

  # Static facts from the TOML files (no pkgs needed): project names and
  # their scripts, for apps and the VM test.
  lock = lib.importTOML "${root}/uv.lock";
  projects =
    lib.listToAttrs (map (p: lib.nameValuePair p.name p.source.editable)
      (lib.filter (p: p.source ? editable) lock.package));
  pyprojectOf = name: lib.importTOML "${root}/${projects.${name}}/pyproject.toml";
  scriptsOf = name: lib.attrNames ((pyprojectOf name).project.scripts or {});
  rootName = (lib.importTOML "${root}/pyproject.toml").project.name or null;
  mainProject =
    if rootName != null && projects ? ${rootName}
    then rootName
    else lib.head (lib.attrNames projects);
  cliProjects = lib.filter (name: scriptsOf name != []) (lib.attrNames projects);
in {
  key = "external-systems/pkgs#flakeModules.python";
  imports = [
    (import ./treefmt.nix {inherit orgInputs;})
    (import ./vm-tests.nix {inherit orgInputs;})
  ];

  options.python = {
    enable = mkOption {
      type = types.bool;
      default = has "pyproject.toml" && has "uv.lock";
      defaultText = lib.literalMD "`true` when pyproject.toml and uv.lock are at the repo root";
      description = "Build the uv workspace at the repo root with uv2nix.";
    };
    vmTest.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Add vmTests.python-cli: installs every package with scripts on an
        offline VM and runs each script with --version (expecting
        `<project> <version>`) and --help as a normal user.
      '';
    };
  };

  config.vmTests.tests = lib.mkIf (cfg.enable && cfg.vmTest.enable && cliProjects != []) {
    python-cli = {hostPkgs, ...}: let
      packages = map (name: self.packages.${hostPkgs.stdenv.hostPlatform.system}.${name}) cliProjects;
      scripts = lib.concatMap (name:
        map (s: {
          project = name;
          script = s;
        }) (scriptsOf name))
      cliProjects;
    in {
      nodes.machine = {
        environment.systemPackages = packages;
        users.users.alice = {
          isNormalUser = true;
          uid = 1000;
        };
      };
      testScript = ''
        import re
        start_all()
        machine.wait_for_unit("multi-user.target", timeout=300)
        for project, script in ${builtins.toJSON (map (s: [s.project s.script]) scripts)}:
            with subtest(f"{script} --version and --help"):
                out = machine.succeed(f"su - alice -c '{script} --version'").strip()
                assert re.fullmatch(rf"{re.escape(project)} \d+\.\d+\.\d+", out), (script, out)
                machine.succeed(f"su - alice -c '{script} --help' >/dev/null")
      '';
    };
  };

  config.perSystem = {
    config,
    pkgs,
    ...
  }: let
    pcfg = config.python;
    ws = mkWorkspace {
      inherit pkgs root;
      inherit (pcfg) overrides python;
      revCount = self.revCount or null;
    };
    inherit (pkgs.callPackages orgInputs.pyproject-nix.build.util {}) mkApplication;

    # Each project: its scripts wrapped with makeWrapper (not
    # wrapProgram, so Typer/click usage lines show the real command), or
    # a venv for a library. pname/version/meta for nixd and consumers.
    package = name: let
      drv = ws.shipSet.${name};
      project = (pyprojectOf name).project or {};
      venv = ws.shipSet.mkVirtualEnv "${name}-env" {${name} = [];};
      app = mkApplication {
        inherit venv;
        package = drv;
      };
      scripts = scriptsOf name;
      urls = project.urls or {};
    in
      if scripts == []
      then venv
      else
        pkgs.runCommand "${name}-${drv.version}" {
          pname = name;
          inherit (drv) version;
          nativeBuildInputs = [pkgs.makeWrapper];
          passthru = {
            inherit app venv scripts;
            python = drv;
          };
          meta =
            {
              description = project.description or name;
              platforms = lib.platforms.unix;
            }
            // lib.optionalAttrs (lib.length scripts == 1) {mainProgram = lib.head scripts;}
            // lib.optionalAttrs (urls != {}) {
              homepage = urls.Homepage or urls.homepage or urls.Repository or urls.repository or (lib.head (lib.attrValues urls));
            };
        } ''
          mkdir -p $out/bin
          for s in ${lib.escapeShellArgs scripts}; do
            makeWrapper ${app}/bin/$s $out/bin/$s ${lib.optionalString (pcfg.runtimeInputs != []) "--suffix PATH : ${lib.makeBinPath pcfg.runtimeInputs}"}
          done
        '';
    packages = lib.genAttrs (lib.attrNames projects) package;

    # Only what the checks read, so docs or Nix edits do not rerun them.
    # (builtins.path, not lib.fileset: self is a store path string.)
    checkTops =
      ["pyproject.toml" "uv.lock" "README.md" "LICENSE" "src" "tests"]
      ++ lib.filter (d: d != ".") (lib.attrValues projects);
    checkSrc = builtins.path {
      name = "python-check-src";
      path = root;
      filter = path: _: let
        rel = lib.removePrefix "${toString root}/" (toString path);
      in
        lib.any (top: rel == top || lib.hasPrefix "${top}/" rel || lib.hasPrefix "${rel}/" top) checkTops;
    };
    pyCheck = name: script:
      pkgs.runCommand "python-${name}" {
        nativeBuildInputs = [ws.testVenv] ++ pcfg.runtimeInputs ++ pcfg.checkInputs;
      } ''
        cp -r ${checkSrc}/. src && chmod -R u+w src && cd src
        export HOME=$TMPDIR
        ${script}
        touch $out
      '';

    # pyproject <major>.<minor> must equal ci.yml's major/minor (the
    # release number is <major>.<minor>.<commit count>).
    ciFile = "${root}/.github/workflows/ci.yml";
    ciField = field: let
      m =
        lib.findFirst (x: x != null) null (map (builtins.match "[[:space:]]*${field}:[[:space:]]*([0-9]+).*")
          (lib.splitString "\n" (builtins.readFile ciFile)));
    in
      if m == null
      then null
      else lib.head m;
    pyVersion = lib.splitVersion (pyprojectOf mainProject).project.version;
    versionCheck = pkgs.runCommand "python-version" {} (
      if !(builtins.pathExists ciFile)
      then "echo 'no .github/workflows/ci.yml: nothing to compare'; touch $out"
      else let
        want = "${toString (ciField "major")}.${toString (ciField "minor")}";
        got = "${lib.elemAt pyVersion 0}.${lib.elemAt pyVersion 1}";
      in
        if want == got && lib.elemAt pyVersion 2 == "0"
        then "touch $out"
        else ''
          echo "pyproject.toml version ${lib.concatStringsSep "." pyVersion}: want ${want}.0 (ci.yml major.minor; the patch is the commit count, stamped at build time)" >&2
          exit 1
        ''
    );
  in {
    options.python = {
      runtimeInputs = mkOption {
        type = types.listOf types.package;
        default = [];
        example = lib.literalExpression "[pkgs.gum pkgs.mpv]";
        description = ''
          Programs the scripts exec, appended to their PATH (a user's own
          copy wins). Also on PATH in the checks.
        '';
      };
      checkInputs = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "Extra programs on PATH in the Python checks only.";
      };
      checks = mkOption {
        type = types.attrsOf types.lines;
        default = {};
        example = {mypy-stubs = "python -m mypy src";};
        description = ''
          Extra checks.python-<name>: shell scripts run in a writable copy
          of the Python sources with the test venv (every group) on PATH.
        '';
      };
      overrides = mkOption {
        type = types.nullOr (types.either types.path (types.functionTo (types.functionTo types.attrs)));
        default = null;
        description = ''
          Fixups uv.lock cannot express (native libraries, sdist build
          systems): an overlay over the Python set, or a path to
          `{pkgs}: final: prev: {...}`. Default:
          flake-parts/_python/overrides.nix when present.
        '';
      };
      python = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "Interpreter; default the first nixpkgs Python inside requires-python.";
      };
      ty.args = mkOption {
        type = types.listOf types.str;
        default = ["--error-on-warning"];
        description = "Extra `ty check` arguments; drop --error-on-warning to let warnings pass.";
      };
      workspace = mkOption {
        type = types.raw;
        readOnly = true;
        description = "The built workspace (lib.python.mkWorkspace result).";
      };
    };

    config = lib.mkIf cfg.enable {
      python.workspace = ws;

      # mkDefault: a repo that defines one of these itself wins.
      packages = lib.mapAttrs (_: lib.mkDefault) (
        packages
        // {default = packages.${mainProject};}
        // lib.mapAttrs' (name: _: lib.nameValuePair "${name}-venv" (packages.${name}.passthru.venv or packages.${name})) projects
      );

      apps = lib.mapAttrs (_: lib.mkDefault) (lib.listToAttrs (lib.concatMap (name:
        map (s:
          lib.nameValuePair s {
            type = "app";
            program = "${packages.${name}}/bin/${s}";
            meta.description = "Run ${s} from ${name}";
          }) (scriptsOf name))
      cliProjects));

      checks =
        {
          python-ty = pyCheck "ty" ''
            ${lib.getExe pkgs.ty} check --python ${ws.testVenv} --no-progress --output-format concise ${lib.escapeShellArgs pcfg.ty.args}
          '';
          # uv2nix builds a stale lock without complaint, silently missing
          # new dependencies.
          python-uv-lock = pkgs.runCommand "python-uv-lock" {nativeBuildInputs = [pkgs.uv];} ''
            cp -r ${checkSrc}/. . && chmod -R u+w .
            export HOME=$TMPDIR UV_NO_CACHE=1 UV_PYTHON_DOWNLOADS=never
            uv lock --check --offline --python ${ws.python.interpreter}
            touch $out
          '';
          python-version = versionCheck;
        }
        // lib.optionalAttrs (has "tests") {
          # Tests the installed package (not editable): what ships.
          python-pytest = pyCheck "pytest" "pytest -p no:cacheprovider tests";
        }
        // lib.mapAttrs' (name: script: lib.nameValuePair "python-${name}" (pyCheck name script)) pcfg.checks;

      # Ruff: Astral's default rules, lint (with safe fixes) before format.
      treefmt.programs = {
        ruff-check = {
          enable = true;
          priority = 1;
        };
        ruff-format = {
          enable = true;
          priority = 2;
        };
      };

      legacyPackages.python = {inherit (ws) pythonSet shipSet venv testVenv;};
    };
  };
}
