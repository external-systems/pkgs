# odoo19 from nixpkgs, fixed so it evaluates and builds:
#
# - PyPDF2 -> pypdf. nixpkgs marks pypdf2 3.0.1 insecure (CVE-2026-27024,
#   -27025, -27628, -27888, -28351, -33699), so odoo19 refuses to
#   evaluate. Odoo 19 ships its own pypdf backend
#   (odoo/tools/pdf/_pypdf.py, tried after PyPDF2 2.x) and nixpkgs'
#   odoo18 already uses pypdf. setup.py still lists PyPDF2, hence
#   pythonRemoveDeps for the runtime dependency check.
# - makeWrapperArgs as separate words. nixpkgs passes
#   "--prefix PATH : ..." as one list element, which makeWrapper rejects
#   ("doesn't understand the arg"), failing the build in fixupPhase.
#
# Drop each fix once nixpkgs carries it.
{
  lib,
  odoo19,
  rtlcss,
  wkhtmltopdf,
}:
odoo19.overridePythonAttrs (previousAttrs: {
  dependencies =
    map (
      dependency:
        if (dependency.pname or "") == "pypdf2"
        then dependency.pythonModule.pkgs.pypdf
        else dependency
    )
    previousAttrs.dependencies;
  pythonRemoveDeps = (previousAttrs.pythonRemoveDeps or []) ++ ["PyPDF2"];
  makeWrapperArgs = ["--prefix" "PATH" ":" (lib.makeBinPath [wkhtmltopdf rtlcss])];
})
