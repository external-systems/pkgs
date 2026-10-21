# Canonical fleet-uniform Envoy Gateway profile (SPEC D2, D26). Rendered
# into manifests/gateway-envoy/<egVersion>.yaml at update time; consumers
# merge per-cluster variation on top via kubenix module merging — the
# DaemonSet data plane and EnvoyProxy resources are layer-2 and deliberately
# absent here. Upstream chart defaults are the profile; only keys that must
# be explicit for the fleet appear below.
{
  # Airgap lock: pin the data-plane image in the rendered EnvoyGateway
  # config so it provably matches the image-envoy tarball this flake ships.
  # The same ref is the controller binary's built-in default, but defaults
  # buried in the binary drift silently on chart bumps — an explicit pin is
  # a reviewed diff. Key verified against the chart's values.yaml
  # (global.images.envoyProxy.image).
  global.images.envoyProxy.image = "docker.io/envoyproxy/envoy:distroless-v1.39.1";
}
