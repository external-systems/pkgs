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
in {
  flake.overlays = {
    default = lib.composeManyExtensions [
      (import ../overlays/default.nix)
      thirdParty
      vscodeExtensions
    ];
    ifstate = import ../overlays/ifstate.nix;
    kubernetes = import ../overlays/kubernetes.nix;
    tools = import ../overlays/tools.nix;
    vscode-extensions = vscodeExtensions;
    third-party = thirdParty;
  };
}
