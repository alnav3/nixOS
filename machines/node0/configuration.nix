{ config, lib, pkgs, meta, ... }:

{

  # allow unfree for nvidia drivers
  nixpkgs.config.allowUnfree = true;

  # enable docker
  virtualisation.docker.enable = true;

  # NVIDIA configuration
  hardware.opengl.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true;
  };

  #fileSystems."/mnt/HDD1" = {
  #  device = "/dev/disk/by-uuid/b74eb042-a941-405e-9544-ed4f1834875b";
  #  fsType = "auto";
  #  options = [ "defaults" ];
  #};

  #fileSystems."/mnt/Jellifyin" = {
  #  device = "/dev/disk/by-uuid/0affb6bd-11dc-4d98-827c-0ac175d73bc5";
  #  fsType = "auto";
  #  options = [ "defaults" ];
  #};

  # Networking configuration
  networking = {
    hostName = meta.hostname;
    networkmanager.enable = true;

    useDHCP = false;

    interfaces.eth0.ipv4.addresses = [{
      address = "10.71.71.60";
      prefixLength = 24;
    }];

    defaultGateway = "10.71.71.1";
    nameservers = [ "9.9.9.9" "1.1.1.1" ];

    firewall.enable = false;
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    #useXkbConfig = true; # use xkb.options in tty.
  };

  # Fixes for longhorn
  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
  ];
  #virtualisation.docker.logDriver = "json-file";


  sops.secrets."token" = {};
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.sops.secrets."token".path;
    extraFlags = toString [
	    "--write-kubeconfig-mode \"0644\""
	    "--cluster-init"
	    "--disable servicelb"
	    "--disable traefik"
	    "--disable local-storage"
    ];
    clusterInit = true;
  };

  services.openiscsi = {
    enable = true;
    name = "iqn.2016-04.com.open-iscsi:${meta.hostname}";
  };


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
     neovim
     k3s
     cifs-utils
     nfs-utils
     git
  ];

}
