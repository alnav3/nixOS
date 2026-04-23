{ lib
, stdenv
, fetchurl
, appimageTools
, makeDesktopItem
, copyDesktopItems
}:

let
  pname = "spotiflac";
  version = "7.1.4";

  bundle = fetchurl {
    url = "https://github.com/spotbye/SpotiFLAC/releases/download/v${version}/spotiflac-linux-bundle.tar.gz";
    sha256 = "sha256-5L+okTBF4nJ+60O6y8YrPeSrpcNN3gxjFPVKdEyR8QU=";
  };

  appimage-src = stdenv.mkDerivation {
    name = "${pname}-appimage-${version}";
    src = bundle;
    sourceRoot = ".";
    unpackCmd = "tar -xzf $curSrc";
    installPhase = ''
      cp SpotiFLAC-linux-bundle/SpotiFLAC-amd64.AppImage $out
    '';
    dontFixup = true;
  };

  appimageContents = appimageTools.extract {
    inherit pname version;
    src = appimage-src;
  };

in
stdenv.mkDerivation {
  inherit pname version;

  src = appimageTools.wrapType2 {
    inherit pname version;
    src = appimage-src;

    extraPkgs = pkgs: with pkgs; [
      webkitgtk_4_1
      gtk3
    ];
  };

  nativeBuildInputs = [ copyDesktopItems ];

  desktopItems = [
    (makeDesktopItem {
      name = "spotiflac";
      desktopName = "SpotiFLAC";
      comment = "Get Spotify tracks in true FLAC from Tidal, Qobuz & Amazon Music";
      exec = "spotiflac";
      icon = "spotiflac";
      categories = [ "Audio" "Music" ];
      terminal = false;
    })
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp $src/bin/spotiflac $out/bin/spotiflac

    # Extract icon from AppImage contents
    mkdir -p $out/share/icons/hicolor/256x256/apps
    if [ -f ${appimageContents}/icon.png ]; then
      cp ${appimageContents}/icon.png $out/share/icons/hicolor/256x256/apps/spotiflac.png
    elif [ -f ${appimageContents}/.DirIcon ]; then
      cp ${appimageContents}/.DirIcon $out/share/icons/hicolor/256x256/apps/spotiflac.png
    fi

    runHook postInstall
  '';

  dontStrip = true;
  dontPatchELF = true;

  meta = with lib; {
    description = "Get Spotify tracks in true FLAC from Tidal, Qobuz & Amazon Music";
    homepage = "https://github.com/spotbye/SpotiFLAC";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "spotiflac";
  };
}
