{lib, ...}: {
  flake.lib = {
    # Fetch an OCI helm chart (docker.io, ghcr.io, ...) as a fixed-output
    # derivation. `ref` is the full OCI reference, digest-pinned
    # (oci://host/repo/chart@sha256:...); `hash` pins the pulled tgz bytes.
    fetchOciChart = pkgs: {
      name,
      ref,
      hash,
    }:
      pkgs.runCommand "chart-${name}" {
        nativeBuildInputs = [pkgs.kubernetes-helm pkgs.cacert];
        outputHashMode = "flat";
        outputHashAlgo = "sha256";
        outputHash = hash;
        __impureHostDeps = ["/etc/resolv.conf"];
      } ''
        helm pull ${ref} --destination .
        mv ./*.tgz $out
      '';

    # Render a helm chart to a multi-doc YAML manifest. This is an
    # update-time act (SPEC D26): the output is COMMITTED to the repo under
    # manifests/<component>/ and consumers read the committed file — they
    # never render (zero IFD downstream).
    renderChart = pkgs: {
      name,
      chart,
      releaseName ? name,
      namespace ? name,
      values ? {},
      kubeVersion ? null,
      includeCrds ? false,
    }: let
      # helm's YAML parser rejects the %YAML directive writers.writeYAML
      # emits; JSON is valid YAML input to helm.
      valuesFile = pkgs.writeText "${name}-values.json" (builtins.toJSON values);
    in
      pkgs.runCommand "manifest-${name}" {
        nativeBuildInputs = [pkgs.kubernetes-helm];
      } ''
        helm template ${releaseName} ${chart} \
          --namespace ${namespace} \
          --values ${valuesFile} \
          ${
          if includeCrds
          then "--include-crds"
          else "--skip-crds"
        } \
          ${lib.optionalString (kubeVersion != null) "--kube-version ${kubeVersion}"} \
          > $out
        sed -i 's/[[:space:]]*$//' $out
      '';

    # Extract a chart's crds/ directory as one multi-doc YAML artifact.
    # Component-agnostic helper; unused by the surviving cilium component
    # (the Cilium chart ships no crds/ dir — the operator manages CRDs at
    # runtime, D40).
    chartCrds = pkgs: {
      name,
      chart,
    }:
      pkgs.runCommand "crds-${name}" {} ''
        mkdir unpack
        tar -xzf ${chart} -C unpack
        if ls unpack/*/crds/*.yaml >/dev/null 2>&1; then
          for f in unpack/*/crds/*.yaml; do
            printf -- '---\n# Source: crds/%s\n' "$(basename "$f")"
            cat "$f"
          done > $out
        else
          printf '# chart %s ships no crds/ directory\n' '${name}' > $out
        fi
      '';

    # Render-freshness gate (SPEC D26/D29): the committed manifest must be
    # byte-identical to a fresh render of the pinned chart + profile. Fails
    # if someone edits one without the other.
    manifestFreshnessCheck = pkgs: {
      name,
      committed,
      rendered,
    }:
      pkgs.runCommand "${name}-freshness" {} ''
        if ! diff -u ${committed} ${rendered}; then
          echo "committed manifest ${committed} is stale or was hand-edited;" >&2
          echo "regenerate with: nix run .#update-manifests" >&2
          exit 1
        fi
        touch $out
      '';
  };
}
