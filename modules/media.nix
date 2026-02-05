{pkgs, pkgs-stable, ...}:
let
  grayjay = pkgs.buildFHSEnv {
    name = "grayjay";
    targetPkgs = pkgs: with pkgs; [
      libz
      icu
      libgbm
      openssl

      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libxcb

      gtk3
      glib
      nss
      nspr
      dbus
      atk
      cups
      libdrm
      expat
      libxkbcommon
      pango
      cairo
      udev
      alsa-lib
      mesa
      libGL
      libsecret
    ];
    runScript = pkgs.writeShellScript "grayjay-wrapper" ''
      GRAYJAY_DIR="$HOME/.local/share/grayjay"

      # Find existing Grayjay binary in any versioned subdirectory
      GRAYJAY_BIN=$(find "$GRAYJAY_DIR" -maxdepth 2 -name "Grayjay" -type f 2>/dev/null | head -n1)

      if [ -z "$GRAYJAY_BIN" ] || [ ! -x "$GRAYJAY_BIN" ]; then
        echo "Grayjay not found. Downloading..."
        mkdir -p "$GRAYJAY_DIR"
        cd "$GRAYJAY_DIR"
        ${pkgs.curl}/bin/curl -L -o grayjay.zip "https://updater.grayjay.app/Apps/Grayjay.Desktop/Grayjay.Desktop-linux-x64.zip"
        ${pkgs.unzip}/bin/unzip -o grayjay.zip
        rm grayjay.zip

        # Find the extracted directory and make binary executable
        GRAYJAY_BIN=$(find "$GRAYJAY_DIR" -maxdepth 2 -name "Grayjay" -type f | head -n1)
        chmod +x "$GRAYJAY_BIN"
      fi

      cd "$(dirname "$GRAYJAY_BIN")"
      exec "$GRAYJAY_BIN" "$@"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    fcast-receiver
    grayjay
    finamp
    streamrip
    #vlc but good
    mpv
    # music and podcast
    cmus
    # comic conversion to kobo format
    pkgs-stable.kcc
    cbconvert
    # ipod rockbox installation
    rockbox-utility
    idevicerestore
    slskd
    # youtube but without google
    yt-dlp
    ytfzf
    youtube-tui
    # media control
    playerctl
    ## netflix but good
    #jellyfin-media-player
    ## jellyfin but without a server
    #stremio
    # pdf reader
    zathura
    # library reader
    (pkgs.callPackage ../derivations/thorium.nix {})
  ];
}
