# Canonical fleet-uniform sealed-secrets profile: upstream defaults plus the
# documented upstream convention of deploying the controller as
# `sealed-secrets-controller` (kubeseal defaults to that name, so the render
# matches what the CLI expects out of the box).
{
  fullnameOverride = "sealed-secrets-controller";
}
