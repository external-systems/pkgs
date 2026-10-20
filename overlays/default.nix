# The artifact overlay: downstream flakes apply this onto their own nixpkgs
# package set to get the pinned, source-built distro runtimes. The builder
# expressions come from the CONSUMER's nixpkgs (prev.path) — any nixpkgs
# recent enough to ship pkgs/applications/networking/cluster/rke2/builder.nix
# and k3s_1_37 works; the versions/hashes are pinned here.
final: prev: let
  rke2Versions = import ../pkgs/rke2/versions.nix;
  rke2Builder =
    import
    (prev.path + "/pkgs/applications/networking/cluster/rke2/builder.nix")
    final.lib
    rke2Versions;
in {
  # Source-built rke2 v1.37.1+rke2r1. nixpkgs stops at 1_36; when it catches
  # up this entry collapses to `inherit (prev) rke2_1_37;`-style aliasing.
  rke2 = (final.callPackage rke2Builder {}).overrideAttrs (old: {
    # Trim nixpkgs' passthru: its tests attr indexes nixosTests.rke2
    # package attrs that do not exist for 1_37, and its fetchurl'd
    # image tarballs are unused here. Re-attach buildGoModule's
    # canonical overrideModAttrs slot so strictifying eval does not
    # warn "passthru.overrideModAttrs missing after overrideAttrs".
    passthru = {
      updateScript = null;
      overrideModAttrs = old.passthru.overrideModAttrs or (_: _: {});
    };
  });

  # nixpkgs already source-builds exactly k3s 1.37.1+k3s1 — re-export it as
  # the pinned artifact (and as the distro default for consumers).
  k3s = prev.k3s_1_37;
}
