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
in {
  flake.overlays = {
    default = lib.composeManyExtensions [
      (import ../overlays/default.nix)
      thirdParty
    ];
    ifstate = import ../overlays/ifstate.nix;
    kubernetes = import ../overlays/kubernetes.nix;
    tools = import ../overlays/tools.nix;
    vscode-extensions = import ../overlays/vscode-extensions.nix;
    third-party = thirdParty;
  };
}
