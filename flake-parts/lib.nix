{
  inputs,
  lib,
  ...
}: let
  # k3s rides the pinned nixpkgs' builders (it ships exactly the latest
  # patches for 1.35/1.36/1.37); rke2 uses the local tables in
  # pkgs/rke2/versions/ because nixpkgs tops out at 1_36 and lags a patch
  # behind on 1_35/1_36 (SPEC D34: latest patch per minor).
  rke2Tables = {
    "1.35" = import ../pkgs/rke2/versions/1_35.nix;
    "1.36" = import ../pkgs/rke2/versions/1_36.nix;
    "1.37" = import ../pkgs/rke2/versions/1_37.nix;
  };
  k3sTables = {
    "1.35" = import (inputs.nixpkgs + "/pkgs/applications/networking/cluster/k3s/1_35/versions.nix");
    "1.36" = import (inputs.nixpkgs + "/pkgs/applications/networking/cluster/k3s/1_36/versions.nix");
    "1.37" = import (inputs.nixpkgs + "/pkgs/applications/networking/cluster/k3s/1_37/versions.nix");
  };
  # "1.37.1+rke2r1" -> "1.37.1"
  k8sOf = v: builtins.head (builtins.split ''\+'' v);
  minors = builtins.attrNames rke2Tables;
  matrix = builtins.listToAttrs (map (minor: {
      name = minor;
      value = {
        kubernetes = k8sOf k3sTables.${minor}.k3sVersion;
        k3s = "v${k3sTables.${minor}.k3sVersion}";
        rke2 = "v${rke2Tables.${minor}.rke2Version}";
        inherit (k3sTables.${minor}) k3sCommit;
        inherit (rke2Tables.${minor}) rke2Commit;
      };
    })
    minors);

  # SPEC D34 support-window gate: the Kubernetes minors each pinned
  # component supports (from its upstream support matrix, recorded in the
  # component's versions.nix). A packaged distro minor missing from a
  # component's list is an accepted bleeding-edge risk → eval WARNING,
  # never a failure.
  componentSupport = {
    cilium = (import ../pkgs/cilium/versions.nix).k8sMinors;
    envoy-gateway = (import ../pkgs/envoy-gateway/versions.nix).k8sMinors;
    cert-manager = (import ../pkgs/cert-manager/versions.nix).k8sMinors;
  };
  supportWarnings = lib.flatten (lib.mapAttrsToList (
      component: supported:
        map (minor: "${component} does not list pinned k8s minor ${minor} in its support matrix (SPEC D34 accepted-risk gate)")
        (builtins.filter (minor: !(builtins.elem minor supported)) minors)
    )
    componentSupport);
in {
  # flake.lib is not merged by flake-parts unless an option is declared;
  # declare it once here so every module can contribute attributes.
  # manifestArtifacts is a declared submodule option so per-component
  # modules merge their registry entries instead of conflicting.
  options.flake.lib = lib.mkOption {
    type = lib.types.submodule {
      freeformType = lib.types.lazyAttrsOf lib.types.raw;
      options.manifestArtifacts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
        default = {};
        description = "Committed-manifest registry: artifact name → { package, path } — update-manifests re-renders each package into manifests/<path>.";
      };
    };
    default = {};
    description = "Artifact flake library: version matrix, render helpers, component registries.";
  };

  config.flake.lib.versions =
    lib.warnIf (supportWarnings != [])
    "pkgs: support-window warning — ${lib.concatStringsSep "; " supportWarnings}"
    ({
        # The last-3-minors matrix (SPEC D34). Per minor both distros must
        # package the SAME Kubernetes release — enforced per minor by
        # checks.k8s-version-parity-<minor>.
        inherit matrix;
        latestMinor = "1.37";
      }
      # Latest-minor aliases — the historical flat shape consumers already
      # use.
      // matrix."1.37");
}
