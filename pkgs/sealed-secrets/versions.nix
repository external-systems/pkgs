# Sealed Secrets component pin. The canonical fleet-uniform profile lives in
# values.nix; per-cluster variation is the consumer's layer-2 kubenix module
# merging, never values here.
{
  chartVersion = "2.20.0";
  chartUrl = "https://github.com/bitnami/sealed-secrets/releases/download/helm-v2.20.0/sealed-secrets-2.20.0.tgz";
  chartHash = "sha256-YJLSGcaX88muOjhrokv92Gh3xeL8iJLir4qBAUW5kO8=";
}
