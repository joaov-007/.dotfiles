{
  lib,
  stdenv,
  appimageTools,
  fetchurl,
}: let
  pname = "openbot";
  version = "0.80.0";

  sources = {
    x86_64-linux = {
      arch = "x86_64";
      hash = "sha256-DngVvnPznSSOLdn5YX5AhwEFru/iQaj+9P65ALksKUQ=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-pM2rls83HrI1hUmo6gRm4+MnTNhRg9F3ODFOErMaH1o=";
    };
  };

  source =
    sources.${
      stdenv.hostPlatform.system
    } or (throw
      "OpenBot ${version} is not available for ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/nightly-labs/openbot/releases/download/v${version}/OpenBot-${version}-${source.arch}.AppImage";
    inherit (source) hash;
  };

  appimageContents = appimageTools.extract {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -Dm444 ${appimageContents}/*.desktop \
        $out/share/applications/openbot.desktop
      substituteInPlace $out/share/applications/openbot.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=openbot'
      install -Dm444 ${appimageContents}/.DirIcon \
        $out/share/pixmaps/openbot.png
    '';

    meta = {
      description = "Local-first desktop workspace for running teams of AI agents";
      homepage = "https://openbot.run/";
      changelog = "https://github.com/nightly-labs/openbot/releases/tag/v${version}";
      license = lib.licenses.unfree;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = builtins.attrNames sources;
      mainProgram = "openbot";
    };
  }
