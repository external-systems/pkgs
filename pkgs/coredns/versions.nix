# CoreDNS component pin (SPEC D46/D24): one uniform upstream CoreDNS image
# for the clan-rendered cluster.local DNS that the clanServices bootstrap
# bundle deploys in the minimal base (distro CoreDNS disabled there).
# registry.k8s.io is the canonical Kubernetes-hosted upstream source;
# `sha256` pins the dockerTools.pullImage output — refresh via the
# placeholder-hash build dance when bumping.
{
  version = "1.14.7";
  repo = "registry.k8s.io/coredns/coredns";
  tag = "v1.14.7";
  digest = "sha256:2329f5f0e7e79fbe56dcdf11ecc4337ee2476bb251095bc275fe9461cb88a55b";
  sha256 = "sha256-u4VwkSStPrZRfbm4qNhGr07fj2Hdbp78L01kUI4Yhcs=";
}
