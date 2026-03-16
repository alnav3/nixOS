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
  # Module Configuration - All options explicitly enabled
  # =============================================================================

  mymodules = {
    # Base system configuration
    base = {
      enable = true;
      # Framework uses default base settings
      user.extraGroups = [
        "uinput"
        "wheel"
        "docker"
        "audio"
        "input"
        "disk"
        "libvirtd"
        "qemu-libvirtd"
        "libvirt"
        "dialout"
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
        opencode = true;
      };
      git = {
        enable = true;
        gitlab = true;
      };
      work.enable = true;
      freelance.enable = true;
    };

    # Gaming
    gaming = {
      enable = true;
      steam = {
        enable = true;
        gamescope = true;
      };
      launchers = {
        lutris = true;
        heroic = true;
        bottles = true;
      };
      emulation = {
        enable = true;
        switch = true;
      };
      performance = {
        mangohud = true;
        protonTools = true;
      };
      android = {
        enable = true;
        tools = true;
      };
    };

    # Media
    media = {
      enable = true;
      video = {
        mpv = true;
        obs = true;
      };
      audio = {
        playerctl = true;
        finamp = true;
      };
      youtube = {
        ytdlp = true;
        grayjay = true;
      };
      documents = {
        zathura = true;
        thorium = true;
        kcc = true;
      };
      portable.rockbox = true;
      soulseek = true;
      casting.fcast = true;
      streaming.streamrip = true;
      social = {
        enable = true;
        discord = true;
        signal = true;
        telegram = true;
      };
      mail.thunderbird = true;
      backup.pikaBackup = true;
      printing3d.enable = true;
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
        allowedTCPPorts = [ 80 4200 1338 2300 46899 46898 ];
        allowedUDPPorts = [ 46898 ];
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
      spice = true;
      distrobox = true;
      qemu = true;
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
        suspend = {
          hibernateAfterSuspend = true;
          lidAction = "suspend-then-hibernate";
          lidActionOnAC = "lock";
        };
        resumeDevice = "/dev/nvme0n1p3";
        amd.pstate = true;
      };

      graphics = {
        enable = true;
        gpu = "amd";
        enable32Bit = true;
        amd = {
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

      ipMonitor.enable = true;
    };
  };

  # =============================================================================
  # Framework-specific Configuration
  # =============================================================================

  # Latest kernel for network compatibility
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ARM emulation for Duet
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # AMD GPU early loading
  hardware.amdgpu.initrd.enable = true;

  nixpkgs.config.allowUnfree = true;

  # Firmware updates
  services.fwupd.enable = true;
  services.fwupd.package =
    (import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/bb2009ca185d97813e75736c2b8d1d8bb81bde05.tar.gz";
        sha256 = "sha256:003qcrsq5g5lggfrpq31gcvj82lb065xvr7bpfa8ddsw8x4dnysk";
      }) {
        system = pkgs.stdenv.hostPlatform.system;
      })
    .fwupd;

  # Framework hardware settings
  hardware.framework.amd-7040.preventWakeOnAC = true;
  hardware.framework.enableKmod = true;

  # Networking (useDHCP disabled, networkmanager handles it)
  networking.useDHCP = false;

  # Kanata key remapping
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

  # Extra framework-specific packages (things not in modules)
  environment.systemPackages = with pkgs; [
    fw-ectool           # Framework laptop control
    gum                 # Shell scripting helper
    sshuttle            # SSH-based VPN
    transmission_4-gtk  # Torrent client
  ];

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

      # Enable services that framework can use
      services.opensnitch-ui.enable = true;
    };
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit inputs;
      meta = { name = "framework"; system = "x86_64-linux"; useHomeManager = true; isWsl = false; };
    };
  };
}
