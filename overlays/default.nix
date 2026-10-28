final: prev:
(prev.lib.composeManyExtensions [
  (import ./kubernetes.nix)
  (import ./ifstate.nix)
])
final
prev
