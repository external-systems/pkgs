# VS Code extensions that nixpkgs doesn't package, pinned from Open VSX
# (the registry VSCodium uses). Each entry is publisher, name, version
# and the hash of the .vsix; bump all three together. The hashes match
# nix-community/nix-vscode-extensions' Open VSX cache
# (data/cache/open-vsx-latest.json, field "h"), a handy source for new
# entries.
{
  lib,
  fetchurl,
  vscode-utils,
}: let
  fromOpenVsx = {
    publisher,
    name,
    version,
    hash,
    meta,
  }:
    vscode-utils.buildVscodeMarketplaceExtension {
      mktplcRef = {inherit publisher name version hash;};
      vsix = fetchurl {
        name = "${publisher}-${name}-${version}.vsix";
        url = "https://open-vsx.org/api/${publisher}/${name}/${version}/file/${publisher}.${name}-${version}.vsix";
        inherit hash;
      };
      meta = {platforms = lib.platforms.all;} // meta;
    };
in {
  # Remote - SSH for VSCodium: Microsoft's remote-ssh is licensed for
  # VS Code only and is not on Open VSX.
  jeanp413.open-remote-ssh = fromOpenVsx {
    publisher = "jeanp413";
    name = "open-remote-ssh";
    version = "0.5.1";
    hash = "sha256-JBY4LGA/lJFi1cnbuh/jZ8+TcqIXa7yx+NhKWj7TZMo=";
    meta = {
      description = "Use any remote machine with an SSH server as your development environment";
      homepage = "https://github.com/jeanp413/open-remote-ssh";
      license = lib.licenses.mit;
    };
  };

  # Varlock's @env-spec syntax for .env.schema and .env files.
  varlock.env-spec-language = fromOpenVsx {
    publisher = "varlock";
    name = "env-spec-language";
    version = "0.5.0";
    hash = "sha256-uF/3WKPYh67kekC2H/KS8REqz51xQGQt7NKR0GAx9yE=";
    meta = {
      description = "@env-spec (.env) language support";
      homepage = "https://varlock.dev";
      license = lib.licenses.mit;
    };
  };
}
