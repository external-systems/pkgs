# Docs settings that differ from the org defaults (flakeModules.docs).
# documentation/docs/*.md is the site, documentation/slides/slides.md the
# deck; delete this file if nothing here needs changing.
_: {
  perSystem.docs = {
    repo = "CHANGE ME"; # site_url https://<repo>.external.systems/
    settings.site_name = "CHANGE ME";
  };
}
