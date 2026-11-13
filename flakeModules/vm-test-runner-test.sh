#!/usr/bin/env bash
# The expect conditions are eval strings, expanded when checked (SC2016);
# run() sets status for them (SC2034).
# shellcheck disable=SC2016,SC2034
# Self-test of the vm-test runner (checks.vm-test-runner, enabled by
# vmTests.runnerSelfTest.enable): runs a runner built for two stub tests,
# "big" (3 vCPUs) and "small" (1 vCPU), budget 4 vCPUs, against a fake
# `nix` that plays scripted outcomes. No VM, no network, no KVM.
# $RUNNER is the runner's bin/vm-test.
set -euo pipefail
out_path=$out

stub=$PWD/stub
repo=$PWD/repo
mkdir -p "$stub/bin" "$repo"
git -C "$repo" init -q
cd "$repo"

# The fake nix. Per test: $stub/plan-<t> holds outcomes (pass, fail,
# cached), one consumed per test build; $stub/prepfail-<t> holds how many
# preparations of it fail first; $stub/runs-<t> counts test builds;
# $stub/attrs logs every built attribute.
cat > "$stub/bin/nix" <<EOF
#!$BASH
stub=$stub
EOF
cat >> "$stub/bin/nix" <<'EOF'
case "$1" in log | path-info) exit 1 ;; esac
attr=${!#}
echo "$*" >> "$stub/attrs"
if [[ " $* " == *" --print-out-paths "* ]]; then
  for a in "$@"; do
    case "$a" in
      *vmTestChecks.perTest.*)
        t=${a##*.}
        n=$(cat "$stub/prepfail-$t" 2>/dev/null || echo 0)
        if [ "$n" -gt 0 ]; then
          echo $((n - 1)) > "$stub/prepfail-$t"
          echo "error: failed to start SSH connection to 'builder'" >&2
          exit 1
        fi
        echo "$stub/x-vm-tests-check-$t" ;;
    esac
  done
  exit 0
fi
t=${attr##*.}
echo $(($(cat "$stub/runs-$t" 2>/dev/null || echo 0) + 1)) > "$stub/runs-$t"
plan=$(cat "$stub/plan-$t" 2>/dev/null || echo pass)
outcome=${plan%% *}
[ "$plan" = "$outcome" ] || echo "${plan#* }" > "$stub/plan-$t"
sleep 1
case "$outcome" in
  pass) echo "vm-test-run-$t> subtest: phase one"; echo "vm-test-run-$t> test script finished in 1.00s" ;;
  fail) echo "vm-test-run-$t> !!! Test \"phase one\" failed with error: timeout"; exit 1 ;;
  cached) : ;;
esac
EOF
chmod +x "$stub/bin/nix"
printf '1 3072 3 /nix/store/big-test.drv\n' > "$stub/x-vm-tests-check-big"
printf '1 1024 1 /nix/store/small-test.drv\n' > "$stub/x-vm-tests-check-small"
export PATH=$stub/bin:$PATH

fails=0
reset() {
  rm -rf "$stub"/plan-* "$stub"/prepfail-* "$stub"/runs-* "$stub/attrs" .vm-tests
  [ $# -gt 0 ] && echo "$1" > "$stub/plan-big"
  [ $# -gt 1 ] && echo "$2" > "$stub/plan-small"
  return 0
}
run() {
  set +e
  out=$("$RUNNER" "$@" 2>&1)
  status=$?
  set -e
}
expect() { # expect <case> <condition...>
  local name=$1
  shift
  if "$@"; then echo "ok   $name"; else
    echo "FAIL $name"
    printf '%s\n' "$out" | sed 's/^/     | /'
    fails=$((fails + 1))
  fi
}
has() { printf '%s\n' "$out" | grep -E -- "$1" > /dev/null; }
runs() { [ "$(cat "$stub/runs-$1" 2>/dev/null || echo 0)" = "$2" ]; }

reset pass pass
run --all
expect "both pass, side by side" eval 'has "PASS +big" && has "PASS +small" && [ $status = 0 ]'
expect "result.txt records the test drv" grep -F "passed" .vm-tests/big/result.txt
expect "result.txt records the test drv (path)" grep -F "/nix/store/big-test.drv" .vm-tests/big/result.txt

reset "fail pass" pass
run --all
expect "fails under load, passes alone: PASS(!)" eval 'has "PASS\(!\) +big" && [ $status = 0 ] && runs big 2'
expect "PASS(!) warns in the summary" grep -F "WARNING" .vm-tests/big/summary.txt

reset "fail fail" pass
run --all
expect "fails alone too: FAIL" eval 'has "FAIL +big \(also alone\)" && [ $status = 1 ]'

reset fail pass
run --all --serial
expect "failed while alone: no rerun" eval 'has "FAIL +big \(ran alone\)" && [ $status = 1 ] && runs big 1'

reset pass pass
echo 1 > "$stub/prepfail-small"
run --all
expect "failed preparation retried alone" eval 'has "preparing small again, alone" && has "PASS +small" && [ $status = 0 ]'

reset pass pass
echo 2 > "$stub/prepfail-small"
run --all
expect "preparation failing twice: FAIL (preparation)" eval 'has "FAIL +small \(preparation\)" && [ $status = 1 ]'

reset cached pass
run --all
expect "booted nothing: CACHED" eval 'has "CACHED +big" && [ $status = 0 ]'

reset cached
run big
expect "single test CACHED, not passed" eval 'has "passed earlier \(CACHED" && grep -F CACHED .vm-tests/big/summary.txt > /dev/null'
run --summary big
expect "--summary reprints it" has "CACHED"

reset pass fail
run --all
rm -f "$stub"/runs-*
echo pass > "$stub/plan-small"
run --all --resume
expect "--resume skips the passed test, runs the failed one" eval 'has "PASS +big .*--resume" && runs big 0 && runs small 1 && [ $status = 0 ]'
sed -i 's#/nix/store/big-test.drv#/nix/store/other.drv#' "$stub/x-vm-tests-check-big"
run --all --resume
expect "--resume reruns a test whose drv changed" eval 'runs big 1'
sed -i 's#/nix/store/other.drv#/nix/store/big-test.drv#' "$stub/x-vm-tests-check-big"

reset pass
run big --rebuild --remote
expect "--rebuild builds vmTestsFresh, --impure, remote" eval 'grep -E -- "--impure" "$stub/attrs" | grep -E -- "--max-jobs 0" | grep -F "vmTestsFresh.big" > /dev/null'

run big --resume
expect "--resume needs --all" eval '[ $status = 2 ]'

[ "$fails" = 0 ] || { echo "$fails runner self-test case(s) failed" >&2; exit 1; }
touch "$out_path"
