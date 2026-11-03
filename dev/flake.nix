{
  description = "Development-only inputs for pkgs (the dev partition)";

  # Locked in dev/flake.lock, never in the main flake.lock. Only pkgs keeps
  # a dev partition: the code-agent image needs external-systems/modules,
  # which itself depends on this flake, so it cannot be a root input.
  # Formatting and docs come from this flake's own inputs (treefmt-nix,
  # reveal-js). dev-nixpkgs must lock the same rev as the root nixpkgs
  # (checks.lock-sync; fix with `sync-locks`).
  inputs = {
    dev-nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The code-agent image (images/code-agent): the home-manager agent
    # modules, home-manager itself and external-systems/skills all come
    # through modules. modules follows an older revision of this flake;
    # pin that copy's nixpkgs to dev-nixpkgs.
    modules = {
      url = "github:external-systems/modules";
      inputs.org-pkgs.inputs.nixpkgs.follows = "dev-nixpkgs";
    };
  };

  outputs = _: {};
}
