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

  # dhcpcd is the DHCP client IfState hooks start (clanServices netif).
  # 10.3.x closes a DHCPv6 address socket before deleting it from its
  # event loop. The stale entry makes the next socket that reuses the
  # descriptor number fail with "eloop_event_add: No such file or
  # directory", and DHCPv4 or DHCPv6 then does not recover after a
  # carrier change. Upstream fixed both halves in 10.5.0
  # (NetworkConfiguration/dhcpcd#611); these are those two commits. The
  # version guard drops them once nixpkgs ships 10.5 or newer.
  dhcpcd = prev.dhcpcd.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ final.lib.optionals (final.lib.versionOlder old.version "10.5.0") [
        ./patches/dhcpcd/0001-eloop-always-remove-event-from-list-on-delete.patch
        ./patches/dhcpcd/0002-dhcp6-delete-eloop-event-before-closing-ia-socket.patch
      ];
  });
}
