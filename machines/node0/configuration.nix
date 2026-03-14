{
    pkgs,
    lib,
    modulesPath,
    ...
}:

{
  imports = [
    ./../../modules/virtualisation.nix
    ./../../modules/jellyfin.nix
    ./../../containers  # Import all container modules
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];
  
  # Enable and configure containers using the new modular system
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
    trmnl.enable = true;
    
    # Development/Infrastructure
    infisical.enable = true;
    kasm.enable = true;
  };
  users.groups.transcoding= {
    gid = 104;
  };

  users.users.alnav = {
    extraGroups = [ "transcoding" ];
  };

  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };

  nix.settings.trusted-users = [ "root" "@wheel" "alnav" ];
  boot = {
      enableContainers = true;
      loader.grub.enable = lib.mkForce false;
      loader.systemd-boot.enable = lib.mkForce false;
      loader.generic-extlinux-compatible.enable = lib.mkForce false;
  };



  # Networking configuration
  networking = {
    nameservers = [ "10.71.71.1" ];
    # TODO: check this after migration:
    hostName = lib.mkForce "node-0"; #meta.hostname;
    networkmanager.enable = true;

    useDHCP = false;

    interfaces.eth0.ipv4.addresses = [
    {
      address = "10.71.71.10";
      prefixLength = 24;
    }
    {
      address = "10.71.71.75";
      prefixLength = 24;
    }
    {
      address = "10.71.71.193";
      prefixLength = 24;
    }
    ];

    defaultGateway = "10.71.71.1";

    firewall.enable = false;
    nat = {
        enable = true;
        internalInterfaces = ["ve-+"];
        externalInterface = "eth0";
        enableIPv6 = false;
    };
  };

  # Select internationalisation properties.
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    #useXkbConfig = true; # use xkb.options in tty.
  };

  # Supress systemd units that don't work because of LXC.
  # https://blog.xirion.net/posts/nixos-proxmox-lxc/#configurationnix-tweak
  systemd.suppressedSystemUnits = [
    "dev-mqueue.mount"
    "sys-kernel-debug.mount"
    "sys-fs-fuse-connections.mount"
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
     neovim
     cifs-utils
     nfs-utils
     yt-dlp
     git
  ];

}
