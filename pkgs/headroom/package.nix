# Headroom: context compression layer for AI agents (proxy + MCP server),
# built with uv2nix from the wrapper uv project next to this file
# (pyproject.toml pins headroom-ai, uv.lock holds every profile's deps).
# Wheels only: headroom-ai's own wheel carries its maturin/Rust extension.
#
# One package per upstream dependency profile (an extra of headroom-ai):
#   all     proxy, code, ml, memory, relevance, image, reports, otel,
#           evals, voice, html, mcp, spreadsheet (torch, CPU build)
#   lean    all minus image, ml, memory, evals and voice: torch-free
#   sandbox upstream's deprecated alias of lean
{
  lib,
  callPackage,
  callPackages,
  python313,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  profile ? "all",
}: let
  workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};

  pythonSet =
    (callPackage pyproject-nix.build.packages {python = python313;}).overrideScope
    (lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay {sourcePreference = "wheel";})
      (import ./overrides.nix)
    ]);

  inherit (callPackages pyproject-nix.build.util {}) mkApplication;

  pname =
    if profile == "all"
    then "headroom"
    else "headroom-${profile}";

  app = mkApplication {
    venv = pythonSet.mkVirtualEnv "${pname}-env" {headroom-ai = [profile];};
    package = pythonSet.headroom-ai;
  };
in
  app.overrideAttrs (finalAttrs: old: {
    inherit pname;
    inherit (pythonSet.headroom-ai) version;
    # mkApplication sets name from the package (headroom-ai) itself.
    name = "${pname}-${pythonSet.headroom-ai.version}";
    passthru =
      (old.passthru or {})
      // {
        inherit pythonSet;
        tests = callPackage ./tests.nix {headroom = finalAttrs.finalPackage;};
      };
    meta =
      (old.meta or {})
      // {
        description = "Context compression layer for AI agents (${profile} profile)";
        homepage = "https://github.com/headroomlabs-ai/headroom";
        license = lib.licenses.asl20;
        mainProgram = "headroom";
        platforms = ["x86_64-linux" "aarch64-linux"];
      };
  })
