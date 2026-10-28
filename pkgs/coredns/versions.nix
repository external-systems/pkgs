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
  digest = "sha256:7efd3c635b03efd68c4e8398fc45f0d993d0e9ab016f72c1cefb0fd6d01aa286";
  sha256 = {
    amd64 = "sha256-u4VwkSStPrZRfbm4qNhGr07fj2Hdbp78L01kUI4Yhcs=";
    arm64 = "sha256-NH+QDqR+p3i1jh4xvQH8mjsZ07aHrm/xAOFiOcO0lfA=";
  };
}
