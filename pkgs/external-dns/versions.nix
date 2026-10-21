# external-dns component pin. The canonical fleet-uniform profile lives in
# values.nix; provider and credentials are the consumer's GitOps layer
# (SPEC D31), never values here.
{
  chartVersion = "1.23.0";
  chartUrl = "https://github.com/kubernetes-sigs/external-dns/releases/download/external-dns-helm-chart-1.23.0/external-dns-1.23.0.tgz";
  chartHash = "sha256-bRSbmwTbHcnkazaTpOykrJDWu6XjsqD90GfOP3v7wx4=";
}
