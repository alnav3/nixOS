{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # Firewall Configuration (nftables)
  # ===========================================================================
  # This module contains all nftables rules for the router's firewall.
  #
  # Overview:
  # - Filter table: Controls packet forwarding and input filtering
  # - Mangle table: Modifies packet headers (MSS clamping, connection marking)
  # - NAT table: Source/destination NAT for masquerading and port forwarding
  #
  # Key concepts:
  # - ppp0: WAN interface (internet connection)
  # - wg0: WireGuard VPN tunnel (encrypted internet connection)
  # - brlan: Main LAN (trusted network)
  # - brguest: Guest network (restricted access)
  # - briot: IoT network (isolated, limited internet)
  # - brdirect: Direct WAN access (bypasses VPN)
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
        # Named set to track IPs that should bypass the VPN and use WAN directly
        # Supports timeout for temporary bypass entries
        # Used by vpn-bypass command to selectively route traffic via ppp0
        set vpn_bypass {
          type ipv4_addr
          flags timeout
        }

        # ---------------------------------------------------------------------
        # Flow Offloading Table
        # ---------------------------------------------------------------------
        # Hardware flow offloading accelerates forwarding for established connections
        # Only applies to TCP/UDP traffic between specified interfaces
        # Significantly reduces CPU usage for high-throughput connections
        flowtable f {
          hook ingress priority 0;
          devices = { wg0, brlan, brguest };
        }

        # ---------------------------------------------------------------------
        # OUTPUT Chain
        # ---------------------------------------------------------------------
        # Controls packets originating from the router itself
        # Policy: ACCEPT - allow all outbound traffic from router
        chain output {
          type filter hook output priority 100; policy accept;
        }

        # ---------------------------------------------------------------------
        # INPUT Chain - Traffic TO the Router
        # ---------------------------------------------------------------------
        # Controls which packets can reach services running on the router
        # Policy: DROP - deny everything except explicitly allowed
        chain input {
          type filter hook input priority filter; policy drop;

          # Allow all loopback traffic (router talking to itself)
          iifname "lo" accept

          # LAN (brlan): Full access to router services
          # Trusted network can access all router management interfaces
          iifname "brlan" counter accept

          # Guest network (brguest): Limited access
          # Only DNS (53), DHCP (67), and NTP (123) allowed
          # Prevents guests from accessing router management
          iifname "brguest" udp dport { 53, 67, 123 } accept
          iifname "brguest" tcp dport 53 accept

          # IoT network (briot): Limited access
          # Same restrictions as guest network for security
          # IoT devices often have poor security, so minimize attack surface
          iifname "briot" udp dport { 53, 67, 123 } accept
          iifname "briot" tcp dport 53 accept

          # Direct VLAN (brdirect): Limited access
          # OpenVPN container and direct WAN access devices
          iifname "brdirect" udp dport { 53, 67, 123 } accept
          iifname "brdirect" tcp dport 53 accept

          # WireGuard VPN: Allow established/related connections
          # Permits return traffic for VPN connections initiated by router
          iifname "wg0" ct state { established, related } counter accept

          # WAN (ppp0): Allow OpenVPN protocol (1194/udp) to container
          # This allows external clients to connect to the OpenVPN server
          # DNAT rule redirects this to the container (see NAT table)
          iifname "ppp0" udp dport 1194 ct state new counter accept comment "Allow OpenVPN to container"

          # WAN (ppp0): BLOCK SSH from internet
          # Critical security rule: prevent external SSH access to router
          # SSH management should only be from LAN
          iifname "ppp0" tcp dport 22 ct state new counter drop comment "Block SSH from WAN (ppp0)"

          # Direct VLAN: Allow ping to router
          # Useful for diagnostics from OpenVPN container
          iifname "brdirect" icmp type echo-request accept comment "Container/direct VLAN ping to host"

          # WAN (ppp0): Allow established/related connections
          # Permits return traffic for connections initiated by router to internet
          iifname "ppp0" ct state { established, related } counter accept

          # WAN (ppp0): Drop everything else
          # Explicit drop for clarity (default policy is already drop)
          iifname "ppp0" drop
        }

        # ---------------------------------------------------------------------
        # FORWARD Chain - Traffic THROUGH the Router
        # ---------------------------------------------------------------------
        # Controls routing between different networks
        # Policy: DROP - deny everything except explicitly allowed
        # This is the most complex chain as it handles all inter-network routing
        chain forward {
          type filter hook forward priority filter; policy drop;

          # -----------------------------------------------------------------
          # OpenVPN Container Traffic
          # -----------------------------------------------------------------
          # Allow OpenVPN container to access both WAN (ppp0) and VPN (wg0)
          # Container can route clients to either internet or VPN as needed
          iifname "vb-openvpn" oifname "ppp0" counter accept comment "OpenVPN container (vb-openvpn) → WAN"
          iifname "vb-openvpn" oifname "wg0" counter accept comment "OpenVPN container (vb-openvpn) → VPN"

          # -----------------------------------------------------------------
          # Direct VLAN Traffic (brdirect)
          # -----------------------------------------------------------------
          # Devices on brdirect can access both WAN and VPN directly
          # Used for services that need to bypass VPN or choose routing
          iifname "brdirect" oifname "ppp0" counter accept comment "brdirect direct to WAN"
          iifname "brdirect" oifname "wg0" counter accept comment "brdirect direct to VPN"

          # Return traffic for brdirect and OpenVPN container
          # Allow responses to requests made from these networks
          iifname { "brdirect", "vb-openvpn" } oifname "ppp0" ct state established,related counter accept comment "Return traffic from brdirect/vb-openvpn to WAN"
          iifname { "brdirect", "vb-openvpn" } oifname "wg0" ct state established,related counter accept comment "Return traffic from brdirect/vb-openvpn to VPN"
          iifname "ppp0" oifname "brdirect" ct state established,related counter accept comment "Return traffic for direct VLAN"
          iifname "wg0" oifname "brdirect" ct state established,related counter accept comment "Return traffic from VPN for direct VLAN"

          # -----------------------------------------------------------------
          # Flow Offloading
          # -----------------------------------------------------------------
          # Accelerate TCP/UDP forwarding using hardware offload where available
          # Must be placed before VPN bypass rules to apply to normal traffic
          ip protocol { tcp, udp } flow offload @f

          # -----------------------------------------------------------------
          # VPN Bypass Rules
          # -----------------------------------------------------------------
          # Allow specific IPs to bypass VPN and use WAN directly
          # Managed by vpn-bypass command, includes OpenVPN tunnel (tun0)
          # IPs in vpn_bypass set get temporary or permanent direct routing
          iifname { "brlan", "brguest", "tun0" } oifname "ppp0" \
          ip saddr @vpn_bypass counter accept comment "VPN bypass (timed)"

          # Return traffic for bypassed connections
          iifname "ppp0" ct state established,related counter accept comment "Return traffic for VPN bypass"

          # -----------------------------------------------------------------
          # Port Forwarding (WAN → LAN)
          # -----------------------------------------------------------------
          # Forward HTTP/HTTPS from internet to specific server on LAN
          # DNAT happens in NAT table, this just allows the forwarded traffic
          iifname "ppp0" oifname "brlan" ip daddr 10.71.71.193 tcp dport { 80, 443 } counter accept comment "Port forward HTTP/HTTPS to 10.71.71.193"

          # Return traffic from port-forwarded server back to internet
          iifname "brlan" oifname "ppp0" ip saddr 10.71.71.193 ct state established,related counter accept comment "Return traffic from forwarded server to WAN"

          # -----------------------------------------------------------------
          # Intra-LAN Traffic
          # -----------------------------------------------------------------
          # Allow all traffic within the main LAN
          # LAN is trusted, devices can communicate freely
          iifname "brlan" oifname "brlan" counter accept comment "Allow intra-LAN traffic"

          # -----------------------------------------------------------------
          # Wake on LAN Traffic (Cross-VLAN)
          # -----------------------------------------------------------------
          # Allow WoL magic packets between some VLANs
          # WoL packets are UDP on port 9 (or 7) and need broadcast capability

          # LAN → Guest, IoT, Direct VLANs (WoL)
          iifname "brlan" oifname { "brguest", "briot", "brdirect" } udp dport { 7, 9 } counter accept comment "WoL from LAN to other VLANs"

          # Direct → LAN, Guest, IoT VLANs (WoL)
          iifname "brdirect" oifname { "brlan", "brguest", "briot" } udp dport { 7, 9 } counter accept comment "WoL from Direct to other VLANs"

          # -----------------------------------------------------------------
          # Device-Specific Internet Blocks
          # -----------------------------------------------------------------
          # Block specific devices from accessing internet (both VPN and WAN)
          # Useful for devices that should be LAN-only or for parental controls

          # Block 10.71.71.2 from internet
          iifname "brlan" oifname "wg0" ip saddr 10.71.71.2 drop comment "Block internet for 10.71.71.2"
          iifname "brlan" oifname "ppp0" ip saddr 10.71.71.2 drop comment "Block internet for 10.71.71.2"

          # Block 10.71.71.3 from internet
          iifname "brlan" oifname "wg0" ip saddr 10.71.71.3 drop comment "Block internet for 10.71.71.3"
          iifname "brlan" oifname "ppp0" ip saddr 10.71.71.3 drop comment "Block internet for 10.71.71.3"

          # Block 10.71.71.4 from internet
          iifname "brlan" oifname "wg0" ip saddr 10.71.71.4 drop comment "Block internet for 10.71.71.4"
          iifname "brlan" oifname "ppp0" ip saddr 10.71.71.4 drop comment "Block internet for 10.71.71.4"

          # Block Android TV (10.71.71.91) from internet
          # Prevent TV from phoning home while still allowing LAN access
          iifname "brlan" oifname "wg0" ip saddr 10.71.71.91 drop comment "Block internet for android tv"
          iifname "brlan" oifname "ppp0" ip saddr 10.71.71.91 drop comment "Block internet for android tv"

          # -----------------------------------------------------------------
          # Default LAN → Internet (via VPN)
          # -----------------------------------------------------------------
          # Main LAN and Guest network use VPN for internet by default
          # This provides privacy and security for regular browsing
          iifname "brlan" oifname "wg0" counter accept
          iifname "brguest" oifname "wg0" counter accept

          # -----------------------------------------------------------------
          # IoT Network Rules
          # -----------------------------------------------------------------
          # IoT devices are heavily restricted for security
          # Most IoT devices are blocked from internet by default

          # Specific IoT devices allowed to VPN internet
          # Only whitelisted devices get internet access
          iifname "briot" oifname "wg0" ip saddr 192.168.6.3 counter accept comment "Work laptop internet access"

          # IoT → LAN: Restricted to specific server
          # IoT devices can only reach MQTT
          iifname "briot" oifname "brlan" ip daddr 10.71.71.47 counter accept comment "IoT subnet → 10.71.71.47"
          iifname "brlan" oifname "briot" ip saddr 10.71.71.47 ct state established,related counter accept comment "Return traffic 10.71.71.47 → IoT"

          # LAN → IoT: LAN can initiate connections to IoT
          # Allow management of IoT devices from trusted LAN
          iifname "brlan" oifname "briot" counter accept comment "LAN → IoT"
          iifname "briot" oifname "brlan" ct state established,related counter accept comment "IoT return traffic → LAN"

          # -----------------------------------------------------------------
          # VPN Return Traffic
          # -----------------------------------------------------------------
          # Allow return traffic from VPN for established connections
          iifname "wg0" ct state established,related counter accept
          iifname "wg0" oifname "brdirect" ct state established,related counter accept comment "VPN return to container"
          iifname "brlan" oifname "brdirect" ct state established,related counter accept comment "LAN return to container"

          # -----------------------------------------------------------------
          # OpenVPN Client → LAN Access
          # -----------------------------------------------------------------
          # Allow OpenVPN clients (10.8.0.0/24) to reach LAN
          # Container masquerades source to 10.71.73.10 for tracking
          # Only admin OpenVPN users (10.8.0.2-9) should reach LAN
          iifname "brdirect" oifname "brlan" ip saddr { 10.8.0.0/24, 10.71.73.10 } counter accept comment "OpenVPN clients to LAN (container masquerades src to 10.71.73.10)"

          # LAN → OpenVPN container (new connections)
          # Allow LAN devices to initiate connections to OpenVPN service
          iifname "brlan" oifname "brdirect" udp dport 1194 ct state new counter accept comment "LAN to OpenVPN container"

          # OpenVPN container → LAN (replies)
          # Return traffic for connections initiated by LAN
          iifname "brdirect" oifname "brlan" ct state established,related counter accept comment "OpenVPN container replies to LAN"

          # WAN → OpenVPN container
          # Allow internet clients to connect to OpenVPN server
          iifname "ppp0" oifname "brdirect" udp dport 1194 ct state new counter accept comment "WAN to OpenVPN container"
        }
      }

      # =========================================================================
      # MANGLE TABLE - Packet Modification
      # =========================================================================
      # Used for connection marking and MSS clamping
      # Connection marks are used for policy routing decisions
      table inet mangle {
        # ---------------------------------------------------------------------
        # PREROUTING Chain - Mark Packets Before Routing Decision
        # ---------------------------------------------------------------------
        chain prerouting {
          type filter hook prerouting priority mangle; policy accept;

          # Mark port-forwarded HTTP/HTTPS packets
          # Ensures return traffic always goes via ppp0 (not wg0)
          # Routing rules check this mark (0xca6c) to select correct table
          iifname "ppp0" tcp dport { 80, 443 } ct mark set 0xca6c comment "Mark HTTP/HTTPS port-forward: return via ppp0"
          ct mark 0xca6c meta mark set 0xca6c

          # Mark OpenVPN server responses for correct routing
          # OpenVPN runs in container on brdirect, responses must go via ppp0
          # Without this, responses might try to route through wg0 (VPN)
          # Mark 0x1194 is matched by ip rule to force main table (ppp0)
          iifname "brdirect" ip saddr 10.71.73.10 udp sport 1194 meta mark set 0x1194 comment "Mark OpenVPN 1194 responses for ppp0 routing"
        }

        # ---------------------------------------------------------------------
        # FORWARD Chain - MSS Clamping
        # ---------------------------------------------------------------------
        # Adjust Maximum Segment Size to prevent fragmentation issues
        # PPPoE reduces MTU from 1500 to 1492, so MSS must be reduced
        chain forward {
          type filter hook forward priority mangle; policy accept;

          # Clamp MSS to 1452 for PPPoE connections
          # 1452 = 1492 MTU - 40 bytes (IP+TCP headers)
          # Prevents PMTUD issues and fragmentation
          oifname "ppp0" tcp flags syn tcp option maxseg size set 1452
          iifname "ppp0" tcp flags syn tcp option maxseg size set 1452
        }
      }

      # =========================================================================
      # NAT TABLE - Network Address Translation
      # =========================================================================
      # Handles source/destination NAT for masquerading and port forwarding
      table ip nat {
        # ---------------------------------------------------------------------
        # PREROUTING Chain - Destination NAT (Port Forwarding)
        # ---------------------------------------------------------------------
        # Modifies destination address for incoming connections
        # Used to forward public ports to internal servers
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;

          # Forward WAN HTTP/HTTPS to internal web server
          # External connections to port 80/443 are redirected to 10.71.71.193
          iifname "ppp0" tcp dport { 80, 443 } dnat to 10.71.71.193

          # Forward WAN OpenVPN port to container
          # External OpenVPN connections (1194/udp) go to container IP
          iifname "ppp0" udp dport 1194 dnat to 10.71.73.10:1194 comment "Forward OpenVPN to container (WAN)"

          # Forward LAN OpenVPN port to container
          # Internal clients connecting to router IP are redirected to container
          # Allows LAN clients to use router IP instead of container IP
          ip daddr 10.71.71.1 udp dport 1194 dnat to 10.71.73.10:1194 comment "Forward OpenVPN from LAN (10.71.71.1:1194 → container)"
        }

        # ---------------------------------------------------------------------
        # POSTROUTING Chain - Source NAT (Masquerading)
        # ---------------------------------------------------------------------
        # Modifies source address for outgoing connections
        # Masquerading allows internal IPs to share the external IP
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;

          # Masquerade all traffic going through VPN
          # Internal IPs are hidden behind VPN endpoint IP
          oifname "wg0" masquerade

          # Masquerade OpenVPN client traffic through VPN
          # Allows OpenVPN clients to access internet via wg0
          oifname "wg0" ip saddr 10.8.0.0/24 masquerade comment "OpenVPN clients NAT via wg0"

          # Masquerade container traffic through VPN
          # Container's own traffic (not client traffic) via wg0
          oifname "wg0" ip saddr 10.71.73.10 masquerade comment "Container to VPN masquerade"

          # Masquerade all traffic going through WAN
          # Internal IPs are hidden behind public IP
          oifname "ppp0" masquerade

          # Masquerade container traffic through WAN
          # Container's direct internet access via ppp0
          oifname "ppp0" ip saddr 10.71.73.10 masquerade comment "Container to internet masquerade"
        }
      }
    '';
  };
}
