{lib, ...}: {
  # overlays.vscode-extensions only adds attributes; this check fetches and
  # unpacks every pinned .vsix, so a wrong hash fails on the PR.
  perSystem = {pkgs, ...}: {
    checks.vscode-extensions = let
      extensions = import ../pkgs/vscode-extensions/open-vsx.nix {
        inherit (pkgs) lib fetchurl vscode-utils;
      };
    in
      pkgs.linkFarmFromDrvs "vscode-extensions"
      (lib.concatMap lib.attrValues (lib.attrValues extensions));
  };
}
