{
    pkgs,
    lib,
    modulesPath,
    ...
}:

{
  imports = [
    # Import only needed modules for server
    ./../../modules/hardware/graphics.nix
    ./../../modules/services/jellyfin.nix
    ./../../modules/virtualisation.nix
    ./../../modules/development.nix
    ./../../modules/media.nix
    ./../../containers  # Import container modules
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  # =============================================================================
  # Module Configuration - All options explicitly enabled
  # =============================================================================

  mymodules = {
    # Disable desktop module (not needed for server)
    desktop.enable = false;

    # Development (minimal for server)
    development = {
      enable = true;
      shell = {
          zsh.enable = true;
          direnv = true;
      };
      editor.neovim = true;
      git.enable = true;
    };

    # Virtualisation
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
    };

    # Hardware (Intel GPU for transcoding)
    hardware = {
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

    # Media (just for yt-dlp)
    media = {
      enable = true;
      youtube.ytdlp = true;
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

  # Intel VA-API override
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };

  nix.settings.trusted-users = [ "root" "@wheel" "alnav" ];

  # Boot configuration (LXC)
  boot = {
    enableContainers = true;
    loader.grub.enable = lib.mkForce false;
    loader.systemd-boot.enable = lib.mkForce false;
    loader.generic-extlinux-compatible.enable = lib.mkForce false;
  };

  # Networking configuration
  networking = {
    nameservers = [ "10.71.71.1" ];
    hostName = lib.mkForce "node-0";
    networkmanager.enable = true;
    wireless.enable = lib.mkForce false;  # Disable wpa_supplicant - no WiFi in LXC container
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

  # Suppress systemd units for LXC
  systemd.suppressedSystemUnits = [
    "dev-mqueue.mount"
    "sys-kernel-debug.mount"
    "sys-fs-fuse-connections.mount"
  ];
  
  # Disable wpa_supplicant service - no WiFi in LXC container
  systemd.services.wpa_supplicant.enable = lib.mkForce false;

  # Extra node0-specific packages (things not in modules)
  environment.systemPackages = with pkgs; [
    cifs-utils
    nfs-utils
  ];
}
