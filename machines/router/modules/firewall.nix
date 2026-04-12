{ config, lib, pkgs, ... }:

let
  netlib = import ./lib.nix;
  
  # Shortcuts for readability
  br = {
    lan = netlib.vlans.lan.bridge;
    guest = netlib.vlans.guest.bridge;
    iot = netlib.vlans.iot.bridge;
    homelab = netlib.vlans.homelab.bridge;
    direct = netlib.vlans.direct.bridge;
  };
  
  gw = {
    lan = netlib.vlans.lan.gateway;
    homelab = netlib.vlans.homelab.gateway;
  };
  
  ovpn = netlib.openvpn;
  homelabServers = netlib.homelabServersNft;
  portFwdTarget = netlib.special.portForwardTarget;
in
{
  # ===========================================================================
  # Firewall Configuration (nftables)
  # ===========================================================================
  # This module contains all nftables rules for the router's firewall.
  # Network definitions are sourced from lib.nix for consistency.
  #
  # Overview:
  # - Filter table: Controls packet forwarding and input filtering
  # - Mangle table: Modifies packet headers (MSS clamping, connection marking)
  # - NAT table: Source/destination NAT for masquerading and port forwarding
  #
  # Key interfaces:
  # - ppp0: WAN interface (internet connection)
  # - wg0: WireGuard VPN tunnel (encrypted internet connection)
  # - ${br.lan}: Main LAN (trusted network)
  # - ${br.guest}: Guest network (restricted access)
  # - ${br.iot}: IoT network (isolated, limited internet)
  # - ${br.homelab}: Homelab network (fully isolated, client isolation enabled)
  # - ${br.direct}: Direct WAN access (bypasses VPN)
  # - vb-openvpn: OpenVPN container bridge interface
  # ===========================================================================

  networking.nftables = {
    enable = true;
    checkRuleset = false;
    ruleset = ''
      # =========================================================================
      # FILTER TABLE - Packet Filtering and Forwarding Rules
      # =========================================================================
      table inet filter {
        # ---------------------------------------------------------------------
        # VPN Bypass Set
        # ---------------------------------------------------------------------
        set vpn_bypass {
          type ipv4_addr
          flags timeout
        }

        # ---------------------------------------------------------------------
        # Flow Offloading Table
        # ---------------------------------------------------------------------
        flowtable f {
          hook ingress priority 0;
          devices = { wg0, ${br.lan}, ${br.guest} };
        }

        # ---------------------------------------------------------------------
        # CLIENT_TRAFFIC Chain - Per-Client Bandwidth Accounting
        # ---------------------------------------------------------------------
        chain CLIENT_TRAFFIC {
          # Rules are added dynamically by client-traffic-tracker.service
        }

        # ---------------------------------------------------------------------
        # OUTPUT Chain
        # ---------------------------------------------------------------------
        chain output {
          type filter hook output priority 100; policy accept;
        }

        # ---------------------------------------------------------------------
        # INPUT Chain - Traffic TO the Router
        # ---------------------------------------------------------------------
        chain input {
          type filter hook input priority filter; policy drop;

          # Allow all loopback traffic
          iifname "lo" accept

          # LAN: Full access to router services
          iifname "${br.lan}" counter accept

          # Guest network: Limited access (DNS, DHCP, NTP only)
          iifname "${br.guest}" udp dport { 53, 67, 123 } accept
          iifname "${br.guest}" tcp dport 53 accept

          # IoT network: Limited access
          iifname "${br.iot}" udp dport { 53, 67, 123 } accept
          iifname "${br.iot}" tcp dport 53 accept

          # Homelab network: Limited access
          iifname "${br.homelab}" udp dport { 53, 67, 123 } accept
          iifname "${br.homelab}" tcp dport 53 accept

          # Direct VLAN: Limited access
          iifname "${br.direct}" udp dport { 53, 67, 123 } accept
          iifname "${br.direct}" tcp dport 53 accept

          # WireGuard VPN: Allow established/related connections
          iifname "wg0" ct state { established, related } counter accept

          # WAN: Allow OpenVPN to container
          iifname "ppp0" udp dport ${toString ovpn.port} ct state new counter accept comment "Allow OpenVPN to container"

          # WAN: BLOCK SSH from internet
          iifname "ppp0" tcp dport 22 ct state new counter drop comment "Block SSH from WAN"

          # Direct VLAN: Allow ping to router
          iifname "${br.direct}" icmp type echo-request accept comment "Container/direct VLAN ping to host"

          # WAN: Allow established/related connections
          iifname "ppp0" ct state { established, related } counter accept

          # WAN: Drop everything else
          iifname "ppp0" drop
        }

        # ---------------------------------------------------------------------
        # FORWARD Chain - Traffic THROUGH the Router
        # ---------------------------------------------------------------------
        chain forward {
          type filter hook forward priority filter; policy drop;

          # Per-Client Traffic Accounting
          jump CLIENT_TRAFFIC

          # -----------------------------------------------------------------
          # OpenVPN Container Traffic
          # -----------------------------------------------------------------
          iifname "vb-openvpn" oifname "ppp0" counter accept comment "OpenVPN container → WAN"
          iifname "vb-openvpn" oifname "wg0" counter accept comment "OpenVPN container → VPN"

          # -----------------------------------------------------------------
          # Direct VLAN Traffic
          # -----------------------------------------------------------------
          iifname "${br.direct}" oifname "ppp0" counter accept comment "brdirect → WAN"
          iifname "${br.direct}" oifname "wg0" counter accept comment "brdirect → VPN"

          # Return traffic for brdirect and OpenVPN container
          iifname { "${br.direct}", "vb-openvpn" } oifname "ppp0" ct state established,related counter accept
          iifname { "${br.direct}", "vb-openvpn" } oifname "wg0" ct state established,related counter accept
          iifname "ppp0" oifname "${br.direct}" ct state established,related counter accept
          iifname "wg0" oifname "${br.direct}" ct state established,related counter accept

          # -----------------------------------------------------------------
          # Flow Offloading
          # -----------------------------------------------------------------
          ip protocol { tcp, udp } flow offload @f

          # -----------------------------------------------------------------
          # VPN Bypass Rules
          # -----------------------------------------------------------------
          iifname { "${br.lan}", "${br.guest}", "tun0" } oifname "ppp0" \
          ip saddr @vpn_bypass counter accept comment "VPN bypass (timed)"

          iifname "ppp0" ct state established,related counter accept comment "Return traffic for VPN bypass"

          # -----------------------------------------------------------------
          # Port Forwarding (WAN → LAN)
          # -----------------------------------------------------------------
          iifname "ppp0" oifname "${br.lan}" ip daddr ${portFwdTarget} tcp dport { 443 } counter accept comment "Port forward HTTPS to ${portFwdTarget}"
          iifname "${br.lan}" oifname "ppp0" ip saddr ${portFwdTarget} ct state established,related counter accept comment "Return traffic from forwarded server"

          # -----------------------------------------------------------------
          # Intra-LAN Traffic
          # -----------------------------------------------------------------
          iifname "${br.lan}" oifname "${br.lan}" counter accept comment "Allow intra-LAN traffic"

          # -----------------------------------------------------------------
          # Wake on LAN Traffic (Cross-VLAN)
          # -----------------------------------------------------------------
          iifname "${br.lan}" oifname { "${br.guest}", "${br.iot}", "${br.direct}" } udp dport { 7, 9 } counter accept comment "WoL from LAN"
          iifname "${br.direct}" oifname { "${br.lan}", "${br.guest}", "${br.iot}" } udp dport { 7, 9 } counter accept comment "WoL from Direct"

          # -----------------------------------------------------------------
          # Device-Specific Internet Blocks
          # -----------------------------------------------------------------
          iifname "${br.lan}" oifname "wg0" ip saddr 10.71.71.2 drop comment "Block internet for 10.71.71.2"
          iifname "${br.lan}" oifname "ppp0" ip saddr 10.71.71.2 drop comment "Block internet for 10.71.71.2"

          iifname "${br.lan}" oifname "wg0" ip saddr 10.71.71.3 drop comment "Block internet for 10.71.71.3"
          iifname "${br.lan}" oifname "ppp0" ip saddr 10.71.71.3 drop comment "Block internet for 10.71.71.3"

          iifname "${br.lan}" oifname "wg0" ip saddr 10.71.71.4 drop comment "Block internet for 10.71.71.4"
          iifname "${br.lan}" oifname "ppp0" ip saddr 10.71.71.4 drop comment "Block internet for 10.71.71.4"

          iifname "${br.lan}" oifname "wg0" ip saddr 10.71.71.91 drop comment "Block internet for android tv"
          iifname "${br.lan}" oifname "ppp0" ip saddr 10.71.71.91 drop comment "Block internet for android tv"

          # -----------------------------------------------------------------
          # Default LAN → Internet (via VPN)
          # -----------------------------------------------------------------
          iifname "${br.lan}" oifname "wg0" counter accept
          iifname "${br.guest}" oifname "wg0" counter accept

          # -----------------------------------------------------------------
          # IoT Network Rules
          # -----------------------------------------------------------------
          # Specific IoT devices allowed to VPN internet
          iifname "${br.iot}" oifname "wg0" ip saddr 192.168.6.3 counter accept comment "Work laptop internet access"

          # IoT → LAN: Restricted to specific server
          iifname "${br.iot}" oifname "${br.lan}" ip daddr 10.71.71.47 counter accept comment "IoT → 10.71.71.47"
          iifname "${br.lan}" oifname "${br.iot}" ip saddr 10.71.71.47 ct state established,related counter accept comment "Return traffic"

          # LAN → IoT: LAN can initiate connections to IoT
          iifname "${br.lan}" oifname "${br.iot}" counter accept comment "LAN → IoT"
          iifname "${br.iot}" oifname "${br.lan}" ct state established,related counter accept comment "IoT return → LAN"

          # -----------------------------------------------------------------
          # VPN Return Traffic
          # -----------------------------------------------------------------
          iifname "wg0" ct state established,related counter accept
          iifname "wg0" oifname "${br.direct}" ct state established,related counter accept
          iifname "${br.lan}" oifname "${br.direct}" ct state established,related counter accept

          # -----------------------------------------------------------------
          # OpenVPN Client → LAN Access
          # -----------------------------------------------------------------
          iifname "${br.direct}" oifname "${br.lan}" ip saddr { ${ovpn.clientSubnet}, ${ovpn.containerIp} } counter accept comment "OpenVPN clients to LAN"

          # LAN → OpenVPN container (new connections)
          iifname "${br.lan}" oifname "${br.direct}" udp dport ${toString ovpn.port} ct state new counter accept comment "LAN to OpenVPN container"

          # OpenVPN container → LAN (replies)
          iifname "${br.direct}" oifname "${br.lan}" ct state established,related counter accept comment "OpenVPN container replies"

          # WAN → OpenVPN container
          iifname "ppp0" oifname "${br.direct}" udp dport ${toString ovpn.port} ct state new counter accept comment "WAN to OpenVPN container"

          # -----------------------------------------------------------------
          # Homelab Network Rules
          # -----------------------------------------------------------------
          # Homelab devices are fully isolated with client isolation enabled
          # EXCEPT: Server devices (${homelabServers}) are accessible from all networks

          # Allow homelab devices to reach server devices
          iifname "${br.homelab}" oifname "${br.homelab}" ip daddr { ${homelabServers} } counter accept comment "Homelab → homelab servers"

          # Allow server devices to respond/initiate to other homelab devices
          iifname "${br.homelab}" oifname "${br.homelab}" ip saddr { ${homelabServers} } counter accept comment "Homelab servers → homelab"

          # Block all other intra-homelab traffic (client isolation)
          iifname "${br.homelab}" oifname "${br.homelab}" counter drop comment "Block intra-homelab (client isolation)"

          # Allow other VLANs to access homelab server devices
          iifname { "${br.lan}", "${br.guest}", "${br.iot}", "${br.direct}" } oifname "${br.homelab}" ip daddr { ${homelabServers} } counter accept comment "All VLANs → homelab servers"

          # Allow homelab servers to respond to other VLANs
          iifname "${br.homelab}" oifname { "${br.lan}", "${br.guest}", "${br.iot}", "${br.direct}" } ip saddr { ${homelabServers} } ct state established,related counter accept comment "Homelab servers return traffic"

          # Block all homelab → internet traffic
          iifname "${br.homelab}" oifname "wg0" counter drop comment "Block homelab → VPN"
          iifname "${br.homelab}" oifname "ppp0" counter drop comment "Block homelab → WAN"

          # Block all other homelab traffic
          iifname "${br.homelab}" counter drop comment "Block all other homelab traffic"
        }
      }

      # =========================================================================
      # MANGLE TABLE - Packet Modification
      # =========================================================================
      table inet mangle {
        chain prerouting {
          type filter hook prerouting priority mangle; policy accept;

          # Mark port-forwarded HTTP/HTTPS packets for correct return routing
          iifname "ppp0" tcp dport { 80, 443 } ct mark set 0xca6c comment "Mark HTTP/HTTPS port-forward"
          ct mark 0xca6c meta mark set 0xca6c

          # Mark OpenVPN server responses for correct routing
          iifname "${br.direct}" ip saddr ${ovpn.containerIp} udp sport ${toString ovpn.port} meta mark set 0x1194 comment "Mark OpenVPN responses"
        }

        chain forward {
          type filter hook forward priority mangle; policy accept;

          # MSS clamping for PPPoE (1452 = 1492 MTU - 40 bytes headers)
          oifname "ppp0" tcp flags syn tcp option maxseg size set 1452
          iifname "ppp0" tcp flags syn tcp option maxseg size set 1452
        }
      }

      # =========================================================================
      # NAT TABLE - Network Address Translation
      # =========================================================================
      table ip nat {
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;

          # Forward WAN HTTP/HTTPS to internal web server
          iifname "ppp0" tcp dport { 80, 443 } dnat to ${portFwdTarget}

          # Forward WAN OpenVPN port to container
          iifname "ppp0" udp dport ${toString ovpn.port} dnat to ${ovpn.containerIp}:${toString ovpn.port} comment "Forward OpenVPN to container (WAN)"

          # Forward LAN OpenVPN port to container
          ip daddr ${gw.lan} udp dport ${toString ovpn.port} dnat to ${ovpn.containerIp}:${toString ovpn.port} comment "Forward OpenVPN from LAN"
        }

        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;

          # Masquerade all traffic going through VPN
          oifname "wg0" masquerade

          # Masquerade OpenVPN client traffic through VPN
          oifname "wg0" ip saddr ${ovpn.clientSubnet} masquerade comment "OpenVPN clients NAT via wg0"

          # Masquerade container traffic through VPN
          oifname "wg0" ip saddr ${ovpn.containerIp} masquerade comment "Container to VPN masquerade"

          # Masquerade all traffic going through WAN
          oifname "ppp0" masquerade

          # Masquerade container traffic through WAN
          oifname "ppp0" ip saddr ${ovpn.containerIp} masquerade comment "Container to internet masquerade"
        }
      }
    '';
  };
}
