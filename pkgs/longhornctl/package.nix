# Longhorn CLI: preflight, operate and troubleshoot a Longhorn cluster.
# Upstream release binary (statically linked Go).
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "longhornctl";
  version = "1.12.0";

  src = fetchurl {
    url = "https://github.com/longhorn/cli/releases/download/v${finalAttrs.version}/longhornctl-linux-amd64";
    hash = "sha256-HX7w5kTNEYWhEgYDug04nJKjJERQru1eZSdcHFLVwIM=";
  };

  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/longhornctl
    runHook postInstall
  '';

  meta = {
    description = "Headless CLI for preflighting, operating and troubleshooting Longhorn clusters";
    homepage = "https://github.com/longhorn/cli";
    license = lib.licenses.asl20;
    mainProgram = "longhornctl";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
