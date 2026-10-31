# Repo-built CLI and agent tooling (the packages external-systems/home
# used to build). Every source is pinned inside its package file, so this
# overlay adds no flake input. nixpkgs-provided tools (claude-code,
# pi-coding-agent, tfctl, devenv, mcp-nixos, github-mcp-server) are used
# as-is and not re-exported here.
final: _prev: {
  artifacthub-mcp = final.callPackage ../pkgs/artifacthub-mcp/package.nix {};
  hcloud-ip = final.callPackage ../pkgs/hcloud-ip/package.nix {};
  headroom = final.callPackage ../pkgs/headroom/package.nix {};
  headroom-slim = final.callPackage ../pkgs/headroom/package.nix {slim = true;};
  kimi-code = final.callPackage ../pkgs/kimi-code/package.nix {};
  kubernetes-mcp-server = final.callPackage ../pkgs/kubernetes-mcp-server/package.nix {};
  longhornctl = final.callPackage ../pkgs/longhornctl/package.nix {};
}
