# containers/kubernetes-mcp-server: MCP server for Kubernetes and OpenShift
# (kubectl + helm toolsets, stdio transport). Hermetic Go build from the
# pinned upstream tag; no npx or docker at runtime.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule (finalAttrs: {
  pname = "kubernetes-mcp-server";
  version = "0.0.66";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "kubernetes-mcp-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vnJxSCfnpvOZJXQpKrCAW4QKt5R2PJDYQevA7O1uXZg=";
  };

  vendorHash = "sha256-gbqoT4X+wVOEktHm7jaAH9vHrUBrYgR8OjyFz1ljP6k=";

  env.CGO_ENABLED = "0";

  # The unit tests need a live cluster.
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
    "-X github.com/containers/kubernetes-mcp-server/pkg/version.Version=${finalAttrs.version}"
  ];

  meta = {
    description = "MCP server for Kubernetes and OpenShift";
    homepage = "https://github.com/containers/kubernetes-mcp-server";
    license = lib.licenses.asl20;
    mainProgram = "kubernetes-mcp-server";
    platforms = lib.platforms.linux;
  };
})
