{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # OpenVPN Container — isolated OpenVPN server in nixos-container
  # ===========================================================================
  # This module configures an isolated OpenVPN server in a NixOS container.
  # 
  # Architecture:
  # - Container runs on brdirect network (10.71.73.0/24)
  # - Container has its own IP: 10.71.73.10
  # - OpenVPN clients get IPs from 10.8.0.0/24 subnet
  # - Container routes client traffic through host router
  # 
  # Isolation benefits:
  # - OpenVPN service is separated from main router
  # - Container can be restarted without affecting router
  # - Easier to debug and maintain
  # - Security: compromise of OpenVPN doesn't affect router
  # 
  # Routing:
  # - Admin users (10.8.0.2-9): Get LAN access + internet via VPN
  # - Regular users (10.8.0.10+): Internet only via VPN, no LAN access
  # - Container routes all traffic through host's wg0 (VPN) or ppp0 (WAN)
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Container Configuration
  # ---------------------------------------------------------------------------
  containers.openvpn = {
    autoStart = true;

    # Enable tun device in container for OpenVPN
    enableTun = true;

    # Use bridge networking - connect directly to brdirect bridge
    privateNetwork = true;
    hostBridge = "brdirect";

    # Bind host directories to container for persistent state
    bindMounts = {
      "/var/lib/openvpn" = {
        hostPath = "/var/lib/openvpn-container";
        isReadOnly = false;
      };
      "/var/log/openvpn" = {
        hostPath = "/var/log/openvpn-container";
        isReadOnly = false;
      };
    };

    # Additional devices the container needs access to
    allowedDevices = [
      {
        modifier = "rw";
        node = "/dev/net/tun";
      }
    ];

    config = { config, pkgs, ... }: {
      # Import the original OpenVPN configuration
      imports = [
        ./openvpn.nix
      ];

      # Override the OpenVPN server configuration for container environment
      services.openvpn.servers.home.config = lib.mkForce ''
        port 1194
        proto udp
        dev tun0
        ca /var/lib/openvpn/home/pki/ca.crt
        cert /var/lib/openvpn/home/pki/server.crt
        key /var/lib/openvpn/home/pki/server.key
        dh /var/lib/openvpn/home/pki/dh.pem
        tls-auth /var/lib/openvpn/home/pki/ta.key 0
        topology subnet
        server 10.8.0.0 255.255.255.0
        client-config-dir /etc/openvpn/home/ccd
        ifconfig-pool-persist /var/lib/openvpn/home/ipp.txt
        # Username/password auth — no client certificate required
        auth-user-pass-verify /etc/openvpn/home/auth.sh via-file
        username-as-common-name
        verify-client-cert none
        script-security 2
        keepalive 10 120
        cipher AES-256-GCM
        auth SHA256
        persist-key
        persist-tun
        # Push DNS + search domain so clients resolve .home and unqualified names
        # Point to the host router for DNS resolution
        push "dhcp-option DNS 10.71.73.1"
        push "dhcp-option DOMAIN home"
        push "dhcp-option DOMAIN-SEARCH home"
        # Push gateway for internet access via container's routing
        push "redirect-gateway def1"
        status /var/log/openvpn/home-status.log
        verb 3
      '';

      # Basic container networking - use host's network stack for routing
      networking = {
        useHostResolvConf = false;
        useDHCP = false;             # no DHCP on any interface — static only
        nameservers = [ "10.71.73.1" ];

        # systemd-nspawn with --network-bridge names the interface eth0 in the container
        interfaces.eth0 = {
          useDHCP = false;
          ipv4.addresses = [
            {
              address = "10.71.73.10";
              prefixLength = 24;
            }
          ];
        };

        defaultGateway = "10.71.73.1";

        # Allow the container's own firewall to forward VPN client traffic
        firewall.enable = false;
      };

      # Enable IP forwarding in container for OpenVPN routing
      boot.kernel.sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv4.conf.default.forwarding" = true;
      };

      # Minimal system configuration for container
      system.stateVersion = "24.11";

      # Container needs these packages
      environment.systemPackages = with pkgs; [
        openssl
        openvpn
        iproute2
        iptables
      ];

      # -----------------------------------------------------------------------
      # Container Routing Configuration
      # -----------------------------------------------------------------------
      # Sets up routing for OpenVPN clients inside the container
      # Clients need to reach LAN and internet through the host
      systemd.services.openvpn-routing = {
          description = "Setup OpenVPN client routing inside container";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
          };
          path = [ pkgs.iproute2 pkgs.iptables ];
          script = ''
              # Add route to LAN via host router
              # OpenVPN clients need this to reach LAN devices
              ip route add 10.71.71.0/24 via 10.71.73.1 dev eth0 || true
              
              # Masquerade OpenVPN client traffic going to host
              # This makes all client traffic appear to come from container IP (10.71.73.10)
              # Host firewall uses this to identify and route OpenVPN traffic
              iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE || true
              
              # Allow forwarding from VPN tunnel to eth0 (host)
              iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT || true
              
              # Allow return traffic from host to VPN clients
              iptables -A FORWARD -i eth0 -o tun0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || true
              '';
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Host Configuration for Container
  # ---------------------------------------------------------------------------
  
  # Create directories for container's persistent state
  # These directories are bind-mounted into the container
  systemd.tmpfiles.rules = [
    "d /var/lib/openvpn-container 0755 root root -"
    "d /var/log/openvpn-container 0755 root root -"
  ];

  # ---------------------------------------------------------------------------
  # OpenVPN Client Routing Service (Host Side)
  # ---------------------------------------------------------------------------
  # Configures host routing for OpenVPN client subnet
  # Ensures OpenVPN traffic is routed correctly and cannot bypass VPN policy
  systemd.services.openvpn-client-routing = {
      description = "Route OpenVPN client subnet via the container + protect against bypass";
      after = [ "nftables.service" "wg-quick-wg0.service" "container@openvpn.service" "vpn-bypass-restore.service" ];
      wants = [ "nftables.service" "wg-quick-wg0.service" "container@openvpn.service" "vpn-bypass-restore.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      path = [ pkgs.iproute2 ];
      script = ''
          # Remove any old rules for OpenVPN client subnet
          # Clean slate before adding new rules
          ip rule del from 10.8.0.0/24 table main priority 90 2>/dev/null || true
          ip rule del from 10.8.0.0/24 table main 2>/dev/null || true
          ip route del 10.8.0.0/24 dev brdirect 2>/dev/null || true
          
          # Add route for OpenVPN client subnet via container
          # All traffic to/from 10.8.0.0/24 goes through container IP
          ip route add 10.8.0.0/24 via 10.71.73.10 dev brdirect || true
          
          # Force OpenVPN port 1194 responses (marked 0x1194) to always use ppp0 (main table)
          # This ensures OpenVPN server responses go out via WAN, not VPN
          # Priority 30 runs before wg-quick's routing rules (which are ~51)
          # Without this, OpenVPN responses might try to route through wg0, breaking connectivity
          ip rule del fwmark 0x1194 table main priority 30 2>/dev/null || true
          ip rule add fwmark 0x1194 table main priority 30
          
          echo "OpenVPN client routing (via container) + bypass protection applied"
          '';
  };
}
