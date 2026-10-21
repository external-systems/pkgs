# Cilium component pin (SPEC §5.4/D26). The canonical fleet-uniform profile
# lives in values.nix; per-cluster variation is the consumer's layer-2
# kubenix module merging, never values here.
{
  chartVersion = "1.20.3";
  chartUrl = "https://helm.cilium.io/cilium-1.20.3.tgz";
  chartHash = "sha256-CAWlJzEYxDbJdyu5Vm2H7FWNiyXMLOXcMpGOzdNvLHw=";

  # Kubernetes minors the pinned Cilium supports (upstream support matrix
  # for the 1.20 series). checks.support-window warns when a pinned distro
  # minor is not listed (SPEC D34).
  k8sMinors = ["1.33" "1.34" "1.35" "1.36" "1.37"];
}
