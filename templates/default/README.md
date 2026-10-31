# CHANGE ME

One line on what this repo provides.

## Develop

Needs Nix and devenv.

```sh
devenv allow     # auto-activates the shell on cd (after `devenv hook`)
fmt              # format and lint
check            # nix flake check
docs-build       # static docs to ./result-docs; open index.html from disk
devenv up        # live docs on :8981 and slides on :8982
```

Editor: VS Code with the Nix IDE extension uses `.vscode/settings.json`
(nixd hints from this flake's nixpkgs, flake-parts and NixOS options;
alejandra on format). Start it from the devenv shell, or install nixd
yourself, so `nixd` is on PATH.
