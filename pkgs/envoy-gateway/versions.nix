# Envoy Gateway component pin (SPEC D2/D26). The canonical fleet-uniform
# profile lives in values.nix; per-cluster variation (DaemonSet data plane,
# EnvoyProxy resources) is the consumer's layer-2 kubenix module merging,
# never values here.
{
  egVersion = "v1.9.2";
  chartRef = "oci://docker.io/envoyproxy/gateway-helm:v1.9.2";
  chartHash = "sha256-EHnK0AngiF9uEOX3EiV9jl/a+RHSzrP6G3hjLI8pu/k=";

  # Gateway API bundle the pinned EG supports, per the chart's bundled
  # gatewayapi-crds.yaml (gateway.networking.k8s.io/bundle-version). The
  # standard + experimental install manifests are separate atomic artifacts
  # because the chart only bundles the experimental channel (SPEC D2).
  gatewayApi = {
    version = "v1.6.1";
    standardUrl = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml";
    standardHash = "sha256-JNkx8iq9jkDJcyZDGerXz6CdD7dxa3qx7i/xdMsGOnM=";
    experimentalUrl = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/experimental-install.yaml";
    experimentalHash = "sha256-1/p3ZQ5O8o/KBBFTb8teI33rTVAwHP3tO+Sdmht7vQI=";
  };

  # Data-plane image the pinned EG deploys by default
  # (api/v1alpha1/shared_types.go DefaultEnvoyProxyImage at v1.9.2). digest
  # is the linux/amd64 image manifest resolved from the upstream-pinned
  # manifest list; archiveHash pins the dockerTools.pullImage tarball
  # (placeholder-hash dance).
  envoyImage = {
    repo = "docker.io/envoyproxy/envoy";
    tag = "distroless-v1.39.1";
    digest = "sha256:9c9ca6bef1e4e355b00b4657cbe123baf3b4a78613cb949b6cbabaab897a6c28";
    archiveHash = "sha256-aAUm1bq+ArUpPQaY9Q87UO/I3GA3yw2raSIoVfdJCuI=";
  };

  # Kubernetes minors the pinned EG supports (EG 1.9 support matrix, SPEC
  # §10). checks.support-window warns when a pinned distro minor is not
  # listed (SPEC D34).
  k8sMinors = ["1.33" "1.34" "1.35" "1.36"];
}
