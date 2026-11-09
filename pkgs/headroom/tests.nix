# Smoke tests for one headroom profile, offline in the build sandbox.
{
  lib,
  runCommand,
  cacert,
  curl,
  jq,
  headroom,
}: let
  exe = lib.getExe headroom;
in {
  help = runCommand "${headroom.pname}-help" {} ''
    ${exe} --help > $out
    grep -q proxy $out
  '';

  # Start the proxy and poll /health. Kompress downloads its model from
  # huggingface.co, and telemetry phones home: both off, the sandbox has
  # no network. The sandbox points SSL_CERT_FILE at a missing file, which
  # httpx loads eagerly: give it a real bundle. Overall status stays
  # "unhealthy" offline (the upstream check cannot resolve DNS), so assert
  # the proxy's own startup, its Rust core and the version instead.
  proxy = runCommand "${headroom.pname}-proxy" {nativeBuildInputs = [curl jq];} ''
    export HOME=$TMPDIR HEADROOM_BEACON=off HEADROOM_UPDATE_CHECK=off HF_HUB_OFFLINE=1
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    ${exe} proxy --stateless --disable-kompress --host 127.0.0.1 --port 18787 > proxy.log 2>&1 &
    pid=$!
    for _ in $(seq 120); do
      if curl -sf http://127.0.0.1:18787/health > health.json; then break; fi
      if ! kill -0 $pid 2>/dev/null; then cat proxy.log; exit 1; fi
      sleep 1
    done
    kill $pid
    cat proxy.log health.json
    jq -e '.checks.startup.ready and .rust_core == "loaded" and .version == "${headroom.version}"' health.json
    cp health.json $out
  '';
}
