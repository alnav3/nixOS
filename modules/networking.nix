{pkgs, pkgs-unstable, ...}: {
  environment.systemPackages = with pkgs-unstable; [
    nfs-utils
    ethtool
    opensnitch-ui
  ];
  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [ "9.9.9.9" "149.112.112.112" ];
    extraConfig = ''
      DNSStubListener=no
    '';
  };
  # Completely disable IPv6 for all devices and interfaces
  boot.kernel.sysctl = {
    # Disable IPv6 globally
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
    # Disable IPv6 on loopback interface
    "net.ipv6.conf.lo.disable_ipv6" = 1;
    # Disable IPv6 autoconfiguration
    "net.ipv6.conf.all.autoconf" = 0;
    "net.ipv6.conf.default.autoconf" = 0;
    # Disable IPv6 router advertisements
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.default.accept_ra" = 0;
  };

  # Disable IPv6 in networking configuration
  networking.enableIPv6 = false;

  environment.etc.openvpn.source = "${pkgs.update-resolv-conf}/libexec/openvpn";
  sops.secrets."home.ovpn" = {};
  sops.secrets."homecreds.conf" = {};

  #networking.networkmanager = {
  #    enable = true;  # Ensure NetworkManager is enabled
  #        ensureProfiles.profiles = {
  #            "wired-connection-1" = {  # Internal key for the profile (can be anything unique)
  #                connection = {
  #                    id = "Wired connection 1";  # Display name in NetworkManager
  #                    type = "ethernet";
  #                    interface-name = "eth0";  # Bind to specific interface
  #                };
  #                ipv4 = {
  #                    method = "manual";
  #                    address1 = "10.71.71.85/24";  # First IP with prefix
  #                    address2 = "10.71.71.75/24";  # Second IP with prefix
  #                    dns = "10.71.71.1;";  # DNS servers (semicolon-separated)
  #                };
  #                ipv6 = {
  #                    method = "disabled";  # Optional: Disable IPv6 if not needed
  #                };
  #            };
  #        };
  #};

  #services.openvpn.servers = {
  #    home = {
  #        config = ''config /run/secrets/home.ovpn '';
  #        updateResolvConf = true;
  #    };
  #};
  #services.opensnitch.enable = true;
}
