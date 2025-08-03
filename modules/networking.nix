{pkgs, pkgs-unstable, ...}: {
  environment.systemPackages = with pkgs-unstable; [
    nfs-utils
    ethtool
    opensnitch-ui
  ];
  services.resolved.enable = true;
  networking.networkmanager.enable = true;
  boot.kernelParams = ["ipv6.disable=1"];

  environment.etc.openvpn.source = "${pkgs.update-resolv-conf}/libexec/openvpn";
  sops.secrets."home.ovpn" = {};
  sops.secrets."homecreds.conf" = {};
  services.openvpn.servers = {
      home = {
          config = ''config /run/secrets/home.ovpn '';
          updateResolvConf = true;
      };
  };
  #services.opensnitch.enable = true;
}
