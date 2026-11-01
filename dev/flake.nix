{
  description = "Development-only inputs for pkgs (the dev partition)";

  # Locked in dev/flake.lock, never in the main flake.lock. dev-nixpkgs
  # must lock the same rev as the root nixpkgs (checks.lock-sync; fix
  # with `sync-locks`).
  inputs = {
    dev-nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "dev-nixpkgs";
    };

    # Docs + slides (documentation/flake-module.nix).
    presenting = {
      url = "github:external-systems/presenting";
      # presenting takes nixpkgs from its org-pkgs; pin that one to
      # dev-nixpkgs so the dev lock holds a single nixpkgs.
      inputs.org-pkgs.inputs.nixpkgs.follows = "dev-nixpkgs";
    };

    # The code-agent image (images/code-agent): the home-manager agent
    # modules, home-manager itself and external-systems/skills all come
    # through modules. modules follows an older revision of this flake;
    # pin that copy's nixpkgs to dev-nixpkgs as well.
    modules = {
      url = "github:external-systems/modules";
      inputs.org-pkgs.inputs.nixpkgs.follows = "dev-nixpkgs";
    };
  };

  outputs = _: {};
}
