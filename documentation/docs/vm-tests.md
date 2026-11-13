# VM tests

`flakeModules.vmTests` (part of `flakeModules.default`) gives every
external-systems repo NixOS VM tests with no wiring: drop a file in
`vm-tests/` and run it with `vm-test`.

!!! warning "Never in CI"
    GitHub Actions has no KVM and never boots a VM: `org-ci.yml` runs
    `nix flake check`, the release and the docs deploy, nothing else.
    VM tests run only by hand, on a local KVM machine or on the remote
    builder. They live in `legacyPackages.<system>.vmTests`, never in
    `checks`.

## Writing a test

One file per test, `vm-tests/<name>.nix`, a `nixosLib.runTest` module.
The attribute name is the file's basename. Files starting with `_` or
`.` are helpers, not tests. `git add` a new file before running it.

```nix
# vm-tests/my-service.nix
{self, ...}: {
  nodes.machine = {
    imports = [self.nixosModules.my-service];
    services.my-service.enable = true;
    # Declare what the test needs; the default is 1024 MiB and 1 core.
    virtualisation = {
      memorySize = 2048;
      cores = 2;
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("my-service.service", timeout=120)
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:8080/healthz", timeout=60)
  '';
}
```

The module sets, for every test:

| Setting | Value |
|---|---|
| `hostPkgs` | the repo's `pkgs` |
| `requiredFeatures.kvm`, `qemu.forceAccel` | `true`: a machine without KVM refuses the job, no slow emulation |
| `globalTimeout` | `vmTests.globalTimeout` (30 min) unless the test sets its own |
| module args | `self`, `inputs` and `vmTests.specialArgs`, in the test module and in every node |
| `defaults` | `vmTests.defaults`, applied to every node |

Tests are hermetic: no network inside the VMs, nothing downloaded at
boot, fake secrets built at build time and passed as files.

## Options

Set at the flake's top level (not in `perSystem`):

```nix
vmTests = {
  defaults = [self.nixosModules.default];   # every node of every test
  specialArgs = {inherit customLib;};       # extra module args
  systems = ["x86_64-linux"];               # default
  tests.extra = ./tests/extra.nix;          # tests defined in code
  limits = {                                # defaults
    memorySize = 16384;                     # MiB, one VM
    cores = 8;                              # one VM
    totalMemorySize = 24576;                # MiB, all VMs of one test
    totalCores = 16;                        # all VMs of one test
  };
  flakeChecks.enable = true;                # eval + resources checks in `checks`
  parallel = {                              # `vm-test --all` budget; defaults:
    cores = 16;                             #   limits.totalCores
    memorySize = 24576;                     #   limits.totalMemorySize (MiB)
    evalJobs = 4;                           # tests evaluated at once, locally
  };
};
```

The default caps fit a 32 GiB, 16-thread machine. A repo whose tests
need more (several clusters in one topology) raises `limits` with the
owner's yes and runs those tests on the remote builder.

`parallel` is what `vm-test --all` may run side by side: the vCPUs and
MiB that the VMs of all running tests declare together. The default is
one test's cap, so `--all` is safe anywhere; a repo that runs on the
remote builder raises it (below the builder's threads and memory, so
the host keeps headroom and tests do not slow each other into timeouts).

`dir` (default `vm-tests/` in the repo root, `null` to disable) sets the
directory scanned for tests.

## Running

Inside the devenv shell (`vm-test`, or `nix run .#vm-test --` anywhere):

| Command | Does |
|---|---|
| `vm-test --list` | list the tests |
| `vm-test <name>` | build the test in the Nix sandbox; the exit code is the result |
| `vm-test <name> --remote` | the same, only on the remote builders (`--max-jobs 0`) |
| `vm-test --all --remote` | run every test on the remote builder, side by side within `vmTests.parallel` (see below) |
| `vm-test --all --serial --remote` | the same, one test at a time |
| `vm-test --check [<name>]` | check that every test (or one) evaluates and fits the caps, one Nix process per test (`legacyPackages.<system>.vmTestChecks.perTest.<name>`) |
| `vm-test <name> --rebuild` | boot a test that already passed again; works with `--remote` and `--all` |
| `vm-test <name> --driver` | run the driver on this machine, outside the sandbox |
| `vm-test <name> --driver --keep-state` | reuse VM disks between runs (fast iteration) |
| `vm-test <name> --driver --interactive` | Python REPL against live VMs |
| `vm-test <name> --quiet` | the full log goes to the file only; the summary is printed |
| `vm-test --summary <name>` | print the summary of `<name>`'s last run again, without building |

Every build and driver run ends with a **summary**: the subtests it
started, the failures (`!!!` lines) and the first build errors, such as
the test-script linter (`F401` for an unused import) or an evaluation
error. It is printed and saved as `.vm-tests/<name>/summary.txt`, so an
agent reads a dozen lines instead of the full `-L` log; the full log
stays in `build.log` (or `driver.log`).

A build that succeeds without booting anything, because the result was
already in the store, is reported as **CACHED** (with the earlier run's
summary when its log is available), never as a fresh pass. `--rebuild`
boots it again: it builds `vmTestsFresh.<name>`, the same test with a
per-run id (read with `--impure`), because Nix never sends a
`nix build --rebuild` to a remote builder.

### `--all`

1. **Prepare**, `parallel.evalJobs` tests at a time: evaluate each test,
   check its caps, read its size and build its driver (the VMs' system
   closures), so the next phase only boots VMs.
2. **Run**, largest first: a test starts when its VMs fit in what is
   left of `parallel.cores` and `parallel.memorySize`, or when nothing
   else runs (a test larger than the budget runs alone). Each test has
   its own `build.log`, `summary.txt` and `result.txt`.
3. **Rerun failures alone.** A test that then passes counts as a pass
   with a warning (`PASS(!)`: it failed under load, so it is
   timing-sensitive; its first log is `build-under-load.log`). A test that
   fails alone fails the run.

The run ends with one line per test: `PASS`, `PASS(!)`, `CACHED` or
`FAIL`, and exits non-zero on any `FAIL`.

Arguments after `--` go to `nix build`. Build logs, the result link and
driver output (`driver.log`, `junit.xml`, screenshots) land in
`.vm-tests/<name>/` in the repo root, which is gitignored.

## What `nix flake check` checks

When a repo has tests, three eval-only checks, safe on any runner:

| Check | Fails when |
|---|---|
| `vm-tests-eval` | a test does not evaluate |
| `vm-tests-resources` | a VM asks for more than `limits.memorySize` MiB or `limits.cores`, or a test's VMs together more than `limits.totalMemorySize` MiB or `limits.totalCores` cores |
| `vm-tests-no-kvm-checks` | any check needs KVM: a VM test put into `checks` |

Evaluating every node of every test can take minutes and several
gigabytes when a repo has many large tests (clan suites of four or five
machines each). Such a repo sets `vmTests.flakeChecks.enable = false`:
`vm-tests-eval` and `vm-tests-resources` leave `checks`, so CI stays
fast, and the same checks run by hand with `vm-test --check` before VM
runs. `--check` evaluates one test per Nix process, so its memory peak
is that of the largest test, not the sum of all of them.
`vm-tests-no-kvm-checks` always stays in `checks`.
