# Odoo, fixed where the nixpkgs package does not evaluate or build (see
# pkgs/odoo/package.nix). Replaces the nixpkgs attribute, so a consumer
# that applies overlays.default needs no rename: pkgs.odoo19 just works.
final: prev: {
  odoo19 = final.callPackage ../pkgs/odoo/package.nix {inherit (prev) odoo19;};
}
