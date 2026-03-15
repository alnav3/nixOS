{ lib }:

{
  # Default user configuration
  user = {
    name = "alnav";
    uid = 1000;
    groups = [
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
  };

  # Common paths
  paths = {
    home = "/home/alnav";
    nixosConfig = "/home/alnav/nixOS";
    mediaDir = "/mnt/media";
    downloadsDir = "/mnt/things";
  };

  # Network configuration
  network = {
    homeSubnet = "10.71.71";
    serverIP = "10.71.71.10";
    internalProxyIP = "10.71.71.75";
    externalProxyIP = "10.71.71.193";
  };

  # Common timezone
  timezone = "Europe/Madrid";

  # Common locale
  locale = "en_US.UTF-8";
}
