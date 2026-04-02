{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # OpenVPN Container — isolated OpenVPN server in nixos-container
  #
  # This wraps the OpenVPN server in a container that:
  # - Uses VLAN 100 (brdirect) network, bypassing WireGuard
  # - Has access to tun0 device for VPN clients
  # - Maps port 1194 from host to container
  # - Isolates OpenVPN from the main router system
  # ===========================================================================

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

      # Add routing for OpenVPN clients
      systemd.services.openvpn-routing = {
          description = "Setup OpenVPN client routing";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
          };
          path = [ pkgs.iproute2 pkgs.iptables ];
          script = ''
              ip route add 10.71.71.0/24 via 10.71.73.1 dev eth0 || true
              iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE || true
              iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT || true
              iptables -A FORWARD -i eth0 -o tun0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || true
              '';
      };
    };
  };

  # Create directories for container's persistent state
  systemd.tmpfiles.rules = [
    "d /var/lib/openvpn-container 0755 root root -"
    "d /var/log/openvpn-container 0755 root root -"
  ];

  # The container will be connected to brdirect bridge automatically
  # by the nixos-container system when using localAddress/hostAddress

  # Port forwarding from WAN to container using nftables (since NAT is disabled)
  # The port forwarding will be handled by the nftables rules below


}
