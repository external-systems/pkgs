# MCP server for Artifact Hub (Helm charts), stdio transport. Upstream has
# no flake; the source is pinned to the v1.1.1 tag here.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:
buildNpmPackage (finalAttrs: {
  pname = "artifacthub-mcp";
  # The tag's package.json still says 1.0.0; report the real tag.
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "AlexW00";
    repo = "artifacthub-mcp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-fn3z9958hFAga5SCYpnrMIsBRVKEpYoybNwJVn7aew0=";
  };

  npmDepsHash = "sha256-/hOUQOMpCux/Dt1ZUqqZUIGjIZJkp8g9a0Pqd7bMlVA=";

  # Pure TypeScript: tsc -> dist/ via the "build" script, no native modules.
  npmBuild = "npm run build";

  # package.json has no `bin` field, so wrap the entrypoint by hand; ESM
  # resolves its deps from the installed node_modules.
  dontNpmPrune = true;
  postInstall = ''
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/artifacthub-mcp \
      --add-flags "$out/lib/node_modules/artifacthub-mcp/dist/index.js"
  '';

  meta = {
    description = "MCP server for Artifact Hub (Helm charts)";
    homepage = "https://github.com/AlexW00/artifacthub-mcp";
    license = lib.licenses.mit;
    mainProgram = "artifacthub-mcp";
    platforms = lib.platforms.linux;
  };
})
