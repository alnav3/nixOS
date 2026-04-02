{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # DNS and DHCP Services
  # ===========================================================================
  # This module configures DNS resolution and DHCP server for all networks.
  # 
  # Architecture:
  # 1. AdGuard Home (port 53): Primary DNS with ad-blocking
  #    - Queries for *.home domain are forwarded to dnsmasq
  #    - All other queries go to Quad9 over HTTPS/TLS
  # 2. dnsmasq (port 8053): Authoritative DNS for .home domain + DHCP server
  #    - Maintains local DNS records for LAN devices
  #    - Handles DHCP for all networks (LAN, Guest, IoT, Direct)
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # dnsmasq: Local DNS + DHCP Server
  # ---------------------------------------------------------------------------
  # Runs on port 8053 to avoid conflict with AdGuard Home
  # Provides authoritative DNS for the .home domain
  # Handles DHCP leases and static assignments for all subnets
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;
    settings = {
      # Domain configuration
      # All devices get .home domain automatically appended
      domain = "home";
      local = "/home/";        # .home queries never leave the network
      expand-hosts = true;     # Automatically add .home to hostnames
      no-hosts = true;         # Don't read /etc/hosts file
      domain-needed = true;    # Don't forward queries without domain
      bogus-priv = true;       # Don't forward reverse lookups for private IPs

      # Upstream DNS configuration
      # Don't use /etc/resolv.conf, use explicit servers
      no-resolv = true;
      # Use Quad9 for external DNS queries (privacy-focused, DNSSEC)
      server = [ "9.9.9.9" "149.112.112.112" ];

      # Wildcard DNS for .home domain
      # All *.home queries return this IP (useful for reverse proxy)
      address = "/.home/10.71.71.75";

      # Static host record for the router itself
      host-record = "router.home,10.71.71.1";

      # Listen on port 8053 to avoid conflict with AdGuard Home
      port = 8053;

      # Listen on all network interfaces
      # lo: For AdGuard Home to query
      # brlan, brguest, briot, brdirect: For DHCP and direct DNS queries
      interface = [ "lo" "brlan" "brguest" "briot" "brdirect" ];
      bind-interfaces = true;  # Only bind to specified interfaces

      # DHCP ranges for each network
      # Tagged sets allow different DHCP options per network
      "dhcp-range" = [
        "set:lan,10.71.71.100,10.71.71.200,24h"      # LAN: 100 IPs, 24h lease
        "set:guest,10.71.72.100,10.71.72.200,24h"    # Guest: 100 IPs, 24h lease
        "set:iot,192.168.6.100,192.168.6.200,24h"    # IoT: 100 IPs, 24h lease
        "set:direct,10.71.73.100,10.71.73.200,24h"   # Direct: 100 IPs, 24h lease
      ];

      # DHCP options per network
      # Each network gets its own gateway, DNS server, and NTP server
      # All point to the router IP for that subnet
      "dhcp-option" = [
        # LAN network options
        "tag:lan,option:router,10.71.71.1"          # Default gateway
        "tag:lan,option:dns-server,10.71.71.1"      # DNS server (AdGuard Home)
        "tag:lan,option:ntp-server,10.71.71.1"      # NTP server (chrony)
        "tag:lan,option:domain-name,home"           # Search domain

        # Guest network options
        "tag:guest,option:router,10.71.72.1"
        "tag:guest,option:dns-server,10.71.72.1"
        "tag:guest,option:ntp-server,10.71.72.1"
        "tag:guest,option:domain-name,home"

        # IoT network options
        "tag:iot,option:router,192.168.6.1"
        "tag:iot,option:dns-server,192.168.6.1"
        "tag:iot,option:ntp-server,192.168.6.1"
        "tag:iot,option:domain-name,home"

        # Direct VLAN network options
        "tag:direct,option:router,10.71.73.1"
        "tag:direct,option:dns-server,10.71.73.1"
        "tag:direct,option:ntp-server,10.71.73.1"
        "tag:direct,option:domain-name,home"
      ];

      # Static lease assignments file
      # Format: MAC,IP,hostname (one per line)
      # Allows specific devices to always get the same IP
      dhcp-hostsfile = "/var/lib/dnsmasq/static-leases.conf";

      # DHCP lease database
      # Tracks which IPs are currently assigned
      dhcp-leasefile = "/var/lib/dnsmasq/dnsmasq.leases";

      # Enable DHCP logging for troubleshooting
      log-dhcp = true;
    };
  };

  # ---------------------------------------------------------------------------
  # AdGuard Home: DNS Ad-Blocking and Privacy
  # ---------------------------------------------------------------------------
  # Primary DNS server for all devices
  # Blocks ads, trackers, and malicious domains
  # Provides encrypted DNS (DoH/DoT) to upstream resolvers
  services.adguardhome = {
    enable = true;
    mutableSettings = true;  # Allow web UI configuration changes
    settings = {
      dns = {
        # Listen on all interfaces, port 53 (standard DNS port)
        bind_hosts = [ "0.0.0.0" ];
        port = 53;

        # Upstream DNS configuration
        upstream_dns = [
          # Forward .home domain queries to dnsmasq for local resolution
          "[/home/]127.0.0.1:8053"
          # All other queries go to Quad9 over encrypted DNS
          "https://dns.quad9.net/dns-query"  # DNS-over-HTTPS
          "tls://dns.quad9.net"              # DNS-over-TLS
        ];

        # Bootstrap DNS for resolving encrypted DNS hostnames
        # Plain DNS used only to resolve dns.quad9.net initially
        bootstrap_dns = [ "9.9.9.9" "149.112.112.112" ];
        
        # Fallback DNS if upstream fails
        fallback_dns = [ "9.9.9.9" "149.112.112.112" ];

        # Ad-blocking and filtering settings
        protection_enabled = true;   # Enable ad-blocking
        filtering_enabled = true;    # Enable DNS filtering
        filters_update_interval = 24;  # Update filter lists daily
        blocked_response_ttl = 10;   # TTL for blocked domain responses

        # No rate limiting - we trust our local network
        ratelimit = 0;
      };

      # Ad-blocking filter lists
      # Multiple lists provide comprehensive ad/tracker blocking
      filters = [
        # AdGuard's curated DNS filter
        { id = 1; enabled = true; 
          url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt"; 
          name = "AdGuard DNS filter"; }
        
        # OISD Big - comprehensive blocklist
        { id = 2; enabled = true; 
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt"; 
          name = "OISD Big"; }
        
        # HaGeZi Pro - aggressive blocking
        { id = 3; enabled = true; 
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt"; 
          name = "HaGeZi Pro"; }
        
        # Steven Black's unified hosts file
        { id = 4; enabled = true; 
          url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"; 
          name = "Steven Black Unified hosts"; }
      ];

      # Custom user rules (can be added via web UI)
      user_rules = [];
    };
  };

  # ---------------------------------------------------------------------------
  # NTP Server Configuration
  # ---------------------------------------------------------------------------
  # Provides time synchronization for all local devices
  # Router syncs from internet NTP pool, serves time to LAN
  services.chrony = {
    enable = true;
    # Upstream NTP servers (NixOS pool)
    servers = [
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
      "2.nixos.pool.ntp.org"
      "3.nixos.pool.ntp.org"
    ];
    extraConfig = ''
      # Allow NTP queries from all local networks
      allow 10.71.71.0/24   # LAN
      allow 10.71.72.0/24   # Guest
      allow 192.168.6.0/24  # IoT
      allow 10.71.73.0/24   # Direct
      allow 10.8.0.0/24     # OpenVPN clients
    '';
  };

  # ---------------------------------------------------------------------------
  # Create Required Directories
  # ---------------------------------------------------------------------------
  systemd.tmpfiles.rules = [
    # DHCP static leases file (empty initially, populated manually)
    "f /var/lib/dnsmasq/static-leases.conf 0644 root root -"
  ];
}
