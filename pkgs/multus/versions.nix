# Multus CNI component pin (SPEC §6). Upstream ships the thick-plugin
# daemonset as a ready-to-apply manifest rather than a helm chart, so the
# pinned artifact is the rendered YAML itself.
rec {
  version = "4.3.1";
  url = "https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/v${version}/deployments/multus-daemonset-thick.yml";
  hash = "sha256-JPspUwt2DSgSa7p2vZH6yP10EAtT2fxllDwiPjqCvjA=";
}
