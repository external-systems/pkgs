# The code-agent sandbox image, moved here from external-systems/home.
# Lives in the dev partition (dev/flake-module.nix imports it): its inputs
# (external-systems/modules, which brings home-manager and
# external-systems/skills) are locked in dev/flake.lock only, so consumers
# of packages/overlays never fetch them. Build it with
#   nix build .#code-agent-image          # a streamed image script
#   nix run .#load-code-agent-image       # docker load
#   nix run .#push-code-agent-image -- docker://registry/code-agent:tag
{
  inputs,
  self,
  ...
}: {
  perSystem = {
    system,
    config,
    lib,
    ...
  }:
    import ./image.nix {
      inherit inputs self config;
      # One nixpkgs: this flake's nixpkgs plus its own overlay
      # (headroom-slim, kimi-code, artifacthub-mcp, ...). claude-code is
      # the image's only unfree package.
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
        config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";
      };
    };
}
