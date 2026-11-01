# hcloud-ip: assign a Hetzner Cloud floating IP. Upstream release binary.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hcloud-ip";
  version = "0.0.1";

  src = fetchurl {
    url = "https://github.com/FootprintDev/hcloud-ip/releases/download/v${finalAttrs.version}/hcloud-ip-linux64";
    sha256 = "0dvl3qp4cvx994b5jkl7x99fpn5b1vh1gpbja7cdsixmgjyrgc2r";
  };

  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/hcloud-ip
    runHook postInstall
  '';

  meta = {
    description = "CLI utility to assign a Hetzner Cloud floating IP";
    homepage = "https://github.com/FootprintDev/hcloud-ip";
    mainProgram = "hcloud-ip";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
