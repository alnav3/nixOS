{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./../../modules # Import all modules
  ];

  # =============================================================================
  # Module Configuration - base + desktop only (minimal laptop setup)
  # =============================================================================

  mymodules = {
    # Base system configuration
    base = {
      enable = true;
      user.extraGroups = [
        "wheel"
        "networkmanager"
        "bluetooth"
        "audio"
        "input"
        "video"
      ];
    };

    # Desktop environment (Hyprland)
    desktop = {
      enable = true;
      login = {
        enable = false; # We're using SDDM directly below instead of greetd
      };
      hyprland = {
        enable = true;
        xwayland = true;
      };
      stylix = {
        enable = true;
        theme = "catppuccin-mocha";
        polarity = "dark";
      };
      apps = {
        browser = true;
        fileManager = true;
        notifications = true;
        screenshots = true;
        screenRecording = true;
        localsend = true;
      };
    };

    # Development (minimal core)
    development = {
      enable = true;
      shell = {
        zsh.enable = true;
        direnv = true;
      };
      languages = {
        nix = true;
      };
      editor = {
        neovim = true;
        tmux = true;
      };
      git = {
        enable = true;
      };
    };

    # Media (basics)
    media = {
      enable = true;
      video = {
        mpv = true;
      };
      audio = {
        playerctl = true;
      };
      youtube = {
        grayjay = true;
        ytdlp = true;
      };
      jellyfin = {
        mediaPlayer = true;
      };
      documents = {
        zathura = true;
      };
      social = {
        enable = true;
        discord = true;
      };
    };

    # Networking
    networking = {
      enable = true;
      networkManager = true;
      dns = {
        resolved = true;
        dnssec = true;
      };
      ipv6.enable = false;
      firewall = {
        enable = true;
        allowedTCPPorts = [ 53317 ];
        allowedUDPPorts = [ 53317 ];
      };
      diagnostics = true;
    };

    # Hardware - bluetooth and battery only (no GPU module needed; surface module
    # handles Intel GPU bits)
    hardware = {
      bluetooth = {
        enable = true;
        powerManagement = {
          enable = true;
          disableOnBattery = true;
        };
        audio = {
          mprisProxy = true;
          highQuality = true;
        };
        ui = {
          blueman = true;
          rofiBluetooth = true;
        };
      };

      battery = {
        enable = true;
        tlp.enable = true;
        tlp.chargeThresholds = {
          start = 40;
          stop = 80;
        };
        suspend = {
          lidAction = "suspend-then-hibernate";
          lidActionOnAC = "lock";
        };
      };
    };
  };

  # =============================================================================
  # Surface-specific configuration
  # =============================================================================

  # Use the surface kernel as we did in the minimal config
  hardware.microsoft-surface.kernelVersion = "stable";
  hardware.firmware = with pkgs; [ linux-firmware ];

  # Thermal + touchscreen/stylus daemon (from minimal config)
  services.thermald.enable = true;
  services.iptsd = {
    enable = true;
    config.Touchscreen = {
      DisableOnPalm = false;
      DisableOnStylus = true;
    };
  };

  # Bootloader (systemd-boot, matching minimal config)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ---------------------------------------------------------------------------
  # Login manager: greetd + regreet (replaces SDDM)
  # ---------------------------------------------------------------------------
  # regreet is a GTK-based greetd greeter. The NixOS module auto-wires it
  # into greetd inside a cage Wayland compositor, and Stylix's GTK target
  # paints it in Catppuccin Mocha so it matches the rest of the desktop.
  #
  # OSK: we use wvkbd-mobintl (the same OSK used on the locked Hyprland
  # session) because it draws itself via wlr-layer-shell, which cage
  # supports out of the box. squeekboard depends on input-method-v2 +
  # DBus handshakes that don't survive inside cage (it crashes silently).
  # wvkbd is launched as a layer-shell overlay pinned to the bottom of
  # the screen and stays visible for the whole greeter session.
  programs.regreet = {
    enable = true;
    settings = {
      GTK = {
        application_prefer_dark_theme = true;
      };
      commands = {
        reboot = [ "systemctl" "reboot" ];
        poweroff = [ "systemctl" "poweroff" ];
      };
    };
  };

