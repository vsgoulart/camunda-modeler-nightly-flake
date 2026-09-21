{
  description = "Camunda Modeler nightly";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      version = "5.51.1-nightly.2026-09-21";
      sources = {
        x86_64-linux = {
          url = "https://downloads.camunda.cloud/release/camunda-modeler/nightly/camunda-modeler-nightly-linux-x64.tar.gz";
          hash = "sha256-TSnkHSPTxxjftr/KJLAE4NprIprjlU1ZTtAgjNk6UdQ=";
        };
        aarch64-darwin = {
          url = "https://downloads.camunda.cloud/release/camunda-modeler/nightly/camunda-modeler-nightly-mac-arm64.dmg";
          hash = "sha256-Zp0xclTbgw/OR+bmMi0LkMHzZ+W4Y//18V+FREP+XMw=";
        };
      };
      forAllSystems = nixpkgs.lib.genAttrs (builtins.attrNames sources);
      packageFor =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          source = sources.${system};
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "camunda-modeler-nightly";
          inherit version;
          src = pkgs.fetchurl source;

          nativeBuildInputs =
            if pkgs.stdenv.hostPlatform.isLinux then [ pkgs.makeWrapper ] else [ pkgs.undmg ];

          sourceRoot = if pkgs.stdenv.hostPlatform.isLinux then "camunda-modeler-nightly-linux-x64" else ".";
          dontBuild = true;

          installPhase =
            if pkgs.stdenv.hostPlatform.isLinux then
              ''
                mkdir -p "$out/bin" "$out/share/camunda-modeler-nightly"
                cp -R locales resources "$out/share/camunda-modeler-nightly/"
                makeWrapper ${pkgs.electron}/bin/electron "$out/bin/camunda-modeler-nightly" \
                  --add-flags "$out/share/camunda-modeler-nightly/resources/app.asar"
              ''
            else
              ''
                mkdir -p "$out/Applications" "$out/bin"
                cp -R "Camunda Modeler.app" "$out/Applications/"
                ln -s "$out/Applications/Camunda Modeler.app/Contents/MacOS/Camunda Modeler" \
                  "$out/bin/camunda-modeler-nightly"
              '';

          meta = {
            description = "Nightly build of Camunda Modeler";
            homepage = "https://github.com/camunda/camunda-modeler";
            license = pkgs.lib.licenses.mit;
            platforms = builtins.attrNames sources;
            mainProgram = "camunda-modeler-nightly";
          };
        };
    in
    {
      packages = forAllSystems (system: {
        default = packageFor system;
      });
    };
}
