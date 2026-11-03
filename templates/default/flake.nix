{
  description = "CHANGE ME: one line on what this repo provides";

  inputs = {
    # Shared-input authority for the org: consumers that already follow
    # it lock nothing new. Named org-pkgs, never pkgs, in every flake.nix
    # and devenv.yaml: `pkgs` is the nixpkgs package set everywhere else
    # (module args, perSystem), and devenv shadows it with an input of
    # that name.
    org-pkgs.url = "github:external-systems/pkgs";
    nixpkgs.follows = "org-pkgs/nixpkgs";
    flake-parts.follows = "org-pkgs/flake-parts";
    import-tree.follows = "org-pkgs/import-tree";

    # Consumer-facing inputs only; each follows nixpkgs/flake-parts.
    # No dev/flake.nix: formatting, docs and slides come from org-pkgs.
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      # Exposes debug.options / currentSystem.options, which nixd
      # (.vscode/settings.json) reads for flake-parts option hints.
      debug = true;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        # treefmt (formatter, checks.treefmt), docs + slides
        # (packages.documentation/slides, live previews), lock-sync.
        # documentation/ needs no Nix; set docs.* in a module under
        # flake-parts/ to change a default (pkgs' "Docs and slides" page).
        inputs.org-pkgs.flakeModules.dev
        (inputs.import-tree ./flake-parts)
      ];
    };
}
