{ lib
, stdenv
, fetchurl
, appimageTools
, makeDesktopItem
, copyDesktopItems
}:

let
  pname = "emudeck";
  version = "2.5.0";

  src = fetchurl {
    url = "https://github.com/EmuDeck/emudeck-electron/releases/download/v${version}/EmuDeck-${version}.AppImage";
    sha256 = "sha256-e0uJhWfCq8x+vnkVALNKsqrcjCoj0XVNI9MUIVtPzGY=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };

in
stdenv.mkDerivation {
  inherit pname version;

  src = appimageTools.wrapType2 {
    inherit pname version src;
  };

  nativeBuildInputs = [ copyDesktopItems ];

  desktopItems = [
    (makeDesktopItem {
      name = "emudeck";
      desktopName = "EmuDeck";
      comment = "Emulator configuration tool";
      exec = "emudeck";
      icon = "emudeck";
      categories = [ "Game" "Utility" ];
      terminal = false;
    })
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp $src/bin/emudeck $out/bin/emudeck

    # Extract icon from AppImage contents
    mkdir -p $out/share/icons/hicolor/256x256/apps
    if [ -f ${appimageContents}/emudeck.png ]; then
      cp ${appimageContents}/emudeck.png $out/share/icons/hicolor/256x256/apps/emudeck.png
    elif [ -f ${appimageContents}/.DirIcon ]; then
      cp ${appimageContents}/.DirIcon $out/share/icons/hicolor/256x256/apps/emudeck.png
    fi

    runHook postInstall
  '';

  dontStrip = true;
  dontPatchELF = true;

  meta = with lib; {
    description = "Emulator configuration tool for Steam Deck and Linux";
    homepage = "https://github.com/EmuDeck/emudeck-electron";
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "emudeck";
  };
}