# ---------------------------------------------------------------------------
  # Login manager: greetd + regreet under sway (NOT cage)
  # ---------------------------------------------------------------------------
  # regreet runs inside a tiny sway session whose only job is to display the
  # greeter and the on-screen keyboard, then exit. We use sway instead of
  # cage because cage does NOT implement wlr-layer-shell
  # (https://github.com/cage-kiosk/cage/issues/95), and wvkbd needs
  # layer-shell to draw itself as an overlay. wvkbd will start under cage
  # but have nowhere to render — that's why the OSK was invisible.
  #
  # Sway supports layer-shell and virtual-keyboard-v1, so wvkbd both shows
  # and successfully injects keystrokes into regreet.
  services.greetd.settings.default_session.command = lib.mkForce (
    let
      greeterSwayConfig = pkgs.writeText "greetd-sway-config" ''
        # No borders/titlebars; regreet is the only tiled window so it fills
        # the screen automatically.
        default_border none
        default_floating_border none
        hide_edge_borders --i3 both
        font pango:monospace 0
        seat * hide_cursor 8000

        # Propagate env to anything that needs it (xdg-portals, etc.)
        exec ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
             WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway

        # On-screen keyboard as a layer-shell overlay, ~280 px tall,
        # anchored to the bottom of the screen by default.
        exec ${pkgs.wvkbd}/bin/wvkbd-mobintl -L 280

        # Run regreet; when it exits (successful login or quit), tear sway
        # down so greetd can hand off to the user session.
        exec "${pkgs.greetd.regreet}/bin/regreet; ${pkgs.sway}/bin/swaymsg exit"

        # Emergency escape hatch in case the greeter wedges and you have a
        # physical keyboard attached. Ctrl+Alt+Fn VT switching also works.
        bindsym Mod4+shift+e exec ${pkgs.sway}/bin/swaymsg exit
      '';
    in
      "${pkgs.sway}/bin/sway --config ${greeterSwayConfig}"
  );

  # SDDM is no longer used; make sure it stays off if anything tries to
  # enable it transitively.
  services.displayManager.sddm.enable = lib.mkForce false;



  # Virtual keyboard support (useful for the tablet form-factor)
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
  };

  programs.gtklock = {
    enable = true;
    modules = with pkgs; [
      gtklock-virtkb-module
      gtklock-powerbar-module
    ];
  };

  security.pam.services.gtklock = {};
  environment.systemPackages = with pkgs; [
    jq
    gtklock
    # Tablet ergonomics
    wvkbd        # on-screen keyboard (used by lock screen + login greeter)
    nwg-drawer   # touch-friendly app drawer (resident, signalled to show)
    hyprlock     # lockscreen that supports OSK overlay (unlike noctalia)
    # Custom lock wrapper: starts wvkbd visibly, then gtklock, then cleans up
    (writeShellScriptBin "noctalia-shell ipc call lockScreen lock" ''
      set -e
      # Start wvkbd visibly (not --hidden); lock screen needs OSK ready.
      ${wvkbd}/bin/wvkbd-mobintl -L 280 &
      KBD_PID=$!
      trap "kill $KBD_PID 2>/dev/null || true" EXIT
      ${gtklock}/bin/gtklock
    '')
  ];

  # Enable hyprlock pam config (required for hyprlock to authenticate)
  security.pam.services.hyprlock = {};

  nixpkgs.config.allowUnfree = true;

  # ===========================================================================
  # Surface Pro 8 power/volume button fix
  # ===========================================================================
  # The SP8's power and volume rocker are exposed as ACPI device MSHW0040,
  # which is meant to be driven by `soc_button_array`. The driver has the
  # correct module alias (`acpi:MSHW0040:*`) and gets autoloaded, and the
  # device shows up in /sys/bus/platform/devices/MSHW0040:00 - but the kernel
  # intermittently fails to auto-bind the driver to the device at boot.
  # When the bind doesn't happen, no input devices are created and the
  # buttons appear completely dead until reboot (and sometimes after reboot
  # too, until you get lucky). Manually writing the device name into the
  # driver's `bind` sysfs file makes it probe and create the gpio-keys
  # input devices for the buttons.
  #
  # We do this via a oneshot service rather than a udev rule because the
  # platform device is registered very early (before udev coldplug), so a
  # udev ACTION=="add" rule wouldn't necessarily fire for it.
  systemd.services.surface-button-bind = {
    description = "Bind soc_button_array to MSHW0040 (Surface power/volume buttons)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Only bind if not already bound. Ignore errors so reboots after a
      # successful auto-bind don't fail the service.
      ExecStart = pkgs.writeShellScript "surface-button-bind" ''
        dev=/sys/bus/platform/devices/MSHW0040:00
        drv=/sys/bus/platform/drivers/soc_button_array

        if [ ! -e "$dev" ]; then
          echo "MSHW0040:00 device not present, skipping"
          exit 0
        fi

        if [ -e "$dev/driver" ]; then
          echo "MSHW0040:00 already bound to $(readlink "$dev/driver")"
          exit 0
        fi

        if [ ! -d "$drv" ]; then
          echo "soc_button_array driver not loaded, loading"
          ${pkgs.kmod}/bin/modprobe soc_button_array || true
        fi

        echo "Binding MSHW0040:00 to soc_button_array"
        echo MSHW0040:00 > "$drv/bind"
      '';
    };
  };

  # ===========================================================================
  # Touch / tablet automation: auto-toggle on-screen keyboard when the
  # Type Cover is physically attached/detached.
  # ===========================================================================
  # udev fires the user target whenever a Type Cover input device is added or
  # removed; the user service checks for the device presence and signals wvkbd.
  # (Folded-back-but-still-attached state is unreliable on the SP8 kernel,
  # so we only react to physical detach. Manual toggle: $mainMod+K or top-edge
  # swipe down.)
  services.udev.extraRules = ''
    # Adjust ATTRS{name} if your Type Cover advertises a different name.
    # Discover with: udevadm info -a -n /dev/input/event<N>
    ACTION=="add",    SUBSYSTEM=="input", ATTRS{name}=="*Surface*Type*Cover*", \
      TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="osk-update.service"
    ACTION=="remove", SUBSYSTEM=="input", ATTRS{name}=="*Surface*Type*Cover*", \
      TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="osk-update.service"
  '';

  systemd.user.services.osk-update = {
    description = "Toggle on-screen keyboard based on Type Cover presence";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "osk-update" ''
        set -eu
        if ${pkgs.bash}/bin/bash -c "compgen -G '/dev/input/by-id/*Type_Cover*'" > /dev/null \
        || ${pkgs.bash}/bin/bash -c "compgen -G '/dev/input/by-id/*Surface_Keyboard*'" > /dev/null; then
          # Physical keyboard present -> hide OSK
          ${pkgs.procps}/bin/pkill -USR1 wvkbd-mobintl || true
        else
          # No physical keyboard -> show OSK
          ${pkgs.procps}/bin/pkill -USR2 wvkbd-mobintl || true
        fi
      ''}";
    };
  };

  # =============================================================================
  # Home Manager Configuration
  # =============================================================================

  home-manager = {
    useUserPackages = true;
    users.alnav = { pkgs, lib, inputs, ... }: {
      imports = [ ../../home-modules ];

      myhome = {
        user.enable = true;

        git.enable = true;
        jdk.enable = false;

        kitty.enable = true;

        hyprpanel.enable = true;

        neovim = {
          enable = true;
          javaSupport = false;
        };

        dotfiles = {
          enable = true;
          zsh.enable = true;
          nvim.enable = true;
          hypr = {
            enable = true;
            # HM's wayland.windowManager.hyprland (below) owns hyprland.conf
            # and hyprpaper.conf, so skip those entries from the dotfile bundle.
            skipMainConf = true;
            skipHyprpaper = true;
          };
          hyprdynamicmonitors.enable = true;
          hyprpanel.enable = true;
          noctalia.enable = true;
          nwgDrawer.enable = true;
          rofi.enable = true;
          tmux.enable = true;
          wallpapers.enable = true;
          llmLs.enable = false;
        };
      };

      # Load Hyprland plugins via home-manager. Plugin .so paths must come
      # from the same Hyprland package the system is running.
      # HM owns ~/.config/hypr/hyprland.conf; we source the static dotfile
      # content from the nix store and then layer touch.conf on top.
      wayland.windowManager.hyprland = {
        enable = true;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
        plugins = [
          inputs.hyprgrass.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
        extraConfig = ''
          source = ${../../dotfiles/hypr/hyprland.conf}
          source = ${./touch.conf}
        '';
      };

      # hyprland.conf sources ~/.config/hypr/monitors.conf, which is
      # generated by hyprdynamicmonitors at runtime. Seed an empty file
      # so the source line doesn't error on first boot.
      home.activation.seedMonitorsConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        target="$HOME/.config/hypr/monitors.conf"
        if [ ! -e "$target" ]; then
          run mkdir -p "$(dirname "$target")"
          run touch "$target"
        fi
      '';
    };
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit inputs;
      meta = { name = "surface"; system = "x86_64-linux"; useHomeManager = true; isWsl = false; };
    };
  };
}
