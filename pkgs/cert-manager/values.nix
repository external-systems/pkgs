# Canonical fleet-uniform cert-manager profile (SPEC §5.8). Upstream chart
# defaults hold everywhere except the CRD gate; rendered into
# manifests/cert-manager/<chartVersion>.yaml at update time and consumers
# merge per-cluster variation on top via kubenix module merging — replica
# counts, feature gates, and issuer wiring are all layer-2 and deliberately
# absent here.
{
  # CRDs are a separate atomic artifact (manifests/cert-manager/<chartVersion>-crds.yaml;
  # CRDs-first ordering is the consumer's contract, SPEC D29). The v1.21
  # chart ships CRDs as templates gated by this key (not a crds/ directory),
  # so pin it OFF even though false is the upstream default — a chart bump
  # flipping the default must surface as a reviewed diff.
  crds.enabled = false;
}
