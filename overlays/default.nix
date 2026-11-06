final: prev:
(prev.lib.composeManyExtensions [
  (import ./kubernetes.nix)
  (import ./ifstate.nix)
  (import ./tools.nix)
])
final
prev
