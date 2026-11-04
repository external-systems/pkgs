# Org flake standard, exported once so every external-systems repo imports
# it instead of copying it. The modules are bound to THIS flake's inputs
# (treefmt-nix, reveal-js), so a consumer declares no dev input and needs
# no dev/flake.nix: one org-pkgs input brings formatting, docs and slides.
{
  inputs,
  flake-parts-lib,
  ...
}: let
  bind = file: flake-parts-lib.importApply file {orgInputs = inputs;};
in {
  imports = [inputs.flake-parts.flakeModules.flakeModules];

  flake = {
    flakeModules = {
      # Org linters as treefmt programs: formatter + checks.treefmt.
      treefmt = bind ../flakeModules/treefmt.nix;
      # MkDocs site + reveal.js deck: packages.documentation/slides and
      # the live-preview apps. Replaces external-systems/presenting.
      docs = bind ../flakeModules/docs.nix;
      # treefmt + docs + checks.lock-sync + apps.sync-locks + docs as
      # checks: the one import every repo's flake.nix needs
      # (inputs.org-pkgs.flakeModules.default).
      default = bind ../flakeModules/dev.nix;
      # Old name for default; remove once no repo imports it.
      dev = bind ../flakeModules/dev.nix;
    };

    # `nix flake init -t github:external-systems/pkgs`
    templates.default = {
      path = ../templates/default;
      description = "external-systems repo: flake on org-pkgs, devenv shell, docs and slides";
      welcomeText = ''
        # New external-systems repo

        Set the description in flake.nix and the CHANGE MEs in
        flake-parts/docs.nix, then lock everything:

            git init && git add -A
            nix flake lock && devenv update
            nix run .#sync-locks
            devenv allow          # auto-activation (needs `devenv hook`)
            check                 # nix flake check, inside the shell
            devenv up             # live docs :8981 and slides :8982

        Then on GitHub: Settings > Pages > Source: GitHub Actions, and
        apply the branch ruleset (required check "ci / flake-check"):

            gh api -X POST repos/external-systems/<repo>/rulesets \
              --input .github/rulesets/default.json

        AGENTS.md describes the layout for coding agents.
      '';
    };
  };
}
