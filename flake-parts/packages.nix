{
  lib,
  self,
  ...
}: {
  perSystem = {pkgs, ...}: let
    # The flake's own packages are the overlay applied to the pinned nixpkgs
    # — one construction, two surfaces (packages.<system>.* for direct
    # builds, overlays.default for consumers).
    artifactPkgs = pkgs.extend self.overlays.default;

    # overlays.tools, minus what this system cannot build (the release
    # binaries are x86_64-linux only).
    tools =
      lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform)
      (lib.getAttrs (lib.attrNames (import ../overlays/tools.nix {} {})) artifactPkgs);

    # The AI coding agents from overlays.llm-agents, buildable directly
    # (nix build .#claude-code) like the tools.
    agents =
      lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform)
      (lib.getAttrs ["claude-code" "claude-desktop" "kimi-code" "opencode" "pi-coding-agent"] artifactPkgs);

    # The uv2nix Python apps from overlays.python-apps (Linux only).
    pythonApps =
      lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform)
      (lib.getAttrs ["headroom" "headroom-lean" "headroom-sandbox"] artifactPkgs);
  in {
    packages =
      {
        inherit
          (artifactPkgs)
          ifstate
          rke2
          rke2_1_35
          rke2_1_36
          rke2_1_37
          k3s
          k3s_1_35
          k3s_1_36
          k3s_1_37
          odoo19
          ;
      }
      // tools
      // agents
      // pythonApps;
  };
}
