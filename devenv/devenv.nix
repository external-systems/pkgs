# The org devenv shell, imported by every external-systems repo's
# devenv.yaml (`imports: [org-pkgs/devenv]`), so every repo has the same
# commands. A repo's own devenv.nix adds languages, services and app
# processes on top. Plain devenv module: never reference flake outputs.
{
  config,
  pkgs,
  ...
}: {
  # nixd and alejandra back the editor: .vscode/settings.json runs nixd
  # (Nix language server, the nixf diagnostics CI enforces) and formats
  # with alejandra.
  packages = with pkgs; [
    alejandra
    git
    jq
    nixd
  ];

  scripts = {
    fmt = {
      exec = ''nix fmt "$@"'';
      description = "Format and lint the repo (treefmt, org linters)";
    };
    check = {
      exec = ''nix flake check "$@"'';
      description = "Run every flake check (lint, lock sync, docs, tests)";
    };
    sync-locks = {
      exec = ''nix run .#sync-locks'';
      description = "Pin dev/flake.lock and devenv.lock to the flake.lock nixpkgs";
    };
    # Static build: no server, open result-docs/index.html straight
    # from disk (file://) in any browser.
    docs-build = {
      exec = ''nix build .#documentation -o result-docs "$@" && echo "$PWD/result-docs/index.html"'';
      description = "Build the docs site (slides embedded at slides/) to ./result-docs";
    };
    # Live previews. Ports 8981/8982 stay clear of the 8000/8001 that
    # app dev servers usually take; the docs port is dev_addr in
    # documentation/mkdocs.yml.
    docs = {
      exec = ''nix run .#watch-documentation'';
      description = "Live docs preview on 127.0.0.1:8981";
    };
    slides = {
      exec = ''nix run .#serve-slides -- 8982'';
      description = "Live slides preview on 127.0.0.1:8982";
    };
  };

  # `devenv up` serves docs and slides side by side.
  processes = {
    docs.exec = config.scripts.docs.exec;
    slides.exec = config.scripts.slides.exec;
  };

  # `devenv test`: the cheap static gates, never VMs.
  enterTest = ''
    nix fmt -- --ci
    nix build --no-link ".#checks.${pkgs.stdenv.hostPlatform.system}.lock-sync"
  '';
}
