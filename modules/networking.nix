{pkgs, pkgs-unstable, ...}: {
  environment.systemPackages = with pkgs-unstable; [
    nfs-utils
    ethtool
    opensnitch-ui
  ];
  services.resolved.enable = true;
  boot.kernelParams = ["ipv6.disable=1"];

  environment.etc.openvpn.source = "${pkgs.update-resolv-conf}/libexec/openvpn";
  sops.secrets."home.ovpn" = {};
  sops.secrets."homecreds.conf" = {};

  networking.networkmanager = {
      enable = true;  # Ensure NetworkManager is enabled
          ensureProfiles.profiles = {
              "wired-connection-1" = {  # Internal key for the profile (can be anything unique)
                  connection = {
                      id = "Wired connection 1";  # Display name in NetworkManager
                      type = "ethernet";
                      interface-name = "eth0";  # Bind to specific interface
                  };
                  ipv4 = {
                      method = "manual";
                      address1 = "10.71.71.85/24";  # First IP with prefix
                      address2 = "10.71.71.75/24";  # Second IP with prefix
                      dns = "10.71.71.1;";  # DNS servers (semicolon-separated)
                  };
                  ipv6 = {
                      method = "disabled";  # Optional: Disable IPv6 if not needed
                  };
              };
          };
  };

  #services.openvpn.servers = {
  #    home = {
  #        config = ''config /run/secrets/home.ovpn '';
  #        updateResolvConf = true;
  #    };
  #};
  #services.opensnitch.enable = true;
}
