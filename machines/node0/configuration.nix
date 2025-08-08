{
    pkgs,
    meta,
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
    ./../../modules/networking.nix
    ./../../containers/nginx.nix
    #./../../containers/searx.nix
    #./../../containers/n8n.nix #TODO: search for a FOSS alternative
    #./../../containers/sonarr.nix
    #./../../containers/radarr.nix
    #./../../containers/prowlarr.nix
    "${modulesPath}/virtualisation/lxc-container.nix"

  ];

  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };

  boot = {
      enableContainers = true;
      isContainer = true;
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
