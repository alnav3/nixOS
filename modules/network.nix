{
  config,
  pkgs,
  ...
}: {
  networking.wireless.userControlled.enable = true;
  sops.secrets."wireless.env" = {};
  networking.wireless.secretsFile = config.sops.secrets."wireless.env".path;
  networking.wireless.networks = {
    "DIGIFIBRA-CC1B" = {
      pskRaw = "ext:home_psk";
    };
    "ext:home_uuid" = {
      pskRaw = "ext:home_psk";
    };
  };
  networking.wireless.enable = true;
  environment.systemPackages = with pkgs; [
    iw
  ];

  # openvpn config
  environment.etc.openvpn.source = "${pkgs.update-resolv-conf}/libexec/openvpn";
  sops.secrets."secure.ovpn" = {};
  services.openvpn.servers = {
    protonSecure = {
      config = ''config ${config.sops.secrets."secure.ovpn".path} '';
      updateResolvConf = true;
    };
  };
}
