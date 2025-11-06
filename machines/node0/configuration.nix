{
    pkgs,
    lib,
    modulesPath,
    ...
}:

{
  imports = [
    #./../../modules/jellyfin.nix
    #./../../modules/llms.nix
    #./services.nix
    #./../../modules/zigbee2mqtt.nix
    ./../../modules/virtualisation.nix
    ./../../modules/jellyfin.nix
    ./../../containers/nginx.nix
    ./../../containers/searx.nix
    ./../../containers/windmill.nix
    ./../../containers/sonarr.nix
    ./../../containers/immich.nix
    ./../../containers/radarr.nix
    ./../../containers/prowlarr.nix
    ./../../containers/calibre-web.nix
    ./../../containers/transmission.nix
    ./../../containers/infisical.nix
    ./../../containers/suggestarr.nix
    ./../../containers/jellyseerr.nix
    ./../../containers/synapse.nix
    ./../../containers/mautrix-whatsapp.nix
    ./../../containers/mautrix-telegram.nix
    ./../../containers/mautrix-signal.nix
    ./../../containers/ntfy.nix
    ./../../containers/lancache.nix
    #./../../containers/traefik.nix
    #./../../containers/dokploy.nix
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];
  users.groups.transcoding= {
    gid = 104;
  };

  users.users.alnav = {
    extraGroups = [ "transcoding" ];
  };

  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };

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
     git
  ];

}
