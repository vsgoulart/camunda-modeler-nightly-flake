{
  description = "Camunda Modeler nightly";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      version = "5.52.0-nightly.2026-10-08";
      sources = {
        x86_64-linux = {
          url = "https://downloads.camunda.cloud/release/camunda-modeler/nightly/camunda-modeler-nightly-linux-x64.tar.gz";
          hash = "sha256-bYiK7OyGT55fmCp1A44Mx2ne3yXMn4oHaON/fyxp74s=";
        };
        aarch64-darwin = {
          url = "https://downloads.camunda.cloud/release/camunda-modeler/nightly/camunda-modeler-nightly-mac-arm64.dmg";
          hash = "sha256-PT7N89PQlOvYSZHuILZRr4uY7VtKarA8dy099MYNqHI=";
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
            if pkgs.stdenv.hostPlatform.isLinux then
              [
                pkgs.makeWrapper
                pkgs.copyDesktopItems
              ]
            else
              [ pkgs.undmg ];

          sourceRoot = if pkgs.stdenv.hostPlatform.isLinux then "camunda-modeler-nightly-linux-x64" else ".";
          dontBuild = true;

          installPhase =
            if pkgs.stdenv.hostPlatform.isLinux then
              ''
                runHook preInstall

                mkdir -p "$out/bin" "$out/share/camunda-modeler-nightly"
                cp -R locales resources "$out/share/camunda-modeler-nightly/"
                makeWrapper ${pkgs.electron}/bin/electron "$out/bin/camunda-modeler-nightly" \
                  --add-flags "$out/share/camunda-modeler-nightly/resources/app.asar"
                ln -s camunda-modeler-nightly "$out/bin/camunda-modeler"

                install -Dm644 support/mime-types.xml "$out/share/mime/packages/camunda-modeler.xml"
                for size in 16 48 128; do
                  install -Dm644 "support/icon_$size.png" \
                    "$out/share/icons/hicolor/''${size}x''${size}/apps/camunda-modeler.png"
                done

                runHook postInstall
              ''
            else
              ''
                mkdir -p "$out/Applications" "$out/bin"
                cp -R "Camunda Modeler.app" "$out/Applications/"
                ln -s "$out/Applications/Camunda Modeler.app/Contents/MacOS/Camunda Modeler" \
                  "$out/bin/camunda-modeler-nightly"
                ln -s camunda-modeler-nightly "$out/bin/camunda-modeler"
              '';

          # The app identifies itself as "camunda-modeler" (Wayland app_id /
          # X11 WM class), so the entry uses that name for window matching.
          desktopItems = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            (pkgs.makeDesktopItem {
              name = "camunda-modeler";
              desktopName = "Camunda Modeler";
              genericName = "Process Modeling Tool";
              comment = "Nightly build of Camunda Modeler";
              exec = "camunda-modeler-nightly %F";
              icon = "camunda-modeler";
              categories = [ "Development" ];
              keywords = [
                "bpmn"
                "dmn"
                "form"
                "rpa"
                "modeler"
                "camunda"
              ];
              mimeTypes = [
                "application/bpmn"
                "application/dmn"
                "application/camunda-form"
                "application/rpa"
              ];
              startupNotify = true;
              startupWMClass = "camunda-modeler";
            })
          ];

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
