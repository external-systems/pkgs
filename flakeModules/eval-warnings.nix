# The evaluation-warning gate: `nix run .#flake-check` (the devenv `check`
# script and org-ci's flake-check job) runs `nix flake check`, keeps its
# log and then sorts the evaluation warnings. Ordinary ones (deprecations,
# renames) are listed and pass; a warning matching a dangerous pattern
# (config that is silently ignored, removed or insecure) fails the run.
# The org list is `evalWarnings.deny`; a repo appends its own patterns.
_: {
  config,
  lib,
  ...
}: let
  cfg = config.evalWarnings;
in {
  key = "external-systems/pkgs#flakeModules.evalWarnings";

  options.evalWarnings = {
    deny = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "no longer has any effect"
        "has no effect"
        "has been removed"
        "is insecure"
        "known vulnerabilities"
        "The option .* defined .* does not exist"
      ];
      description = ''
        Extended regular expressions (grep -E). An evaluation warning that
        matches one fails `nix run .#flake-check`: it means configuration
        is silently ignored, gone or unsafe. Other warnings are listed
        and pass. Append repo-specific patterns with
        `evalWarnings.deny = lib.mkAfter [ ... ]`.
      '';
    };
  };

  config.perSystem = {pkgs, ...}: let
    flake-check = pkgs.writeShellApplication {
      name = "flake-check";
      runtimeInputs = [pkgs.coreutils pkgs.gnugrep pkgs.gnused];
      text = ''
        log=$(mktemp)
        trap 'rm -f "$log"' EXIT
        set +e
        nix flake check "$@" 2>&1 | tee "$log"
        status=''${PIPESTATUS[0]}
        set -e
        # Nix prints module warnings as "evaluation warning:" (older:
        # "trace: warning:"); "warning:" alone is Nix's own (dirty tree).
        warnings=$(grep -E '^(evaluation warning|trace: warning): ' "$log" | sort -u || true)
        deny=${lib.escapeShellArg (lib.concatStringsSep "|" cfg.deny)}
        dangerous=$(printf '%s\n' "$warnings" | grep -E -- "$deny" || true)
        if [ -n "$warnings" ]; then
          echo "flake-check: evaluation warnings ($(printf '%s\n' "$warnings" | wc -l), deduplicated):" >&2
          printf '%s\n' "$warnings" | sed 's/^/  /' >&2
        fi
        if [ -n "$dangerous" ]; then
          echo "flake-check: FAILED: dangerous evaluation warnings (evalWarnings.deny):" >&2
          printf '%s\n' "$dangerous" | sed 's/^/  /' >&2
          exit 1
        fi
        exit "$status"
      '';
    };
  in {
    apps.flake-check = {
      type = "app";
      program = lib.getExe flake-check;
      meta.description = "nix flake check, failing on dangerous evaluation warnings (evalWarnings.deny)";
    };
  };
}
