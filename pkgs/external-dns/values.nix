# Canonical fleet-uniform external-dns profile: upstream defaults. Provider and
# credentials are deliberately absent (SPEC D31) — the consumer's GitOps layer
# sets them. `policy` is the one exception: the chart's values.schema.json
# marks it required with no default, so the canonical profile pins the
# non-destructive choice (never deletes DNS records).
{
  policy = "upsert-only";
}
