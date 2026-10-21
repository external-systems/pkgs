# The artifact overlay: downstream flakes apply this onto their own nixpkgs
# package set to get the pinned, source-built distro runtimes. The builder
# expressions come from the CONSUMER's nixpkgs (prev.path) — any nixpkgs
# recent enough to ship pkgs/applications/networking/cluster/rke2/builder.nix
# and k3s 1_35–1_37 works; the versions/hashes are pinned here (SPEC D34:
# last 3 k8s minors per distro, latest patch each).
final: prev: let
  # nixpkgs tops out at rke2 1_36 (and one patch behind on 1_35/1_36), so
  # every minor rides the local tables in pkgs/rke2/versions/. When nixpkgs
  # catches up a minor collapses to `inherit (prev) rke2_1_xx;`-style aliasing.
  mkRke2 = minor: let
    rke2Versions = import ../pkgs/rke2/versions/${minor}.nix;
    rke2Builder =
      import
      (prev.path + "/pkgs/applications/networking/cluster/rke2/builder.nix")
      final.lib
      rke2Versions;
  in
    (final.callPackage rke2Builder {}).overrideAttrs (old: {
      # Trim nixpkgs' passthru: its tests attr indexes nixosTests.rke2
      # package attrs that do not exist for these minors, and its fetchurl'd
      # image tarballs are unused here. Re-attach buildGoModule's canonical
      # overrideModAttrs slot so strictifying eval does not warn
      # "passthru.overrideModAttrs missing after overrideAttrs".
      passthru = {
        updateScript = null;
        overrideModAttrs = old.passthru.overrideModAttrs or (_: _: {});
      };
    });
in {
  rke2_1_35 = mkRke2 "1_35";
  rke2_1_36 = mkRke2 "1_36";
  rke2_1_37 = mkRke2 "1_37";
  # Distro default: latest pinned minor.
  rke2 = final.rke2_1_37;

  # nixpkgs already source-builds exactly the pinned k3s patches — re-export
  # them as the pinned artifacts.
  inherit (prev) k3s_1_35 k3s_1_36 k3s_1_37;
  k3s = final.k3s_1_37;
}
