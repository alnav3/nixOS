{ config, lib, pkgs, ... }:

let
  netlib = import ./lib.nix;
  
  # Generate NTP allow rules from all subnets
  ntpAllowRules = builtins.concatStringsSep "\n" 
    (map (subnet: "      allow ${subnet}") netlib.allSubnets);
in
{
  # ===========================================================================
  # DNS and DHCP Services
  # ===========================================================================
  # This module configures DNS resolution and DHCP server for all networks.
  # Network definitions are sourced from lib.nix.
  # 
  # Architecture:
  # 1. AdGuard Home (port 53): Primary DNS with ad-blocking
  #    - Queries for *.home domain are forwarded to dnsmasq
  #    - All other queries go to Quad9 over HTTPS/TLS
  # 2. dnsmasq (port 8053): Authoritative DNS for .home domain + DHCP server
  #    - Maintains local DNS records for LAN devices
  #    - Handles DHCP for all networks
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # dnsmasq: Local DNS + DHCP Server
  # ---------------------------------------------------------------------------
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;
    settings = {
      # Domain configuration
      domain = "home";
      local = "/home/";
      expand-hosts = true;
      no-hosts = true;
      domain-needed = true;
      bogus-priv = true;

      # Upstream DNS configuration
      no-resolv = true;
      server = [ "9.9.9.9" "149.112.112.112" ];

      # Wildcard DNS for .home domain
      address = "/.home/${netlib.special.wildcardDns}";

      # Static host record for the router itself
      host-record = "router.home,${netlib.vlans.lan.gateway}";

      # Listen on port 8053 to avoid conflict with AdGuard Home
      port = 8053;

      # Listen on all bridge interfaces plus loopback
      interface = [ "lo" ] ++ netlib.allBridges;
      bind-interfaces = true;

      # DHCP ranges - generated from lib.nix
      "dhcp-range" = netlib.mkDhcpRanges;

      # DHCP options per network - generated from lib.nix
      "dhcp-option" = netlib.mkDhcpOptions;

      # Static lease assignments file
      dhcp-hostsfile = "/var/lib/dnsmasq/static-leases.conf";

      # DHCP lease database
      dhcp-leasefile = "/var/lib/dnsmasq/dnsmasq.leases";

      # Enable DHCP logging for troubleshooting
      log-dhcp = true;
    };
  };

  # ---------------------------------------------------------------------------
  # AdGuard Home: DNS Ad-Blocking and Privacy
  # ---------------------------------------------------------------------------
  services.adguardhome = {
    enable = true;
    mutableSettings = true;
    settings = {
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;

        upstream_dns = [
          "[/home/]127.0.0.1:8053"
          "https://dns.quad9.net/dns-query"
          "tls://dns.quad9.net"
        ];

        bootstrap_dns = [ "9.9.9.9" "149.112.112.112" ];
        fallback_dns = [ "9.9.9.9" "149.112.112.112" ];

        protection_enabled = true;
        filtering_enabled = true;
        filters_update_interval = 24;
        blocked_response_ttl = 10;
        ratelimit = 0;
      };

      filters = [
        { id = 1; enabled = true; 
          url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt"; 
          name = "AdGuard DNS filter"; }
        { id = 2; enabled = true; 
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt"; 
          name = "OISD Big"; }
        { id = 3; enabled = true; 
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt"; 
          name = "HaGeZi Pro"; }
        { id = 4; enabled = true; 
          url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"; 
          name = "Steven Black Unified hosts"; }
      ];

      user_rules = [];
    };
  };

  # ---------------------------------------------------------------------------
  # NTP Server Configuration
  # ---------------------------------------------------------------------------
  services.chrony = {
    enable = true;
    servers = [
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
      "2.nixos.pool.ntp.org"
      "3.nixos.pool.ntp.org"
    ];
    extraConfig = ''
      # Allow NTP queries from all local networks (generated from lib.nix)
${ntpAllowRules}
    '';
  };

  # ---------------------------------------------------------------------------
  # Create Required Directories
  # ---------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    "f /var/lib/dnsmasq/static-leases.conf 0644 root root -"
  ];
}
