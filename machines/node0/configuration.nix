{
  pkgs,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    # Import full module system for consistency
    ./../../modules
    
    # Container modules
    ./../../containers
    
    # LXC container support
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  # =============================================================================
  # Module Configuration - Server profile (LXC Container)
  # =============================================================================

  mymodules = {
    # Base configuration
    base = {
      enable = true;
      # Disable boot loader for LXC
      boot.systemdBoot = false;
      stateVersion = "24.11";
    };

    # Disable desktop module (server has no GUI)
    desktop.enable = false;

    # Disable gaming (server)
    gaming.enable = false;

    # Disable networking module (handled manually for LXC)
    networking.enable = false;

    # Development (minimal for server management)
    development = {
      enable = true;
      shell = {
        zsh.enable = true;
        direnv = true;
      };
      editor.neovim = true;
      git.enable = true;
      # Disable development tools not needed on server
      languages = {
        go = false;
        nodejs = false;
        java = false;
        python = false;
        nix = false;
      };
      infrastructure = {
        kubernetes = false;
        dockerTools = false;
        databases = false;
      };
    };

    # Virtualisation (Docker for containers)
    virtualisation = {
      enable = true;
      docker = {
        enable = true;
        rootless = true;
        autoPrune = {
          enable = true;
          schedule = "weekly";
        };
        networks = {
          "custom-net" = {
            subnet = "172.42.0.0/24";
            dependsOn = [ "windmill-db" "windmill-server" ];
          };
          "lancache-net" = {
            subnet = "10.0.39.0/24";
            dependsOn = [ "lancache-dns" "lancache-monolithic" ];
          };
        };
      };
      containers = {
        enable = true;
        backend = "docker";
      };
      # Disable desktop virtualization features
      spice = false;
      distrobox = false;
      qemu = false;
    };

    # Media (minimal - just yt-dlp for downloads)
    media = {
      enable = true;
      youtube.ytdlp = true;
      # Disable desktop media apps
      video.mpv = false;
      video.obs = false;
      audio.playerctl = false;
      audio.finamp = false;
      documents.zathura = false;
      documents.thorium = false;
      social.enable = false;
    };

    # Hardware (Intel GPU for transcoding)
    hardware = {
      bluetooth.enable = false;
      battery.enable = false;
      graphics = {
        enable = true;
        gpu = "intel";
        intel = {
          vaapi = true;
          qsv = true;
          openclCompute = true;
        };
      };
    };

    # Services
    services = {
      jellyfin = {
        enable = true;
        intel = {
          vaapi = true;
          qsv = true;
          openclCompute = true;
        };
        mounts = {
          enable = true;
          credentialsSecret = "smb-things-secrets";
        };
        backup.enable = true;
      };
      # Disable services not needed on server
      syncthing.enable = false;
      ipMonitor.enable = false;
    };
  };

  # =============================================================================
  # Container Configuration (using existing container module system)
  # =============================================================================

  services.mycontainers = {
    # Nginx reverse proxies
    nginx = {
      enableInternal = true;
      enableExternal = true;
    };

    # Media management (*arr stack)
    sonarr.enable = true;
    radarr.enable = true;
    prowlarr.enable = true;
    jellyseerr.enable = true;
    suggestarr.enable = true;

    # Download clients
    transmission.enable = true;
    deemix.enable = true;
    metube.enable = true;
    slskd.enable = true;

    # Media libraries
    calibre-web.enable = true;

    # Photo management
    immich.enable = true;

    # Communication (Matrix)
    synapse.enable = true;
    mautrix-whatsapp.enable = true;
    mautrix-telegram.enable = true;
    mautrix-signal.enable = true;

    # Utilities
    ntfy.enable = true;
    searx.enable = true;
    pihole.enable = true;
    syncthing.enable = true;
    etesync.enable = true;
    trmnl.enable = false;

    # Development/Infrastructure
    infisical.enable = true;
    kasm.enable = true;
  };

  # =============================================================================
  # Node0-specific Configuration (LXC Container)
  # =============================================================================

  # Transcoding group for Jellyfin
  users.groups.transcoding = {
    gid = 104;
  };

  users.users.alnav = {
    extraGroups = [ "transcoding" ];
  };

  # Intel VA-API override for better transcoding support
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };

  nix.settings.trusted-users = [ "root" "@wheel" "alnav" ];

  # Boot configuration (LXC - disable all bootloaders)
  boot = {
    enableContainers = true;
    loader.grub.enable = lib.mkForce false;
    loader.systemd-boot.enable = lib.mkForce false;
    loader.generic-extlinux-compatible.enable = lib.mkForce false;
  };

  # Networking configuration (manual for LXC)
  networking = {
    nameservers = [ "10.71.71.1" ];
    hostName = lib.mkForce "node-0";
    networkmanager.enable = true;
    wireless.enable = lib.mkForce false;
    useDHCP = false;

    interfaces.eth0.ipv4.addresses = [
      { address = "10.71.71.10"; prefixLength = 24; }
      { address = "10.71.71.75"; prefixLength = 24; }
      { address = "10.71.71.193"; prefixLength = 24; }
    ];

    defaultGateway = "10.71.71.1";
    firewall.enable = false;

    nat = {
      enable = true;
      internalInterfaces = [ "ve-+" ];
      externalInterface = "eth0";
      enableIPv6 = false;
    };
  };

  # Console configuration
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Suppress systemd units that don't work in LXC
  systemd.suppressedSystemUnits = [
    "dev-mqueue.mount"
    "sys-kernel-debug.mount"
    "sys-fs-fuse-connections.mount"
  ];
  
  # Disable wpa_supplicant - no WiFi in LXC
  systemd.services.wpa_supplicant.enable = lib.mkForce false;

  # Extra packages for server management
  environment.systemPackages = with pkgs; [
    cifs-utils
    nfs-utils
  ];
}
