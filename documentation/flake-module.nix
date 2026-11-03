# This repo's docs: flakeModules.docs (imported through flakeModules.dev
# in dev/flake-module.nix), dogfooded with no mkdocs.yml and no deck
# index.html. Only what differs from the org defaults is set here.
{
  perSystem.docs = {
    repo = "pkgs";
    settings = {
      site_name = "external-systems pkgs";
      nav = [
        {Home = "index.md";}
        {"Org flake standard" = "flake-standard.md";}
        {"Docs and slides" = "docs-and-slides.md";}
        {CI = "ci.md";}
      ];
    };
  };
}
