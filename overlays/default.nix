final: prev:
(prev.lib.composeManyExtensions [
  (import ./kubernetes.nix)
  (import ./ifstate.nix)
  (import ./tools.nix)
  (import ./vscode-extensions.nix)
])
final
prev
