# Org flake standard, exported once so every external-systems repo imports
# it instead of copying it. The modules read the CONSUMER's inputs
# (treefmt-nix), which the consumer declares in its dev/flake.nix, so this
# flake gains no input and no consumer's main flake.lock grows.
{inputs, ...}: {
  imports = [inputs.flake-parts.flakeModules.flakeModules];

  flake = {
    flakeModules = {
      # Org linters as treefmt programs: formatter + checks.treefmt.
      treefmt = ../flakeModules/treefmt.nix;
      # treefmt + checks.lock-sync + apps.sync-locks + docs as checks.
      # The one import a repo's dev partition needs.
      dev = ../flakeModules/dev.nix;
    };

    # `nix flake init -t github:external-systems/pkgs`
    templates.default = {
      path = ../templates/default;
      description = "external-systems repo: flake + dev partition, devenv shell, docs and slides";
      welcomeText = ''
        # New external-systems repo

        Set the description in flake.nix and site_name in
        documentation/mkdocs.yml, then lock everything:

            git init && git add -A
            nix flake lock && nix flake lock ./dev && devenv update
            nix run .#sync-locks
            devenv allow          # auto-activation (needs `devenv hook`)
            check                 # nix flake check, inside the shell
            devenv up             # live docs :8981 and slides :8982

        AGENTS.md describes the layout for coding agents.
      '';
    };
  };
}
