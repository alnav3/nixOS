{pkgs, pkgs-unstable, ...}: {
  services.netbird.enable = true;
  services.netbird.package = pkgs-unstable.netbird;
  environment.systemPackages = with pkgs-unstable; [
    netbird-ui
    nfs-utils
  ];
  services.resolved.enable = true;
  networking.networkmanager.enable = true;
  boot.kernelParams = ["ipv6.disable=1"];
  environment.etc.openvpn.source = "${pkgs.update-resolv-conf}/libexec/openvpn";
  sops.secrets."secure.ovpn" = {};
  sops.secrets."protoncreds.conf" = {};
  services.openvpn.servers = {
    protonSecure = {
      config = ''config /run/secrets/secure.ovpn '';
      updateResolvConf = true;
    };
  };
}
