# Flux component pins (SPEC §7 phase 2): the flux-operator chart, the Flux
# distribution install manifest, and the airgap image mirror set. The
# canonical fleet-uniform profile lives in values.nix; per-cluster variation
# is the consumer's layer-2 kubenix module merging, never values here.
{
  operatorChart = {
    version = "0.61.0";
    ref = "oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator:0.61.0";
    # Flat hash of the tgz bytes `helm pull` produces.
    hash = "sha256-DPHD9cM009Rm77ygoaJBTo3ArAV3AVCZO4KenX1+WG4=";
  };

  distribution = {
    tag = "v2.9.6";
    url = "https://github.com/fluxcd/flux2/releases/download/v2.9.6/install.yaml";
    hash = "sha256-nB/afkAUKVMe0UePZ7oGs+3/ZRO3XafuR73p8cTUJRw=";
  };

  # Airgap mirror set: every controller image referenced by the pinned Flux
  # distribution install.yaml plus the flux-operator controller image
  # (ghcr.io/controlplaneio-fluxcd/flux-operator:<chart appVersion>).
  # repo/tag/digest are the upstream pins (digest from the registry's
  # docker-content-digest header); sha256 is the dockerTools.pullImage
  # fixed-output hash (placeholder-hash build dance).
  images = [
    {
      name = "helm-controller";
      repo = "ghcr.io/fluxcd/helm-controller";
      tag = "v1.6.5";
      digest = "sha256:0d52fff5c4d476277b8fcb6beb9041e269adb5db943fe69f5a806ea0c92b1511";
      sha256 = "sha256-fX4qh5VeeCenK1EvXby8JZx0CPFbev/WaEnIWevH3B8=";
    }
    {
      name = "image-automation-controller";
      repo = "ghcr.io/fluxcd/image-automation-controller";
      tag = "v1.2.5";
      digest = "sha256:e1a2720d3951694609c39635886d5dcb15b7dffe0b8248461c6693539c522a28";
      sha256 = "sha256-pTl8t2AfmmMxK2GQnT7gi47mLnFUjZSMPdGXW8RtsQ8=";
    }
    {
      name = "image-reflector-controller";
      repo = "ghcr.io/fluxcd/image-reflector-controller";
      tag = "v1.2.5";
      digest = "sha256:c83ce5c06fed9ebb308cd5165bd144ee934c720f6b47e0da2180869092063c82";
      sha256 = "sha256-noKG4bqHmJ9elmgED9/LWsu3/arVbdlvbF+QTiCEofY=";
    }
    {
      name = "kustomize-controller";
      repo = "ghcr.io/fluxcd/kustomize-controller";
      tag = "v1.9.6";
      digest = "sha256:2ebeaa341da77d52b6abbbba5efcee0450d47f8b42f0e6f33b08f9020262d606";
      sha256 = "sha256-LviGjTBDmVgRtHcWV+mQf0s9K/3/EBP+sWXI5FmvPVE=";
    }
    {
      name = "notification-controller";
      repo = "ghcr.io/fluxcd/notification-controller";
      tag = "v1.9.4";
      digest = "sha256:840f318265ee26f0d2c48a158bf7896b22aa4e998e320a18646309f0e40b15da";
      sha256 = "sha256-JCAx+9nB9+Wcyrt5aNWyGSK9VCOEVMp5DeV45c0jUMM=";
    }
    {
      name = "source-controller";
      repo = "ghcr.io/fluxcd/source-controller";
      tag = "v1.9.6";
      digest = "sha256:6a6693172589f8ff26123a231d5fa6ceb194a6efb4dc647cdf057c959f76a2e3";
      sha256 = "sha256-PUAuGrl9BtKzzHGr9pf5LiBmct+Lf2b6IFc0W6r2FCg=";
    }
    {
      name = "source-watcher";
      repo = "ghcr.io/fluxcd/source-watcher";
      tag = "v2.2.4";
      digest = "sha256:86743f5a4cd4ea76b9722eb86222d56e8253e776daa0565ecb186ec68ad1d835";
      sha256 = "sha256-ztKYXgpcVtmJ3IqwS9TzZ51d2T57CHmxTWZGKb3OCoA=";
    }
    {
      name = "operator";
      repo = "ghcr.io/controlplaneio-fluxcd/flux-operator";
      tag = "v0.61.0";
      digest = "sha256:71041d9fff7f7b05f1a8123ebe73c73b7b156f4aacfe1e8e19b5aa953a98892c";
      sha256 = "sha256-Ll3sqUY0B9bQidXW1X8XyQ7XKGZU0FLIrJLq1kwpylA=";
    }
  ];
}
