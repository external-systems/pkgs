# The org devenv shell, imported by every external-systems repo's
# devenv.yaml (`imports: [pkgs/devenv]`), so every repo has the same
# commands. A repo's own devenv.nix adds languages, services and app
# processes on top. Plain devenv module: never reference flake outputs.
{
  config,
  pkgs,
  ...
}: {
  packages = with pkgs; [
    git
    jq
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
    docs = {
      exec = ''nix run .#watch-documentation'';
      description = "Live docs preview on 127.0.0.1:8000";
    };
    slides = {
      exec = ''nix run .#serve-slides -- 8001'';
      description = "Live slides preview on 127.0.0.1:8001";
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
