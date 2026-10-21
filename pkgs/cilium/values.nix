# Canonical fleet-uniform Cilium profile (SPEC §5.4, D1, D26). Rendered into
# manifests/cilium/<chartVersion>.yaml at update time; consumers merge
# per-cluster variation on top via kubenix module merging — cluster name/id,
# k8sServiceHost/Port, devices, MTU, nodeIPAM, CiliumPodIPPool CIDRs, and
# clustermesh peers are all layer-2 and deliberately absent here.
{
  kubeProxyReplacement = true;

  routingMode = "tunnel";
  tunnelProtocol = "vxlan";
  # Native-routing CIDRs are inert under tunnel mode but pinned so a future
  # mode flip is a reviewed diff.
  ipv4NativeRoutingCIDR = "10.0.0.0/8";
  ipv6NativeRoutingCIDR = "fd10::/16";

  ipam.mode = "multi-pool";

  # Dual-stack inside, always (invariant 2).
  ipv4.enabled = true;
  ipv6.enabled = true;
  enableIPv4Masquerade = true;
  enableIPv6Masquerade = true;

  bpf = {
    masquerade = true;
    tproxy = true;
  };

  cni = {
    chainingMode = "none";
    exclusive = true;
  };

  operator.replicas = 1;

  # D1: Cilium is networking-only, permanently.
  gatewayAPI.enabled = false;
  ingressController.enabled = false;

  loadBalancer.algorithm = "maglev";
  pmtuDiscovery.enabled = true;

  # §5.5: every eligible cluster runs clustermesh-apiserver from first boot;
  # maxConnectedClusters is a fleet-uniform invariant (D26). Peers and the
  # per-cluster name/id are layer-2.
  clustermesh = {
    useAPIServer = true;
    # Chart-validated choices are 255 (upstream default) or 511.
    maxConnectedClusters = 511;
  };
}
