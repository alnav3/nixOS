{ config, lib, pkgs, pkgs-stable ? pkgs, ... }:

let
  cfg = config.mymodules.media;
  grayjay = pkgs.buildFHSEnv {
    name = "grayjay";
    targetPkgs = pkgs: with pkgs; [
      libz icu libgbm openssl libX11 libXcomposite libXdamage libXext
      libXfixes libXrandr libxcb gtk3 glib nss nspr dbus atk cups
      libdrm expat libxkbcommon pango cairo udev alsa-lib mesa libGL libsecret
    ];
    runScript = pkgs.writeShellScript "grayjay-wrapper" ''
      GRAYJAY_DIR="$HOME/.local/share/grayjay"
      GRAYJAY_BIN=$(find "$GRAYJAY_DIR" -maxdepth 2 -name "Grayjay" -type f 2>/dev/null | head -n1)
      if [ -z "$GRAYJAY_BIN" ] || [ ! -x "$GRAYJAY_BIN" ]; then
        echo "Grayjay not found. Downloading..."
        mkdir -p "$GRAYJAY_DIR"
        cd "$GRAYJAY_DIR"
        ${pkgs.curl}/bin/curl -L -o grayjay.zip "https://updater.grayjay.app/Apps/Grayjay.Desktop/Grayjay.Desktop-linux-x64.zip"
        ${pkgs.unzip}/bin/unzip -o grayjay.zip
        rm grayjay.zip
        GRAYJAY_BIN=$(find "$GRAYJAY_DIR" -maxdepth 2 -name "Grayjay" -type f | head -n1)
        chmod +x "$GRAYJAY_BIN"
      fi
      cd "$(dirname "$GRAYJAY_BIN")"
      exec "$GRAYJAY_BIN" "$@"
    '';
  };
in
{
  options.mymodules.media = {
    enable = lib.mkEnableOption "Media applications";

    # Video players
    video = {
      mpv = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable MPV video player";
      };

      obs = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable OBS Studio for streaming/recording";
      };
    };

    # Music/Audio
    audio = {
      cmus = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable cmus terminal music player";
      };

      finamp = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Finamp Jellyfin client";
      };

      playerctl = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable playerctl for media controls";
      };
    };

    # YouTube alternatives
    youtube = {
      grayjay = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Grayjay (YouTube alternative)";
      };

      ytdlp = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable yt-dlp for video downloads";
      };

      ytfzf = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable ytfzf for terminal YouTube";
      };
    };

    # Document/Book readers
    documents = {
      zathura = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Zathura PDF reader";
      };

      thorium = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Thorium eBook reader";
      };

      kcc = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable KCC comic converter";
      };
    };

    # iPod/Portable devices
    portable = {
      rockbox = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Rockbox utility for iPods";
      };
    };

    # Soulseek
    soulseek = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Soulseek (slskd) for music sharing";
    };

    # Casting
    casting = {
      fcast = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable FCast receiver";
      };
    };

    # Music streaming tools
    streaming = {
      streamrip = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable streamrip for music downloads";
      };
    };

    # Communication apps (social)
    social = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable social/communication apps";
      };

      discord = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Discord (Vesktop)";
      };

      signal = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Signal messenger";
      };

      telegram = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Telegram client";
      };

      teamspeak = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable TeamSpeak client";
      };

      revolt = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Revolt chat";
      };
    };

    # Email
    mail = {
      thunderbird = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Thunderbird email client";
      };
    };

    # Backup
    backup = {
      pikaBackup = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Pika Backup";
      };
    };

    # 3D Printing
    printing3d = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable 3D printing tools";
      };
    };

    # Extra packages
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional media packages";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base media config
    {
      environment.systemPackages = cfg.extraPackages;
    }

    # MPV
    (lib.mkIf cfg.video.mpv {
      environment.systemPackages = [ pkgs.mpv ];
    })

    # OBS
    (lib.mkIf cfg.video.obs {
      environment.systemPackages = [ pkgs.obs-studio ];
    })

    # cmus
    (lib.mkIf cfg.audio.cmus {
      environment.systemPackages = [ pkgs.cmus ];
    })

    # Finamp
    (lib.mkIf cfg.audio.finamp {
      environment.systemPackages = [ pkgs.finamp ];
    })

    # playerctl
    (lib.mkIf cfg.audio.playerctl {
      environment.systemPackages = [ pkgs.playerctl ];
    })

    # Grayjay
    (lib.mkIf cfg.youtube.grayjay {
      environment.systemPackages = [ grayjay ];
    })

    # yt-dlp
    (lib.mkIf cfg.youtube.ytdlp {
      environment.systemPackages = [ pkgs.yt-dlp ];
    })

    # ytfzf
    (lib.mkIf cfg.youtube.ytfzf {
      environment.systemPackages = with pkgs; [ ytfzf youtube-tui ];
    })

    # Zathura
    (lib.mkIf cfg.documents.zathura {
      environment.systemPackages = [ pkgs.zathura ];
    })

    # Thorium
    (lib.mkIf cfg.documents.thorium {
      environment.systemPackages = [ (pkgs.callPackage ../derivations/thorium.nix {}) ];
    })

    # KCC
    (lib.mkIf cfg.documents.kcc {
      environment.systemPackages = [ pkgs-stable.kcc ];
    })

    # Rockbox
    (lib.mkIf cfg.portable.rockbox {
      environment.systemPackages = with pkgs; [ rockbox-utility idevicerestore ];
    })

    # Soulseek
    (lib.mkIf cfg.soulseek {
      environment.systemPackages = [ pkgs.slskd ];
    })

    # FCast
    (lib.mkIf cfg.casting.fcast {
      environment.systemPackages = [ pkgs.fcast-receiver ];
    })

    # Streamrip
    (lib.mkIf cfg.streaming.streamrip {
      environment.systemPackages = [ pkgs.streamrip ];
    })

    # Social apps
    (lib.mkIf cfg.social.enable (lib.mkMerge [
      (lib.mkIf cfg.social.discord {
        environment.systemPackages = [ pkgs-stable.vesktop ];
      })
      (lib.mkIf cfg.social.signal {
        environment.systemPackages = [ pkgs.signal-desktop ];
      })
      (lib.mkIf cfg.social.telegram {
        environment.systemPackages = with pkgs; [ tg _64gram ];
      })
      (lib.mkIf cfg.social.teamspeak {
        environment.systemPackages = [ pkgs.teamspeak6-client ];
      })
      (lib.mkIf cfg.social.revolt {
        environment.systemPackages = [ pkgs.revolt-desktop ];
      })
    ]))

    # Thunderbird
    (lib.mkIf cfg.mail.thunderbird {
      environment.systemPackages = [ pkgs.thunderbird ];
    })

    # Pika Backup
    (lib.mkIf cfg.backup.pikaBackup {
      environment.systemPackages = with pkgs; [ pika-backup glib.bin glib.dev ];
      services.gvfs = {
        enable = true;
        package = lib.mkForce pkgs.gnome.gvfs;
      };
    })

    # 3D Printing
    (lib.mkIf cfg.printing3d.enable {
      environment.systemPackages = with pkgs; [ orca-slicer openscad freecad ];
      nixpkgs.config.permittedInsecurePackages = [ "libsoup-2.74.3" ];
    })
  ]);
}
