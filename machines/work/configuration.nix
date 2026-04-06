{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    ./../../modules  # Import all modules
  ];

  # =============================================================================
  # Module Configuration - Work laptop configuration
  # =============================================================================

  mymodules = {
    # Base system configuration
    base = {
      enable = true;
      # Work laptop uses default base settings (SSH, alnav user, mjolnir build key)
      user.extraGroups = [
        "uinput"
        "wheel"
        "docker"
        "audio"
        "input"
        "disk"
        "dialout"
        "networkmanager"
      ];
      vm.enable = true; # Enable VM variant configuration
    };

    # Desktop environment
    desktop = {
      enable = true;
      login = {
        enable = true;
        autoLogin = true;
        user = "alnav";
        session = "hyprland";
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

    # Development environment
    development = {
      enable = true;
      shell = {
        zsh.enable = true;
        direnv = true;
      };
      languages = {
        go = true;
        nodejs = true;
        java = true;
        python = true;
        nix = true;
      };
      infrastructure = {
        kubernetes = true;
        dockerTools = true;
        databases = true;
      };
      editor = {
        neovim = true;
        tmux = true;
        opencode = false;  # Can enable if needed for work
      };
      git = {
        enable = true;
        gitlab = true;
      };
      work.enable = true;      # Teams and work-related tools
      freelance.enable = true;  # Bruno and other API tools
    };

    # Gaming - DISABLED for work laptop
    gaming = {
      enable = false;
    };

    # Media - MINIMAL for work (no entertainment)
    media = {
      enable = true;
      video = {
        mpv = false;  # No video player for work
        obs = true;   # Useful for meetings/presentations
      };
      audio = {
        playerctl = true;  # Control media playback
        finamp = false;    # No music streaming
      };
      youtube = {
        ytdlp = false;  # No YouTube downloading
        grayjay = false;
      };
      documents = {
        zathura = true;   # PDF viewer for work documents
        thorium = false;  # No manga reader
        kcc = false;      # No comic converter
      };
      portable.rockbox = false;
      soulseek = false;  # No P2P music
      casting.fcast = false;
      streaming.streamrip = false;  # No streaming downloads
      social = {
        enable = false;  # No social media apps
        discord = false;
        signal = false;
        telegram = false;
      };
      mail.thunderbird = true;  # Email client for work
      backup.pikaBackup = true;  # Backup important work data
      printing3d.enable = false;
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
        allowedTCPPorts = [ 80 443 8080 ];
        allowedUDPPorts = [];
      };
      diagnostics = true;
    };

    # Virtualisation
    virtualisation = {
      enable = true;
      docker = {
        enable = true;
        batteryOptimized = true;
        autoPrune = {
          enable = true;
          schedule = "daily";
          aggressive = true;
        };
      };
      spice = false;     # Not needed for work
      distrobox = true;  # Useful for testing different environments
      qemu = false;      # Not needed for work initially
    };

    # Hardware
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
        # Conservative CPU frequency limits for work laptop
        # Prioritize battery life over performance
        tlp.cpuFreq = {
          minOnAC = 1000000;   # 1.0 GHz
          maxOnAC = 3500000;   # 3.5 GHz (moderate)
          minOnBAT = 400000;   # 0.4 GHz (lowest P-state)
          maxOnBAT = 2000000;  # 2.0 GHz (efficient range)
        };
        suspend = {
          lidAction = "suspend-then-hibernate";
          lidActionOnAC = "lock";
        };
        # Note: Will need to update this after hardware-configuration.nix is generated
        resumeDevice = "/dev/nvme0n1p3";
        amd.pstate = false;  # Using Intel CPU
      };

      graphics = {
        enable = true;
        gpu = "intel";  # Intel integrated graphics
        enable32Bit = false;  # No gaming, no need for 32-bit
        intel = {
          initrdEnable = true;
          vulkan = true;
        };
      };
    };

    # Services
    services = {
      syncthing = {
        enable = true;
        user = "alnav";
        openFirewall = true;
      };

      ipMonitor.enable = false;  # Not needed for work laptop
    };
  };

  # =============================================================================
  # Work-specific Configuration
  # =============================================================================

  # Latest kernel for network compatibility
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Intel GPU early loading
  hardware.graphics.enable = true;

  # Allow only specific unfree packages for work
  nixpkgs.config.allowUnfree = false;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
    "teams-for-linux"  # Work communication
  ];

  # Firmware updates
  services.fwupd.enable = true;

  # Networking (useDHCP disabled, networkmanager handles it)
  networking.useDHCP = false;

  # NetworkManager with OpenConnect VPN support
  networking.networkmanager.plugins = with pkgs; [
    networkmanager-openvpn
    networkmanager-openconnect  # Corporate VPN support
  ];

  # OpenConnect VPN packages
  environment.systemPackages = with pkgs; [
    openconnect                  # OpenConnect VPN client
    networkmanager-openconnect   # NetworkManager integration
    gum                          # Shell scripting helper
    rebuild-remote               # Custom rebuild command
    deploy-all                   # Comprehensive deployment script
    deploy-config-setup          # Deploy configuration setup helper
  ];

  # Kanata key remapping (adjust device path after hardware detection)
  services.kanata = {
    enable = true;
    keyboards = {
      internalKeyboard = {
        devices = [
          "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
        ];
        extraDefCfg = "process-unmapped-keys yes";
        config = ''
          (defsrc
           caps
           n
          )
          (defalias
           caps (tap-hold 175 175 esc lctl)
           n (tap-hold 200 200 n (unicode ñ))
          )

          (deflayer base
           @caps
           @n
          )
        '';
      };
    };
  };

  networking.firewall.checkReversePath = false;

  # =============================================================================
  # Home Manager Configuration
  # =============================================================================

  home-manager = {
    useUserPackages = true;
    users.alnav = { pkgs, inputs, ... }: {
      imports = [ ../../home-modules ];

      myhome = {
        user.enable = true;

        git.enable = true;
        jdk.enable = true;

        kitty.enable = true;

        hyprpanel.enable = true;

        neovim = {
          enable = true;
          javaSupport = true;
        };

        dotfiles = {
          enable = true;
          zsh.enable = true;
          nvim.enable = true;
          hypr.enable = true;
          hyprdynamicmonitors.enable = true;
          hyprpanel.enable = true;
          rofi.enable = true;
          tmux.enable = true;
          wallpapers.enable = true;
          llmLs.enable = true; # Enable LLM language server for development
        };
      };

      # Enable services that work laptop can use
      services.opensnitch-ui.enable = true;
    };
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit inputs;
      meta = { name = "work"; system = "x86_64-linux"; useHomeManager = true; isWsl = false; };
    };
  };
}
