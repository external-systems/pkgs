{
  inputs,
  lib,
  ...
}: let
  # Packages from third-party flakes, taken as-is for the consumer's
  # system. Unlike the file overlays below, this one closes over flake
  # inputs. The attribute names stay static (a name set that depends on
  # `final` recurses); a system the flake doesn't build for fails only
  # when the package is used.
  thirdParty = final: _prev: let
    fromFlake = input: input.packages.${final.stdenv.hostPlatform.system}.default;
  in {
    zen-browser = fromFlake inputs.zen-browser;
    moscripts = fromFlake inputs.moscripts;
  };

  # nix-community/nix-vscode-extensions' extension sets. Static names over
  # its overlay, so a consumer of overlays.default that never reads them
  # never fetches the input. Each extension builds with the fixes nixpkgs
  # carries for it (native binaries patched for NixOS, claude-code linked
  # to pkgs.claude-code).
  vscodeExtensions = final: prev: {
    inherit
      (inputs.nix-vscode-extensions.overlays.default final prev)
      open-vsx
      open-vsx-release
      vscode-marketplace
      vscode-marketplace-release
      ;
  };
  # numtide/llm-agents.nix's AI coding agents, built against the
  # consumer's nixpkgs (its shared-nixpkgs overlay) and put in place of
  # the nixpkgs attrs every consumer already reads, so modules and the
  # code-agent image get the latest release without renaming anything.
  # The whole set stays reachable as pkgs.llm-agents. Static names, so a
  # consumer that never reads them never fetches the input.
  llmAgents = final: prev: let
    agents = (inputs.llm-agents.overlays.shared-nixpkgs final prev).llm-agents;
  in {
    llm-agents = agents;
    inherit (agents) claude-code claude-desktop kimi-code;
    pi-coding-agent = agents.pi;
    # opencode v2 only: upstream installs the v2 binary as `opencode2` so
    # it can sit next to v1; the org runs v2 alone, under its real name.
    opencode = final.symlinkJoin {
      pname = "opencode";
      inherit (agents.opencode2) version;
      paths = [agents.opencode2];
      postBuild = "ln -s $out/bin/opencode2 $out/bin/opencode";
      meta = agents.opencode2.meta // {mainProgram = "opencode";};
    };
  };

  # Python apps built with uv2nix from a uv project vendored next to their
  # package.nix, against the consumer's nixpkgs. Closes over the uv2nix
  # inputs; lazy, so a consumer that never reads them never fetches them.
  # headroom: one attr per upstream dependency profile (headroom-ai extra).
  pythonApps = final: _prev: let
    headroom = profile:
      final.callPackage ../pkgs/headroom/package.nix {
        inherit profile;
        inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
      };
  in {
    headroom = headroom "all";
    headroom-lean = headroom "lean";
    headroom-sandbox = headroom "sandbox";
  };
in {
  flake.overlays = {
    default = lib.composeManyExtensions [
      (import ../overlays/default.nix)
      thirdParty
      vscodeExtensions
      llmAgents
      pythonApps
    ];
    llm-agents = llmAgents;
    ifstate = import ../overlays/ifstate.nix;
    kubernetes = import ../overlays/kubernetes.nix;
    odoo = import ../overlays/odoo.nix;
    python-apps = pythonApps;
    tools = import ../overlays/tools.nix;
    vscode-extensions = vscodeExtensions;
    third-party = thirdParty;
  };
}
