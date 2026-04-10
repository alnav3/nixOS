{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # Router Main Configuration
  # ===========================================================================
  # This is the main configuration file for the router.
  # It imports modular configurations for different functions.
  #
  # Network Architecture:
  # - WAN: PPPoE connection (ppp0) for internet access
  # - VPN: WireGuard tunnel (wg0) for privacy
  # - LAN (brlan): Main trusted network - 10.71.71.0/24
  # - Guest (brguest): Isolated guest network - 10.71.72.0/24
  # - IoT (briot): Restricted IoT devices - 192.168.6.0/24
  # - Direct (brdirect): Direct WAN access + OpenVPN - 10.71.73.0/24
  #
  # Modules:
  # - network.nix: Physical interfaces, VLANs, bridges
  # - firewall.nix: nftables rules for routing and filtering
  # - dns-dhcp.nix: DNS (AdGuard + dnsmasq) and DHCP server
  # - wireguard.nix: WireGuard VPN client
  # - wan.nix: PPPoE and dynamic DNS (DuckDNS + Cloudflare)
  # - vpn-bypass.nix: Selective VPN bypass utility
  # - openvpn-container.nix: Isolated OpenVPN server
  # - monitoring.nix: Prometheus, Grafana, per-client bandwidth tracking
  # ===========================================================================

  imports = [
    # Modular configuration files
    ./modules/network.nix
    ./modules/firewall.nix
    ./modules/dns-dhcp.nix
    ./modules/wireguard.nix
    ./modules/wan.nix
    ./modules/vpn-bypass.nix
    ./modules/openvpn-container.nix
    ./modules/users.nix           # User accounts & security hardening
    ./modules/monitoring.nix      # Prometheus, Grafana, per-client bandwidth
  ];

  # ===========================================================================
  # System Configuration
  # ===========================================================================

  # Journal configuration - limit log storage
  services.journald.extraConfig = ''
    SystemMaxUse=300M      # Max 300MB of logs
    MaxRetentionSec=2weeks # Keep logs for 2 weeks
    MaxFileSec=1week       # Rotate weekly
  '';

  # Base module configuration (from custom modules)
  mymodules.base = {
    enable = true;
    sops.enable = true;  # Enable SOPS for secrets management
    boot.systemdBoot = lib.mkDefault true;
    stateVersion = "25.05";
  };

  # Disable desktop/development modules (this is a router, not a workstation)
  mymodules = {
    desktop.enable = false;
    development.enable = false;
    gaming.enable = false;
    media.enable = false;
    networking.enable = false;
    virtualisation.enable = false;
  };

  # ===========================================================================
  # Essential Packages
  # ===========================================================================
  # Minimal set of tools for router management and debugging
  environment.systemPackages = with pkgs; [
    neovim                  # Text editor
    htop                 # Process monitor
    ethtool              # Ethernet tool
    tcpdump              # Packet capture
    conntrack-tools      # Connection tracking utilities
    nftables             # Firewall management
    iproute2             # IP routing utilities
    dnsutils             # DNS debugging (dig, nslookup)
  ];
}
