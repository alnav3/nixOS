{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.gaming;
  mlib = import ./_lib { inherit lib; };
in
{
  options.mymodules.gaming = {
    enable = lib.mkEnableOption "Gaming support";

    # Steam configuration
    steam = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Steam gaming platform";
      };

      gamescope = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Gamescope compositor for gaming";
      };
    };

    # SteamOS-like experience (for HTPC/TV setup)
    steamos = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable SteamOS-like experience (for HTPC)";
      };

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Auto-start Steam on boot";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = mlib.helpers.defaultUser;
        description = "User for Steam session";
      };

      deckyLoader = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Decky Loader for Steam Deck plugins";
      };

      frameGeneration = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable LSFG-VK frame generation";
      };
    };

    # Non-Steam game launchers
    launchers = {
      lutris = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Lutris game launcher";
      };

      heroic = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Heroic launcher (Epic/GOG)";
      };

      bottles = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Bottles for Windows games";
      };
    };

    # Emulation
    emulation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable emulation support";
      };

      retroDeck = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable RetroDeck via Flatpak";
      };

      switch = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Nintendo Switch emulation (Ryujinx)";
      };
    };

    # Performance tools
    performance = {
      mangohud = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable MangoHud overlay";
      };

      protonTools = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Proton management tools";
      };
    };

    # Android gaming (Waydroid)
    android = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Waydroid for Android apps/games";
      };

      tools = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Android development/debugging tools (adb, debloater)";
      };
    };

    # TV media apps (for HTPC)
    tvMedia = {
      kodi = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Kodi media center";
      };
    };

    # Extra packages
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional gaming packages";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base gaming configuration
    {
      # Graphics support
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      services.xserver.videoDrivers = [ "amdgpu" ];

      # Steam compatibility tools path
      environment.sessionVariables = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
      };

      # Allow unfree Steam packages
      nixpkgs.config.allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [
          "steam"
          "steam-original"
          "steam-run"
          "steam-jupiter-original"
          "steam-jupiter-unwrapped"
          "steamdeck-hw-theme"
        ];

      environment.systemPackages = cfg.extraPackages;
    }

    # Steam
    (lib.mkIf cfg.steam.enable {
      programs.steam = {
        enable = true;
        gamescopeSession.enable = cfg.steam.gamescope && !cfg.steamos.enable;
      };

      # Only enable gamescope if steamos is not enabled (Jovian handles it otherwise)
      programs.gamescope = lib.mkIf (cfg.steam.gamescope && !cfg.steamos.enable) {
        enable = true;
        capSysNice = true;
      };

      # Desktop mode exit script
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "steamos-session-select" ''
          steam -shutdown & exec Hyprland
        '')
      ];
    })

    # SteamOS mode - basic packages (Jovian config applied in machine config)
    (lib.mkIf cfg.steamos.enable {
      services.xserver.enable = true;

      # SteamOS exit script
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "steamos-session-select" ''
          steam -shutdown
        '')
        pkgs.protontricks
      ];
    })

    # Decky Loader packages
    (lib.mkIf (cfg.steamos.enable && cfg.steamos.deckyLoader) {
      environment.systemPackages = with pkgs; [
        python3
        wget
        p7zip
      ];
    })

    # Lutris
    (lib.mkIf cfg.launchers.lutris {
      environment.systemPackages = [ pkgs.lutris ];
    })

    # Heroic
    (lib.mkIf cfg.launchers.heroic {
      environment.systemPackages = [ pkgs.heroic ];
    })

    # Bottles
    (lib.mkIf cfg.launchers.bottles {
      environment.systemPackages = [ pkgs.bottles ];
    })

    # Emulation base
    (lib.mkIf cfg.emulation.enable {
      # Flatpak for emulation
      services.flatpak.enable = true;
    })

    # RetroDeck
    (lib.mkIf (cfg.emulation.enable && cfg.emulation.retroDeck) {
      services.flatpak = {
        enable = true;
        remotes = [{
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }];
        packages = [
          { appId = "net.retrodeck.retrodeck"; origin = "flathub"; }
        ];
      };
    })

    # Switch emulation
    (lib.mkIf (cfg.emulation.enable && cfg.emulation.switch) {
      environment.systemPackages = [ pkgs.ryubing ];
    })

    # MangoHud
    (lib.mkIf cfg.performance.mangohud {
      environment.systemPackages = [ pkgs.mangohud ];
    })

    # Proton tools
    (lib.mkIf cfg.performance.protonTools {
      environment.systemPackages = with pkgs; [
        protonup-ng
        steamtinkerlaunch
      ];
    })

    # Android (Waydroid)
    (lib.mkIf cfg.android.enable {
      networking.nftables.enable = true;
      virtualisation.waydroid.enable = true;

      networking.firewall.trustedInterfaces = [ "waydroid0" ];

      environment.systemPackages = with pkgs; [
        scrcpy
        wlr-randr
        cage
        iptables-nftables-compat
        xorg.xdpyinfo
      ];

      # Steam Deck controller key layout for Waydroid
      environment.etc."waydroid-keylayout/Vendor_28de_Product_11ff.kl" = {
        text = ''
          # Steam Deck Controller - USB
          key 304   BUTTON_A
          key 305   BUTTON_B
          key 307   BUTTON_X
          key 308   BUTTON_Y
          key 310   BUTTON_L1
          key 311   BUTTON_R1
          axis 0x02 LTRIGGER
          axis 0x05 RTRIGGER
          axis 0x00 X
          axis 0x01 Y
          axis 0x03 Z
          axis 0x04 RZ
          key 317   BUTTON_THUMBL
          key 318   BUTTON_THUMBR
          axis 0x10 HAT_X
          axis 0x11 HAT_Y
          key 314   BUTTON_SELECT
          key 315   BUTTON_START
          key 316   BUTTON_MODE
        '';
        mode = "0644";
      };

      system.activationScripts.waydroid-keylayout = ''
        mkdir -p /var/lib/waydroid/overlay/system/usr/keylayout
        if [ -f /etc/waydroid-keylayout/Vendor_28de_Product_11ff.kl ]; then
          cp /etc/waydroid-keylayout/Vendor_28de_Product_11ff.kl /var/lib/waydroid/overlay/system/usr/keylayout/
          chmod 644 /var/lib/waydroid/overlay/system/usr/keylayout/Vendor_28de_Product_11ff.kl
        fi
      '';
    })

    # Android tools (adb, debloater)
    (lib.mkIf cfg.android.tools {
      environment.systemPackages = with pkgs; [
        android-tools
        universal-android-debloater
      ];
    })

    # Kodi
    (lib.mkIf cfg.tvMedia.kodi {
      services.xserver.desktopManager.kodi = {
        enable = true;
        package = pkgs.kodi-wayland.withPackages (kodiPkgs: with kodiPkgs; [
          inputstream-adaptive
        ]);
      };
    })
  ]);
}
