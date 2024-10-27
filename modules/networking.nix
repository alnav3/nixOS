{pkgs, ...}: {
  services.netbird.enable = true;
  environment.systemPackages = with pkgs; [
    netbird-ui
  ];
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
