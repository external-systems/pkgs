# Open VSX extensions nixpkgs doesn't package, merged into
# pkgs.vscode-extensions under their usual publisher.name paths
# (pkgs.vscode-extensions.jeanp413.open-remote-ssh), so modules list them
# beside the nixpkgs ones.
final: prev: let
  # import, not callPackage: callPackage would add override attrs to the
  # publisher set.
  extra = import ../pkgs/vscode-extensions/open-vsx.nix {
    inherit (final) lib fetchurl vscode-utils;
  };
in {
  vscode-extensions =
    prev.vscode-extensions
    // prev.lib.mapAttrs (publisher: exts: (prev.vscode-extensions.${publisher} or {}) // exts) extra;
}
