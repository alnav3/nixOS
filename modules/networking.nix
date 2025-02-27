{pkgs, pkgs-unstable, ...}: {
  environment.systemPackages = with pkgs-unstable; [
    nfs-utils
    ethtool
  ];
  services.resolved.enable = true;
  networking.networkmanager.enable = true;
  boot.kernelParams = ["ipv6.disable=1"];
}

#environment.etc.openvpn.source = "${pkgs.update-resolv-conf}/libexec/openvpn";
#sops.secrets."secure.ovpn" = {};
#sops.secrets."protoncreds.conf" = {};
#services.openvpn.servers = {
#  protonSecure = {
#    config = ''config /run/secrets/secure.ovpn '';
#    updateResolvConf = true;
#  };
#};
