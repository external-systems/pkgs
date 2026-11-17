final: prev: let
  ifstateSrc = final.fetchFromCodeberg {
    owner = "routerkit";
    repo = "ifstate";
    tag = "2.5.1";
    hash = "sha256-wRIFQQYSCsEmK7epFponyVEh9BrkjJWW8t34tDz7Ofg=";
  };
in {
  # IfState 2.5 moved to the src/ Python layout and uv_build. The pure
  # pyroute2 variant avoids the optional Rust accelerator.
  ifstate = prev.ifstate.overridePythonAttrs (old: {
    version = "2.5.1";
    src = ifstateSrc;
    build-system = [final.python3Packages.uv-build];
    postPatch = ''
      substituteInPlace src/libifstate/paths.py \
        --replace-fail '/usr/share/iproute2' '${final.iproute2}/share/iproute2' \
        --replace-fail "/usr/sbin/ethtool" "${final.lib.getExe final.ethtool}"
      substituteInPlace src/libifstate/hook/wrapper.sh \
        --replace-fail ' ip ' ' ${final.lib.getExe' final.iproute2 "ip"} '
    '';
    passthru =
      old.passthru
      // {
        jsonschema = "${ifstateSrc}/schema/2/ifstate.conf.schema.json";
      };
  });

  # dhcpcd, two attributes. nixpkgs ships 10.3.2, which closes a DHCPv6
  # address socket before deleting it from its event loop: after a
  # carrier change DHCPv4 or DHCPv6 does not recover ("eloop_event_add:
  # No such file or directory", NetworkConfiguration/dhcpcd#596).
  # Upstream fixed it in 10.5.0, with four CVEs (CVE-2026-56113,
  # -56114, -56116, -56117).
  #
  # `dhcpcd_latest` is the unpatched upstream 10.5.2 on the nixpkgs
  # build recipe. clanServices netif runs it: netif starts dhcpcd from
  # an IfState hook, not from the NixOS `dhcpcd.service`. `patches` is
  # emptied on purpose: a fix nixpkgs backports to its older version
  # would not apply to this source.
  dhcpcd_latest =
    if final.lib.versionOlder prev.dhcpcd.version "10.5.2"
    then
      prev.dhcpcd.overrideAttrs (_: {
        version = "10.5.2";
        patches = [];
        src = final.fetchFromGitHub {
          owner = "NetworkConfiguration";
          repo = "dhcpcd";
          tag = "v10.5.2";
          hash = "sha256-lrV6SaB/HmTptZigZ1Lf28eUPz0igxyT6omZwXDSuGM=";
        };
      })
    else prev.dhcpcd;

  # `dhcpcd` stays 10.3.2 with the two upstream commits of the lost-lease
  # fix (NetworkConfiguration/dhcpcd#611). It cannot be 10.5 yet: from
  # 10.5.1 dhcpcd calls chown on its control socket, and the system-call
  # filter of the NixOS `dhcpcd.service` kills it at start ("dhcpcd
  # manager hungup"; NixOS/nixpkgs#562813 adds `@chown`). A machine with
  # `networking.useDHCP` would lose DHCP. The version guard drops the
  # patches once nixpkgs ships 10.5 with that unit.
  dhcpcd = prev.dhcpcd.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ final.lib.optionals (final.lib.versionOlder old.version "10.5.0") [
        ./patches/dhcpcd/0001-eloop-always-remove-event-from-list-on-delete.patch
        ./patches/dhcpcd/0002-dhcp6-delete-eloop-event-before-closing-ia-socket.patch
      ];
  });
}
