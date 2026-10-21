# cert-manager component pin (SPEC §5.8). The canonical fleet-uniform profile
# lives in values.nix; per-cluster variation is the consumer's layer-2
# kubenix module merging, never values here.
{
  chartVersion = "1.21.2";
  chartUrl = "https://charts.jetstack.io/charts/cert-manager-v1.21.2.tgz";
  chartHash = "sha256-c6VuFyjt1smfHzEIJhjDJZ0nmna369PUvcVHXCRC00o=";

  # Image pins exactly as the chart's values compose them
  # (imageRegistry/imageNamespace/image.name, tag defaulting to the chart's
  # appVersion), each with its registry manifest-list digest from quay.io's
  # anonymous token API. sha256 is the pulled-image hash (dockerTools.pullImage
  # FOD, resolved via the placeholder-hash build dance). startupapicheck is
  # chart-rendered but not air-gap-pulled, so it carries no sha256.
  images = {
    controller = {
      repo = "quay.io/jetstack/cert-manager-controller";
      tag = "v1.21.2";
      digest = "sha256:70f532fd9cfde0b09d55687200942399d89838bc2d5d5b45152eb799a15912b8";
      sha256 = "sha256-VSNh58yjDRbUnYHAqsz3d8J3a3Zpa6rpGuqOlpOFsLQ=";
    };
    webhook = {
      repo = "quay.io/jetstack/cert-manager-webhook";
      tag = "v1.21.2";
      digest = "sha256:a60e2dac46dbb8a7f3df95c54ce941012f54c2fe022f0ee55aaa1ab40ed957ae";
      sha256 = "sha256-ggGDFCaCjjq/yBHZmkFEj0bUflzMwu9Lg+jahFsE3zA=";
    };
    cainjector = {
      repo = "quay.io/jetstack/cert-manager-cainjector";
      tag = "v1.21.2";
      digest = "sha256:c85268c64f2e0e76684bf5fe8906caff34b82523561c6affe0fae3546bd87562";
      sha256 = "sha256-kx6VabbkKzqeeypac63FAomItZXsqZ31JLuSXWIhrIU=";
    };
    startupapicheck = {
      repo = "quay.io/jetstack/cert-manager-startupapicheck";
      tag = "v1.21.2";
      digest = "sha256:46e75b6866359ffb5d82624f41e3ed1c70b2994982702ced547ce5edb418a8f5";
    };
  };

  # Kubernetes minors cert-manager 1.21 supports (upstream release matrix:
  # 1.33 → 1.36, https://cert-manager.io/docs/releases/). Recorded for the
  # SPEC D34 support-window gate; lib.nix's componentSupport wiring is a
  # shared-file change outside this component's scope.
  k8sMinors = ["1.33" "1.34" "1.35" "1.36"];
}
