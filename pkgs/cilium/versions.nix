# Cilium component pin (SPEC §5.4/D26). The canonical fleet-uniform profile
# lives in values.nix; per-cluster variation is the consumer's layer-2
# kubenix module merging, never values here.
{
  chartVersion = "1.20.3";
  chartUrl = "https://helm.cilium.io/cilium-1.20.3.tgz";
  chartHash = "sha256-CAWlJzEYxDbJdyu5Vm2H7FWNiyXMLOXcMpGOzdNvLHw=";

  # Kubernetes minors the pinned Cilium supports (upstream support matrix
  # for the 1.20 series). The D34 support-window gate — an eval warning in
  # flake-parts/lib.nix (componentSupport), never a check — warns when a
  # pinned distro minor is not listed.
  k8sMinors = ["1.33" "1.34" "1.35" "1.36" "1.37"];

  # Airgap image set: every container image the committed manifest
  # (manifests/cilium/<chartVersion>.yaml) references, digest-pinned exactly
  # as rendered there (checks.cilium-airgap-completeness enforces coverage).
  # `sha256` pins the dockerTools.pullImage output; refresh via the
  # placeholder-hash build dance when bumping.
  images = [
    {
      name = "agent";
      repo = "quay.io/cilium/cilium";
      tag = "v1.20.3";
      digest = "sha256:95cfa5c2427cc6b452c00908778d0566311f572589284af949d06a013db1a849";
      sha256 = "sha256-Gc4dLyAffosj0E8cUP5ZybjUwYrdCoeMW+9xPMlTDhA=";
    }
    {
      name = "envoy";
      repo = "quay.io/cilium/cilium-envoy";
      tag = "v1.38.6-1791537840-00e749f11f69334c625e53fc1ce2fc6c7f34a51f";
      digest = "sha256:d6c8c0c91954d1885026d82a31b341f37dcd34a4b127fdaf1587e43ddd224cef";
      sha256 = "sha256-/wc4KCXl3r6QbJcmwOJQH9UGELTl/F8wNcwBYFN0JL4=";
    }
    {
      name = "operator";
      repo = "quay.io/cilium/operator-generic";
      tag = "v1.20.3";
      digest = "sha256:efdd8d89d6d8f63d21a065fa2f9e17614a2b3ac9371b221af9355f63829e2dbc";
      sha256 = "sha256-xeDBGVmAk5pywcS89NekocAq6kOjj3fj9ubVJ4et9Gg=";
    }
    {
      name = "clustermesh-apiserver";
      repo = "quay.io/cilium/clustermesh-apiserver";
      tag = "v1.20.3";
      digest = "sha256:5c8dca0d0b77bb593df157be39f6c9c868dc08922bbd0540ac0a56815341b227";
      sha256 = "sha256-O3O4BtvbdjGozMhS/sp3Cx3IY1xqQmr52nPwhC1p1RQ=";
    }
  ];
}
