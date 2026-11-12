# NixOS VM tests for every org repo: discovered from vm-tests/*.nix and
# built with nixosLib.runTest. Tests live in
# legacyPackages.<system>.vmTests, never in checks: GitHub Actions has no
# KVM and never boots a VM. They run only by hand, through `vm-test`
# (apps.vm-test, devenv script), on a local KVM machine or the remote
# builder. `nix flake check` gets eval-only checks instead: every test
# evaluates, its VMs fit the resource caps, and no check needs KVM.
# A repo whose tests are expensive to evaluate (many large clan suites)
# sets `vmTests.flakeChecks.enable = false`: the eval and resources
# checks then leave `checks` and run by hand with `vm-test --check`;
# the KVM guard always stays.
#
# A repo without a vm-tests/ dir and without vmTests.tests gets only the
# vm-test app (which lists nothing) and no checks or legacyPackages.
_: {
  config,
  lib,
  self,
  inputs,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.vmTests;

  # Regular *.nix files; `_`- and `.`-prefixed files are helpers.
  isTestFile = name: type:
    type
    == "regular"
    && lib.hasSuffix ".nix" name
    && !(lib.hasPrefix "_" name)
    && !(lib.hasPrefix "." name);

  dirTests =
    lib.optionalAttrs (cfg.dir != null && builtins.pathExists cfg.dir)
    (lib.mapAttrs' (file: _: lib.nameValuePair (lib.removeSuffix ".nix" file) (cfg.dir + "/${file}"))
      (lib.filterAttrs isTestFile (builtins.readDir cfg.dir)));

  testModules = dirTests // cfg.tests;
  hasTests = testModules != {};
in {
  key = "external-systems/pkgs#flakeModules.vmTests";

  options.vmTests = {
    dir = mkOption {
      type = types.nullOr types.path;
      default = "${self}/vm-tests";
      defaultText = lib.literalExpression ''"''${self}/vm-tests"'';
      description = ''
        Directory of test files. Every regular `*.nix` file not starting
        with `_` or `.` is one test (a `nixosLib.runTest` module), named
        by its basename. A missing directory means no tests. `null`
        disables discovery.
      '';
    };

    tests = mkOption {
      type = types.attrsOf types.deferredModule;
      default = {};
      description = ''
        Extra tests defined in code, by name: `runTest` modules added to
        the discovered ones (a name here wins over a file of that name).
      '';
    };

    defaults = mkOption {
      type = types.listOf types.deferredModule;
      default = [];
      example = lib.literalExpression "[self.nixosModules.default]";
      description = ''
        NixOS modules applied to every node of every test (the test's
        `defaults`), e.g. the repo's own NixOS modules.
      '';
    };

    specialArgs = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = {};
      description = ''
        Extra arguments for test modules and node modules, on top of
        `self` and `inputs` (always passed).
      '';
    };

    systems = mkOption {
      type = types.listOf types.str;
      default = ["x86_64-linux"];
      description = "Systems the tests are built for.";
    };

    globalTimeout = mkOption {
      type = types.ints.positive;
      default = 30 * 60;
      description = ''
        Default `globalTimeout` (seconds) of every test; a test overrides
        it by setting its own.
      '';
    };

    flakeChecks.enable =
      lib.mkEnableOption ''
        the eval and resources checks in `checks` (and so in `nix flake
        check` and CI). Evaluating every node of every test can take
        minutes and gigabytes; a repo with many large suites turns this
        off and runs the same checks with `vm-test --check`
        (`legacyPackages.<system>.vmTestChecks`). The KVM guard
        (`vm-tests-no-kvm-checks`) is always in `checks`
      ''
      // {default = true;};

    limits = {
      memorySize = mkOption {
        type = types.ints.positive;
        default = 16384;
        description = "Largest `virtualisation.memorySize` (MiB) one VM may ask for.";
      };
      cores = mkOption {
        type = types.ints.positive;
        default = 8;
        description = "Largest `virtualisation.cores` one VM may ask for.";
      };
      totalMemorySize = mkOption {
        type = types.ints.positive;
        default = 24576;
        description = "Largest sum of `virtualisation.memorySize` (MiB) over one test's VMs.";
      };
      totalCores = mkOption {
        type = types.ints.positive;
        default = 16;
        description = ''
          Largest sum of `virtualisation.cores` over one test's VMs. Keep
          it at or below the thread count of the machine that runs the
          tests, so one test never oversubscribes it.
        '';
      };
    };
  };

  config.perSystem = {
    config,
    pkgs,
    system,
    ...
  }: let
    args = {inherit self inputs;} // cfg.specialArgs;
    nixosLib = import (pkgs.path + "/nixos/lib") {inherit lib;};

    mkTest = name: module:
      nixosLib.runTest {
        imports = [module];
        name = lib.mkDefault name;
        hostPkgs = pkgs;
        _module.args = args;
        node.specialArgs = args;
        defaults.imports = cfg.defaults;
        # No TCG fallback: a builder without KVM refuses the job instead
        # of running it emulated for an hour.
        requiredFeatures.kvm = true;
        qemu.forceAccel = true;
        globalTimeout = lib.mkDefault cfg.globalTimeout;
      };

    enabled = hasTests && lib.elem system cfg.systems;
    tests = lib.mapAttrs mkTest testModules;
    names = lib.attrNames testModules;

    # One line per VM over a cap, "" when all fit.
    violationsOf = name: test: let
      vms = lib.mapAttrs (_: node: node.virtualisation) test.nodes;
      sumOf = attr: lib.foldl' (sum: vm: sum + vm.${attr}) 0 (lib.attrValues vms);
      total = sumOf "memorySize";
      totalCores = sumOf "cores";
    in
      lib.concatLists (lib.mapAttrsToList (node: vm:
        lib.optional (vm.memorySize > cfg.limits.memorySize)
        "${name}: node ${node} memorySize ${toString vm.memorySize} MiB > ${toString cfg.limits.memorySize}"
        ++ lib.optional (vm.cores > cfg.limits.cores)
        "${name}: node ${node} cores ${toString vm.cores} > ${toString cfg.limits.cores}")
      vms)
      ++ lib.optional (total > cfg.limits.totalMemorySize)
      "${name}: VMs total ${toString total} MiB > ${toString cfg.limits.totalMemorySize}"
      ++ lib.optional (totalCores > cfg.limits.totalCores)
      "${name}: VMs total ${toString totalCores} cores > ${toString cfg.limits.totalCores}";
    violations = lib.concatLists (lib.mapAttrsToList violationsOf tests);

    failOn = name: env: lines:
      pkgs.runCommand name env (
        if lines == []
        then "touch $out"
        else ''
          echo "VM tests over the resource caps (vmTests.limits):" >&2
          ${lib.concatLines (map (v: "echo ${lib.escapeShellArg "  ${v}"} >&2") lines)}
          exit 1
        ''
      );

    # Eval-only: nothing here boots QEMU or needs KVM. In `checks` unless
    # vmTests.flakeChecks.enable is false; always in legacyPackages for
    # `vm-test --check`. `perTest.<name>` checks one test (evaluates and
    # fits the caps): `vm-test --check` builds them one Nix process at a
    # time, since evaluating every test of a large repo in one process
    # can need tens of GB.
    staticChecks = {
      perTest = lib.mapAttrs (name: test:
        failOn "vm-tests-check-${name}" {
          # In the env so instantiating this check evaluates the whole
          # test; the context is dropped, so the test is never built.
          testDrv = builtins.unsafeDiscardStringContext test.drvPath;
        } (violationsOf name test))
      tests;

      eval = pkgs.writeText "vm-tests-eval" (lib.concatLines (lib.mapAttrsToList
        (name: test: "${name} ${builtins.unsafeDiscardStringContext test.drvPath}")
        tests));

      resources = failOn "vm-tests-resources" {} violations;
    };

    guardName = "vm-tests-no-kvm-checks";
    # Every other check; reading names and drv attrs only, never itself.
    # runTest returns a lazyDerivation that hides requiredSystemFeatures,
    # so a NixOS test is also recognised by its `driver` passthru.
    kvmChecks = lib.attrNames (lib.filterAttrs (_: drv: let
      features = drv.requiredSystemFeatures or drv.drvAttrs.requiredSystemFeatures or [];
    in
      drv ? driver || lib.elem "kvm" features || lib.elem "nixos-test" features) (removeAttrs config.checks [guardName]));

    vm-test = pkgs.writeShellApplication {
      name = "vm-test";
      runtimeInputs = [pkgs.git pkgs.coreutils pkgs.gnugrep pkgs.gnused];
      text = ''
        tests=(${lib.escapeShellArgs names})
        system=${lib.escapeShellArg system}

        usage() {
          cat <<'EOF'
        vm-test: run this repo's NixOS VM tests (legacyPackages.<system>.vmTests).

          vm-test --list
          vm-test <name> [--remote] [--rebuild] [--quiet] [-- <nix build args>]
          vm-test --all  [--serial] [--remote] [--rebuild] [--quiet] [-- <nix build args>]
          vm-test --check [<name>]
          vm-test --summary <name>
          vm-test <name> --driver [--keep-state] [--interactive]

          --list         List the tests.
          <name>         Build the test in the Nix sandbox; the exit code is the result.
          --all          Build every test (vmTestsAll), --keep-going.
          --serial       With --all: build the tests one at a time, each with its
                         own log; for tests too large to run side by side.
          --check        Check that every test (or <name>) evaluates and fits the
                         resource caps, one Nix process per test (vmTestChecks.perTest).
          --remote       Build only on the daemon's remote builders (--max-jobs 0).
          --rebuild      Run a test that already passed again.
          --driver       Run the test driver on this machine, outside the sandbox.
          --keep-state   Driver: keep and reuse VM disk state between runs.
          --interactive  Driver: the Python REPL against live VMs.
          --quiet        Keep the full build log in the file only; print the summary.
          --summary      Print the summary of <name>'s last run again (no build).

        Every build ends with a summary: each subtest, the failures (!!! lines)
        and the first build errors (e.g. the test script linter), also saved
        as summary.txt. Logs and driver output: .vm-tests/<name>/ in the repo root.
        VM tests never run in GitHub Actions or nix flake check.
        EOF
        }

        target="" all=0 serial=0 check=0 remote=0 rebuild=0 driver=0 keep=0 interactive=0 quiet=0 summary=0
        extra=()
        while [ $# -gt 0 ]; do
          case "$1" in
            -h | --help) usage; exit 0 ;;
            --list) printf '%s\n' "''${tests[@]}"; exit 0 ;;
            --all) all=1 ;;
            --serial) serial=1 ;;
            --check) check=1 ;;
            --remote) remote=1 ;;
            --rebuild) rebuild=1 ;;
            --driver) driver=1 ;;
            --keep-state) keep=1 ;;
            --interactive) interactive=1 ;;
            --quiet) quiet=1 ;;
            --summary) summary=1 ;;
            --) shift; extra=("$@"); break ;;
            -*) echo "vm-test: unknown flag $1" >&2; usage >&2; exit 2 ;;
            *) target=$1 ;;
          esac
          shift
        done

        if [ ''${#tests[@]} -eq 0 ]; then
          echo "vm-test: this repo has no VM tests for $system (vm-tests/*.nix)" >&2
          exit 1
        fi
        if [ "$all" = 1 ] && [ -n "$target" ]; then
          echo "vm-test: give a test name or --all, not both" >&2; exit 2
        fi
        if [ "$serial" = 1 ] && [ "$all" = 0 ]; then
          echo "vm-test: --serial needs --all" >&2; exit 2
        fi
        if [ "$check" = 1 ] && [ "$all" = 1 ]; then
          echo "vm-test: --check checks every test already; drop --all" >&2; exit 2
        fi
        if [ "$summary" = 1 ] && [ -z "$target" ]; then
          echo "vm-test: --summary needs a test name" >&2; exit 2
        fi
        if [ "$all" = 0 ] && [ "$check" = 0 ] && [ -z "$target" ]; then
          usage >&2; exit 2
        fi
        if [ -n "$target" ] && ! printf '%s\n' "''${tests[@]}" | grep -qxF -- "$target"; then
          echo "vm-test: no test '$target'; tests: ''${tests[*]}" >&2; exit 2
        fi

        root=$(git rev-parse --show-toplevel)
        flake="$root#legacyPackages.$system"

        # The lines an agent or a human acts on, out of a build or driver
        # log: subtests started, failures, and build errors that stop a
        # test before it boots (the driver's ruff lint, eval errors).
        summarize() {
          local log=$1
          {
            grep -E '(^|> )subtest: ' "$log" | sed -E 's/^vm-test-run-//; s/^/  /' || true
            # Not nix's repeat of the last log lines ("  > ..."): each once.
            grep -E '^(vm-test-run-[^>]*> )?!!! (Test |RequestedAssertionFailed|[A-Za-z]+Error)' "$log" | sed -E 's/^vm-test-run-//' | head -n 20 || true
            grep -E '^error: |^ *> [A-Z]+[0-9]+ ' "$log" | head -n 8 || true
            grep -E 'test script finished in' "$log" | sed -E 's/^vm-test-run-//; s/^/  /' | tail -n 1 || true
          }
        }

        # Build one attr, keep the log, print and save the summary.
        run_build() {
          local name=$1 attr=$2 out=$3
          shift 3
          mkdir -p "$out"
          echo "vm-test: building $attr (log: $out/build.log)" >&2
          set +e
          if [ "$quiet" = 1 ]; then
            nix build "$@" -o "$out/result" "''${extra[@]}" "$attr" > "$out/build.log" 2>&1
            status=$?
          else
            nix build "$@" -o "$out/result" "''${extra[@]}" "$attr" 2>&1 | tee "$out/build.log"
            status=''${PIPESTATUS[0]}
          fi
          set -e
          summarize "$out/build.log" > "$out/summary.txt"
          {
            echo "vm-test: summary of $name ($out/summary.txt)"
            cat "$out/summary.txt"
            if [ "$status" = 0 ]; then echo "vm-test: $name passed"; else echo "vm-test: $name FAILED ($status)"; fi
          } >&2
          return "$status"
        }

        if [ "$summary" = 1 ]; then
          dir="$root/.vm-tests/$target"
          log="$dir/build.log"
          [ -f "$log" ] || log="$dir/driver.log"
          if [ ! -f "$log" ]; then
            echo "vm-test: no log for $target in $dir" >&2; exit 1
          fi
          echo "vm-test: summary of $target ($log)"
          summarize "$log"
          exit 0
        fi

        # One nix process per test: a large repo's tests together can
        # need tens of GB to evaluate in a single process.
        if [ "$check" = 1 ]; then
          checks=("''${tests[@]}")
          [ -n "$target" ] && checks=("$target")
          failed=()
          for t in "''${checks[@]}"; do
            echo "vm-test: checking $t" >&2
            if ! nix build --no-link "''${extra[@]}" "$flake.vmTestChecks.perTest.$t"; then
              failed+=("$t")
            fi
          done
          if [ ''${#failed[@]} -eq 0 ]; then
            echo "vm-test: ''${#checks[@]} tests evaluate and fit the caps" >&2
            exit 0
          fi
          echo "vm-test: ''${#failed[@]} of ''${#checks[@]} FAILED the check: ''${failed[*]}" >&2
          exit 1
        fi

        if [ "$driver" = 1 ]; then
          [ -n "$target" ] || { echo "vm-test: --driver needs a test name" >&2; exit 2; }
          out="$root/.vm-tests/$target"
          mkdir -p "$out"
          # driverInteractive always adds --interactive; plain runs use driver.
          kind=driver
          [ "$interactive" = 1 ] && kind=driverInteractive
          drv=$(nix build --no-link --print-out-paths "$flake.vmTests.$target.$kind")
          flags=(--output_directory "$out" --junit-xml junit.xml)
          [ "$keep" = 1 ] && flags+=(--keep-machine-state)
          echo "vm-test: driver output in $out" >&2
          set +e
          "$drv/bin/nixos-test-driver" "''${flags[@]}" 2>&1 | tee "$out/driver.log"
          status=''${PIPESTATUS[0]}
          set -e
          summarize "$out/driver.log" > "$out/summary.txt"
          { echo "vm-test: summary of $target ($out/summary.txt)"; cat "$out/summary.txt"; } >&2
          exit "$status"
        fi

        build=(-L --keep-going)
        [ "$remote" = 1 ] && build+=(--max-jobs 0)

        # One test at a time: each a separate nix build, so the builder
        # never runs two tests side by side. Keeps going; fails at the end.
        if [ "$serial" = 1 ]; then
          failed=()
          for t in "''${tests[@]}"; do
            args=("''${build[@]}")
            attr="$flake.vmTests.$t"
            if [ "$rebuild" = 1 ] && nix path-info "$attr" >/dev/null 2>&1; then
              args+=(--rebuild)
            fi
            if ! run_build "$t" "$attr" "$root/.vm-tests/$t" "''${args[@]}"; then
              failed+=("$t")
            fi
          done
          if [ ''${#failed[@]} -eq 0 ]; then
            echo "vm-test: all ''${#tests[@]} tests passed" >&2
            exit 0
          fi
          echo "vm-test: ''${#failed[@]} of ''${#tests[@]} FAILED: ''${failed[*]}" >&2
          exit 1
        fi

        if [ "$all" = 1 ]; then
          name=_all attr="$flake.vmTestsAll"
        else
          name=$target attr="$flake.vmTests.$target"
          # --rebuild needs an existing output; on a first run it is a no-op.
          if [ "$rebuild" = 1 ] && nix path-info "$attr" >/dev/null 2>&1; then
            build+=(--rebuild)
          fi
        fi
        status=0
        run_build "$name" "$attr" "$root/.vm-tests/$name" "''${build[@]}" || status=$?
        exit "$status"
      '';
    };
  in {
    apps.vm-test = {
      type = "app";
      program = lib.getExe vm-test;
      meta.description = "Run the repo's NixOS VM tests (locally or on the remote builder)";
    };

    legacyPackages = lib.mkIf enabled {
      vmTests = tests;
      # One target for batch runs: `vm-test --all --remote`.
      vmTestsAll = pkgs.linkFarm "vm-tests-all" tests;
      # `vm-test --check`, whether or not they are also in checks.
      vmTestChecks = staticChecks;
    };

    checks = lib.mkIf enabled (lib.optionalAttrs cfg.flakeChecks.enable {
        vm-tests-eval = staticChecks.eval;
        vm-tests-resources = staticChecks.resources;
      }
      // {
        ${guardName} = pkgs.runCommand guardName {} (
          if kvmChecks == []
          then "touch $out"
          else ''
            echo "checks that need KVM (VM tests belong in legacyPackages.vmTests):" >&2
            ${lib.concatLines (map (c: "echo ${lib.escapeShellArg "  ${c}"} >&2") kvmChecks)}
            exit 1
          ''
        );
      });
  };
}
