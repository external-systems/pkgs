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
};
```

The default caps fit a 32 GiB, 16-thread machine. A repo whose tests
need more (several clusters in one topology) raises `limits` with the
owner's yes and runs those tests on the remote builder, one at a time
(`vm-test --all --serial --remote`).

`dir` (default `vm-tests/` in the repo root, `null` to disable) sets the
directory scanned for tests.

## Running

Inside the devenv shell (`vm-test`, or `nix run .#vm-test --` anywhere):

| Command | Does |
|---|---|
| `vm-test --list` | list the tests |
| `vm-test <name>` | build the test in the Nix sandbox; the exit code is the result |
| `vm-test <name> --remote` | the same, only on the remote builders (`--max-jobs 0`) |
| `vm-test --all --remote` | build every test (`vmTestsAll`) on the remote builder, `--keep-going` |
| `vm-test --all --serial --remote` | build every test one at a time, each with its own log; for tests too large to run side by side |
| `vm-test --check [<name>]` | check that every test (or one) evaluates and fits the caps, one Nix process per test (`legacyPackages.<system>.vmTestChecks.perTest.<name>`) |
| `vm-test <name> --rebuild` | run a test that already passed again |
| `vm-test <name> --driver` | run the driver on this machine, outside the sandbox |
| `vm-test <name> --driver --keep-state` | reuse VM disks between runs (fast iteration) |
| `vm-test <name> --driver --interactive` | Python REPL against live VMs |

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
