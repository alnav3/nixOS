{ config, lib, pkgs, ... }:
{
  imports = [
    ./modules/openvpn-container.nix
  ];
  # ===========================================================================
  # IP Forwarding (IPv4 only)
  # ===========================================================================
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
  };
  # ===========================================================================
  # Networking
  # ===========================================================================
  networking = {
    useDHCP = false;
    enableIPv6 = false;
    hostName = lib.mkForce "router";
    vlans = {
      "ens18.20" = { id = 20; interface = "ens18"; };
      "ens19.6" = { id = 6; interface = "ens19"; };
      "ens19.10" = { id = 10; interface = "ens19"; };
      "ens19.100" = { id = 100; interface = "ens19"; };
      "ens20.6" = { id = 6; interface = "ens20"; };
      "ens20.10" = { id = 10; interface = "ens20"; };
      "ens20.100" = { id = 100; interface = "ens20"; };
    };
    bridges = {
      brlan = { interfaces = [ "ens19" "ens20" ]; };
      brguest = { interfaces = [ "ens19.6" "ens20.6" ]; };
      briot = { interfaces = [ "ens19.10" "ens20.10" ]; };
      brdirect = { interfaces = [ "ens19.100" "ens20.100" ]; };
    };
    interfaces = {
      ens18.useDHCP = false;
      "ens18.20".useDHCP = false;
      ens19.useDHCP = false;
      ens20.useDHCP = false;
      brlan = { useDHCP = false; ipv4.addresses = [{ address = "10.71.71.1"; prefixLength = 24; }]; };
      brguest = { useDHCP = false; ipv4.addresses = [{ address = "10.71.72.1"; prefixLength = 24; }]; };
      briot = { useDHCP = false; ipv4.addresses = [{ address = "192.168.6.1"; prefixLength = 24; }]; };
      brdirect = { useDHCP = false; ipv4.addresses = [{ address = "10.71.73.1"; prefixLength = 24; }]; };
    };
    nat.enable = false;
    firewall.enable = false;
    nftables = {
      enable = true;
      checkRuleset = false;
      ruleset = ''
        table inet filter {
          set vpn_bypass {
            type ipv4_addr
            flags timeout
          }
          flowtable f {
            hook ingress priority 0;
            devices = { wg0, brlan, brguest };
          }
          chain output {
            type filter hook output priority 100; policy accept;
          }
          chain input {
            type filter hook input priority filter; policy drop;
            iifname "lo" accept
            iifname "brlan" counter accept
            iifname "brguest" udp dport { 53, 67, 123 } accept
            iifname "brguest" tcp dport 53 accept
            iifname "briot" udp dport { 53, 67, 123 } accept
            iifname "briot" tcp dport 53 accept
            iifname "brdirect" udp dport { 53, 67, 123 } accept
            iifname "brdirect" tcp dport 53 accept
            iifname "wg0" ct state { established, related } counter accept
            iifname "ppp0" udp dport 1194 ct state new counter accept comment "Allow OpenVPN to container"
            iifname "brdirect" icmp type echo-request accept comment "Container/direct VLAN ping to host"
            iifname "ppp0" ct state { established, related } counter accept
            iifname "ppp0" drop
          }
          chain forward {
            type filter hook forward priority filter; policy drop;
            iifname "vb-openvpn" oifname "ppp0" counter accept comment "OpenVPN container (vb-openvpn) → WAN"
            iifname "vb-openvpn" oifname "wg0" counter accept comment "OpenVPN container (vb-openvpn) → VPN"

            iifname "brdirect" oifname "ppp0" counter accept comment "brdirect direct to WAN"
            iifname "brdirect" oifname "wg0" counter accept comment "brdirect direct to VPN"
            iifname { "brdirect", "vb-openvpn" } oifname "ppp0" ct state established,related counter accept comment "Return traffic from brdirect/vb-openvpn to WAN"
            iifname { "brdirect", "vb-openvpn" } oifname "wg0" ct state established,related counter accept comment "Return traffic from brdirect/vb-openvpn to VPN"
            iifname "ppp0" oifname "brdirect" ct state established,related counter accept comment "Return traffic for direct VLAN"
            iifname "wg0" oifname "brdirect" ct state established,related counter accept comment "Return traffic from VPN for direct VLAN"
            ip protocol { tcp, udp } flow offload @f
            iifname { "brlan", "brguest", "tun0" } oifname "ppp0" \
            ip saddr @vpn_bypass counter accept comment "VPN bypass (timed)"
            iifname "ppp0" ct state established,related counter accept comment "Return traffic for VPN bypass"
            iifname "ppp0" oifname "brlan" ip daddr 10.71.71.193 tcp dport { 80, 443 } counter accept comment "Port forward HTTP/HTTPS to 10.71.71.193"
            iifname "brlan" oifname "ppp0" ip saddr 10.71.71.193 ct state established,related counter accept comment "Return traffic from forwarded server to WAN"
            iifname "brlan" oifname "brlan" counter accept comment "Allow intra-LAN traffic"
            iifname "brlan" oifname "wg0" ip saddr 10.71.71.2 drop comment "Block internet for 10.71.71.2"
            iifname "brlan" oifname "ppp0" ip saddr 10.71.71.2 drop comment "Block internet for 10.71.71.2"
            iifname "brlan" oifname "wg0" ip saddr 10.71.71.3 drop comment "Block internet for 10.71.71.2"
            iifname "brlan" oifname "ppp0" ip saddr 10.71.71.3 drop comment "Block internet for 10.71.71.2"
            iifname "brlan" oifname "wg0" ip saddr 10.71.71.4 drop comment "Block internet for 10.71.71.2"
            iifname "brlan" oifname "ppp0" ip saddr 10.71.71.4 drop comment "Block internet for 10.71.71.2"
            iifname "brlan" oifname "wg0" ip saddr 10.71.71.91 drop comment "Block internet for android tv"
            iifname "brlan" oifname "ppp0" ip saddr 10.71.71.91 drop comment "Block internet for android tv"
            iifname "brlan" oifname "wg0" counter accept
            iifname "brguest" oifname "wg0" counter accept
            iifname "briot" oifname "wg0" ip saddr 192.168.6.5 counter accept comment "Specific IoT device (192.168.6.5) → VPN internet access"
            iifname "briot" oifname "wg0" ip saddr 192.168.6.3 counter accept comment "Specific IoT device (192.168.6.3) → VPN internet access"
            iifname "briot" oifname "brlan" ip daddr 10.71.71.47 counter accept comment "IoT subnet → 10.71.71.47"
            iifname "brlan" oifname "briot" ip saddr 10.71.71.47 ct state established,related counter accept comment "Return traffic 10.71.71.47 → IoT"
            iifname "brlan" oifname "briot" counter accept comment "LAN → IoT"
            iifname "briot" oifname "brlan" ct state established,related counter accept comment "IoT return traffic → LAN"
            iifname "wg0" ct state established,related counter accept
            iifname "wg0" oifname "brdirect" ct state established,related counter accept comment "VPN return to container"
            iifname "brlan" oifname "brdirect" ct state established,related counter accept comment "LAN return to container"
            iifname "brdirect" oifname "brlan" ip saddr { 10.8.0.0/24, 10.71.73.10 } counter accept comment "OpenVPN clients to LAN (container masquerades src to 10.71.73.10)"
            # LAN → OpenVPN container (new connections from any LAN client)
            iifname "brlan" oifname "brdirect" udp dport 1194 ct state new counter accept comment "LAN to OpenVPN container"
            # OpenVPN container → LAN (replies)
            iifname "brdirect" oifname "brlan" ct state established,related counter accept comment "OpenVPN container replies to LAN"
            iifname "ppp0" oifname "brdirect" udp dport 1194 ct state new counter accept comment "WAN to OpenVPN container"
          }

        }
        table inet mangle {
          chain prerouting {
            type filter hook prerouting priority mangle; policy accept;
            iifname "ppp0" tcp dport { 80, 443 } ct mark set 0xca6c comment "Mark HTTP/HTTPS port-forward: return via ppp0"
            ct mark 0xca6c meta mark set 0xca6c
            # Mark OpenVPN server responses so they always route via ppp0 (not wg0)
            # vb-openvpn is a bridge port on brdirect; netfilter sees brdirect as iifname
            iifname "brdirect" ip saddr 10.71.73.10 udp sport 1194 meta mark set 0x1194 comment "Mark OpenVPN 1194 responses for ppp0 routing"
          }
          chain forward {
            type filter hook forward priority mangle; policy accept;
            oifname "ppp0" tcp flags syn tcp option maxseg size set 1452
            iifname "ppp0" tcp flags syn tcp option maxseg size set 1452
          }
        }
        table ip nat {
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;
            iifname "ppp0" tcp dport { 80, 443 } dnat to 10.71.71.193
            iifname "ppp0" udp dport 1194 dnat to 10.71.73.10:1194 comment "Forward OpenVPN to container (WAN)"
            ip daddr 10.71.71.1 udp dport 1194 dnat to 10.71.73.10:1194 comment "Forward OpenVPN from LAN (10.71.71.1:1194 → container)"
          }
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            oifname "wg0" masquerade
            oifname "wg0" ip saddr 10.8.0.0/24 masquerade comment "OpenVPN clients NAT via wg0"
            oifname "wg0" ip saddr 10.71.73.10 masquerade comment "Container to VPN masquerade"
            oifname "ppp0" masquerade
            oifname "ppp0" ip saddr 10.71.73.10 masquerade comment "Container to internet masquerade"
          }
        }
      '';
    };
  };
  # ===========================================================================
  # DNS + DHCP — dnsmasq
  # ===========================================================================
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = true;
    settings = {
      domain = "home";
      local = "/home/";
      expand-hosts = true;
      no-hosts = true;
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;
      server = [ "9.9.9.9" "149.112.112.112" ];
      address = "/.home/10.71.71.75";
      host-record = "router.home,10.71.71.1";
      port = 8053;
      interface = [ "lo" "brlan" "brguest" "briot" "brdirect" ];
      bind-interfaces = true;
      "dhcp-range" = [
        "set:lan,10.71.71.100,10.71.71.200,24h"
        "set:guest,10.71.72.100,10.71.72.200,24h"
        "set:iot,192.168.6.100,192.168.6.200,24h"
        "set:direct,10.71.73.100,10.71.73.200,24h"
      ];
      "dhcp-option" = [
        "tag:lan,option:router,10.71.71.1"
        "tag:lan,option:dns-server,10.71.71.1"
        "tag:lan,option:ntp-server,10.71.71.1"
        "tag:lan,option:domain-name,home"
        "tag:guest,option:router,10.71.72.1"
        "tag:guest,option:dns-server,10.71.72.1"
        "tag:guest,option:ntp-server,10.71.72.1"
        "tag:guest,option:domain-name,home"
        "tag:iot,option:router,192.168.6.1"
        "tag:iot,option:dns-server,192.168.6.1"
        "tag:iot,option:ntp-server,192.168.6.1"
        "tag:iot,option:domain-name,home"
        "tag:direct,option:router,10.71.73.1"
        "tag:direct,option:dns-server,10.71.73.1"
        "tag:direct,option:ntp-server,10.71.73.1"
        "tag:direct,option:domain-name,home"
      ];
      dhcp-hostsfile = "/var/lib/dnsmasq/static-leases.conf";
      dhcp-leasefile = "/var/lib/dnsmasq/dnsmasq.leases";
      log-dhcp = true;
    };
  };
  # ===========================================================================
  # NTP server
  # ===========================================================================
  services.chrony = {
    enable = true;
    servers = [
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
      "2.nixos.pool.ntp.org"
      "3.nixos.pool.ntp.org"
    ];
    extraConfig = ''
      allow 10.71.71.0/24
      allow 10.71.72.0/24
      allow 192.168.6.0/24
      allow 10.71.73.0/24
      allow 10.8.0.0/24
    '';
  };
  # ===========================================================================
  # WireGuard client
  # ===========================================================================
  networking.wg-quick.interfaces.wg0 = {
    configFile = config.sops.secrets."vpn.conf".path;
    autostart = false;
  };
  # ===========================================================================
  # AdGuard Home
  # ===========================================================================
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
        { id = 1; enabled = true; url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt"; name = "AdGuard DNS filter"; }
        { id = 2; enabled = true; url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt"; name = "OISD Big"; }
        { id = 3; enabled = true; url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt"; name = "HaGeZi Pro"; }
        { id = 4; enabled = true; url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"; name = "Steven Black Unified hosts"; }
      ];
      user_rules = [];
    };
  };
  # ===========================================================================
  # tmpfiles & VPN bypass restore
  # ===========================================================================
  systemd.tmpfiles.rules = [
    "f /var/lib/dnsmasq/static-leases.conf 0644 root root -"
    "d /var/lib/vpn-bypass 0700 root root -"
    "f /var/lib/vpn-bypass/permanent 0600 root root -"
  ];

  systemd.services.openvpn-client-routing = {
      description = "Route OpenVPN client subnet via the container + protect against bypass";
      after = [ "nftables.service" "wg-quick-wg0.service" "container@openvpn.service" "vpn-bypass-restore.service" ];
      wants = [ "nftables.service" "wg-quick-wg0.service" "container@openvpn.service" "vpn-bypass-restore.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      path = [ pkgs.iproute2 ];
      script = ''
          ip rule del from 10.8.0.0/24 table main priority 90 2>/dev/null || true
          ip rule del from 10.8.0.0/24 table main 2>/dev/null || true
          ip route del 10.8.0.0/24 dev brdirect 2>/dev/null || true
          ip route add 10.8.0.0/24 via 10.71.73.10 dev brdirect || true
          # Force OpenVPN port 1194 responses (marked 0x1194) to always use ppp0 (main table)
          # Priority 30 runs before wg-quick's routing rules
          ip rule del fwmark 0x1194 table main priority 30 2>/dev/null || true
          ip rule add fwmark 0x1194 table main priority 30
          echo "OpenVPN client routing (via container) + bypass protection applied"
          '';
  };
  systemd.services.vpn-bypass-restore = {
    description = "Restore permanent VPN bypass rules";
    after = [ "nftables.service" "network-online.target" "wg-quick-wg0.service" ];
    wants = [ "network-online.target" "wg-quick-wg0.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.nftables pkgs.iproute2 pkgs.gawk ];
    script = ''
      FILE="/var/lib/vpn-bypass/permanent"
      [ -f "$FILE" ] || exit 0
      WG_LOWEST=$(ip rule show | awk -F: '/suppress_prefixlength|fwmark/{print $1+0}' | sort -n | head -1)
      if [ -n "$WG_LOWEST" ] && [ "$WG_LOWEST" -gt 10 ]; then
        PRIO=$(( WG_LOWEST - 10 ))
      else
        PRIO=50
      fi
      echo "Using bypass priority $PRIO (wg-quick lowest: $WG_LOWEST)"
      while IFS= read -r ip || [ -n "$ip" ]; do
        [ -z "$ip" ] && continue
        nft add element inet filter vpn_bypass "{ $ip }" 2>/dev/null || true
        ip rule del from "$ip" table main priority "$PRIO" 2>/dev/null || true
        ip rule add from "$ip" table main priority "$PRIO"
        echo "Restored permanent bypass for $ip at priority $PRIO"
      done < "$FILE"
      #ip rule del from 10.71.73.0/24 table main priority "$PRIO" 2>/dev/null || true
      #ip rule add from 10.71.73.0/24 table main priority "$PRIO"
      ip route flush cache
      echo "Restored permanent brdirect bypass (10.71.73.0/24) at priority $PRIO"
    '';
  };
  # ===========================================================================
  # Dynamic DNS, Cloudflare DDNS, PPPoE (exactly as in your original config)
  # ===========================================================================
  sops.secrets."duckdns.env" = { };
  sops.secrets."cloudflare.env" = { };
  sops.secrets."pap-secrets" = {
    path = "/etc/ppp/pap-secrets";
    owner = "root";
    group = "root";
    mode = "0600";
  };
  sops.secrets."vpn.conf" = { };

  systemd.services.duckdns = {
    description = "DuckDNS dynamic DNS update";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."duckdns.env".path;
      ExecStart = pkgs.writeShellScript "duckdns-update" ''
        RESULT=$(${pkgs.curl}/bin/curl -sf --interface ppp0 \
          "https://www.duckdns.org/update?domains=alnav&token=$DUCKDNS_TOKEN&ip=")
        echo "DuckDNS: $RESULT"
        [ "$RESULT" = "OK" ] || { echo "DuckDNS update failed: $RESULT"; exit 1; }
      '';
    };
  };
  systemd.timers.duckdns = {
    description = "DuckDNS update timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
  };

  systemd.services.cloudflare-ddns = {
    description = "Cloudflare dynamic DNS update for alnav.dev";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets."cloudflare.env".path;
      ExecStart = pkgs.writeShellScript "cloudflare-ddns-update" ''
        CURL=${pkgs.curl}/bin/curl
        JQ=${pkgs.jq}/bin/jq
        CF="https://api.cloudflare.com/client/v4"
        WAN_IP=$($CURL -sf --interface ppp0 https://ifconfig.me)
        [ -z "$WAN_IP" ] && { echo "ERROR: could not get WAN IP"; exit 1; }
        echo "WAN IP: $WAN_IP"
        ZONE_ID=$($CURL -sf \
          -H "Authorization: Bearer $CLOUDFLARE_DNS_API_TOKEN" \
          -H "Content-Type: application/json" \
          "$CF/zones?name=alnav.dev" \
          | $JQ -r '.result[0].id')
        [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ] && { echo "ERROR: zone alnav.dev not found"; exit 1; }
        echo "Zone ID: $ZONE_ID"
        update_record() {
          FQDN=$1
          RECORD_ID=$($CURL -sf \
            -H "Authorization: Bearer $CLOUDFLARE_DNS_API_TOKEN" \
            -H "Content-Type: application/json" \
            "$CF/zones/$ZONE_ID/dns_records?type=A&name=$FQDN" \
            | $JQ -r '.result[0].id')
          if [ -z "$RECORD_ID" ] || [ "$RECORD_ID" = "null" ]; then
            echo "SKIP: no A record found for $FQDN"
            return 0
          fi
          OK=$($CURL -sf -X PATCH \
            -H "Authorization: Bearer $CLOUDFLARE_DNS_API_TOKEN" \
            -H "Content-Type: application/json" \
            "$CF/zones/$ZONE_ID/dns_records/$RECORD_ID" \
            --data "{\"type\":\"A\",\"content\":\"$WAN_IP\"}" \
            | $JQ -r '.success')
          echo "$FQDN → $WAN_IP : $OK"
          [ "$OK" = "true" ]
        }
        update_record "alnav.dev"
      '';
    };
  };
  systemd.timers.cloudflare-ddns = {
    description = "Cloudflare DDNS update timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
  };

  services.pppd = {
    enable = true;
    peers.wan = {
      autostart = true;
      enable = true;
      config = ''
        plugin pppoe.so ens18.20
        name "611835311@digi"
        auth
        refuse-chap
        refuse-mschap
        refuse-mschap-v2
        refuse-eap
        debug
        noipdefault
        defaultroute
        hide-password
        noauth
        persist
        maxfail 0
        holdoff 5
        mtu 1492
        mru 1492
        lcp-echo-interval 20
        lcp-echo-failure 3
        ifname ppp0
      '';
    };
  };

  systemd.services."pppd-wan".preStart = ''
    ${pkgs.iproute2}/bin/ip link set ens18 up 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip link set ens18.20 up 2>/dev/null || true
  '';

  environment.etc."ppp/ip-up" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      for s in /etc/ppp/ip-up.d/*; do
        [ -x "$s" ] && "$s" "$@"
      done
    '';
  };
  environment.etc."ppp/ip-down" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      for s in /etc/ppp/ip-down.d/*; do
        [ -x "$s" ] && "$s" "$@"
      done
    '';
  };
  environment.etc."ppp/ip-up.d/01-wireguard" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      ${pkgs.systemd}/bin/systemctl restart wg-quick-wg0.service
    '';
  };
  environment.etc."ppp/ip-down.d/01-wireguard" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      ${pkgs.systemd}/bin/systemctl stop wg-quick-wg0.service
    '';
  };
  # ===========================================================================
  # Base module & packages
  # ===========================================================================
  services.journald.extraConfig = ''
    SystemMaxUse=300M
    MaxRetentionSec=2weeks
    MaxFileSec=1week
  '';

  mymodules.base = {
    enable = true;
    sops.enable = true;
    boot.systemdBoot = lib.mkDefault true;
    stateVersion = "25.05";
  };

  mymodules = {
    desktop.enable = false;
    development.enable = false;
    gaming.enable = false;
    media.enable = false;
    networking.enable = false;
    virtualisation.enable = false;
  };

  environment.systemPackages = with pkgs; [
    vim
    htop
    ethtool
    tcpdump
    conntrack-tools
    nftables
    iproute2
    dnsutils
    (pkgs.writeShellScriptBin "vpn-bypass" ''
      IP=$1
      DURATION=''${2:-5m}
      UNIT="vpn-bypass-$(echo "$IP" | tr '.' '-')"
      parse_secs() {
        case "$1" in
          *h) echo $(( ''${1%h} * 3600 )) ;;
          *m) echo $(( ''${1%m} * 60 )) ;;
          *s) echo "''${1%s}" ;;
          *) echo "$1" ;;
        esac
      }
      bypass_prio() {
        WG=$(ip rule show | awk -F: '/suppress_prefixlength|fwmark/{print $1+0}' | sort -n | head -1)
        if [ -n "$WG" ] && [ "$WG" -gt 10 ]; then
          echo $(( WG - 10 ))
        else
          echo 50
        fi
      }
      PRIO=$(bypass_prio)
      if [ -z "$IP" ]; then
        echo "Usage: vpn-bypass <IP> [duration|off]"
        echo " vpn-bypass list"
        exit 1
      fi
      if [ "$IP" = "list" ]; then
        nft list set inet filter vpn_bypass
        echo ""
        echo "Active routing rules (bypass priority: $PRIO):"
        ip rule show | awk -F: -v p="$PRIO" '$1+0 == p'
        exit 0
      fi
      if [ "$DURATION" = "off" ]; then
        nft delete element inet filter vpn_bypass "{ $IP }" 2>/dev/null || true
        ip rule del from "$IP" table main priority "$PRIO" 2>/dev/null || true
        systemctl stop "$UNIT.service" 2>/dev/null || true
        sed -i "/^$(echo "$IP" | sed 's/\./\\./g')$/d" /var/lib/vpn-bypass/permanent 2>/dev/null || true
        echo "Bypass removed for $IP"
        exit 0
      fi
      ip rule del from "$IP" table main priority "$PRIO" 2>/dev/null || true
      ip rule add from "$IP" table main priority "$PRIO"
      if [ "$DURATION" = "permanent" ] || [ "$DURATION" = "perm" ]; then
        nft add element inet filter vpn_bypass "{ $IP }"
        grep -qxF "$IP" /var/lib/vpn-bypass/permanent 2>/dev/null || echo "$IP" >> /var/lib/vpn-bypass/permanent
        echo "Bypass permanently active for $IP — remove with: vpn-bypass $IP off"
        exit 0
      fi
      SECS=$(parse_secs "$DURATION")
      nft add element inet filter vpn_bypass "{ $IP timeout $DURATION }"
      ${pkgs.systemd}/bin/systemd-run \
        --on-active="''${SECS}s" \
        --unit="$UNIT" \
        --description="Remove VPN bypass routing for $IP" \
        ${pkgs.iproute2}/bin/ip rule del from "$IP" table main priority "$PRIO"
      echo "Bypass active for $IP — expires in $DURATION"
    '')
  ];
}
