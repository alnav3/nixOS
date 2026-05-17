{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # Tinyproxy Container — isolated HTTP/HTTPS proxy in nixos-container
  # ===========================================================================
  # This module configures an isolated Tinyproxy HTTP/HTTPS proxy in a NixOS container.
  # 
  # Architecture:
  # - Container runs on brlan network (10.71.71.0/24)
  # - Container has its own IP: 10.71.71.55
  # - Listens on port 8888 for proxy connections
  # - Traffic routes through wg0 (VPN) via router's default routing
  # 
  # Isolation benefits:
  # - Proxy service is separated from main router
  # - Container can be restarted without affecting router
  # - Easier to debug and maintain
  # - Security: compromise of proxy doesn't affect router
  # 
  # Use case:
  # - Provides HTTP/HTTPS proxy access for LAN devices
  # - All proxy traffic goes through VPN for privacy
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Container Configuration
  # ---------------------------------------------------------------------------
  containers.tinyproxy = {
    autoStart = true;

    # Use bridge networking - connect directly to brlan bridge
    privateNetwork = true;
    hostBridge = "brlan";

    config = { config, pkgs, lib, ... }: {
      # Basic container networking
      networking = {
        useHostResolvConf = false;
        useDHCP = false;
        nameservers = [ "10.71.71.1" ];  # Use router for DNS

        # systemd-nspawn with --network-bridge names the interface eth0 in the container
        interfaces.eth0 = {
          useDHCP = false;
          ipv4.addresses = [
            {
              address = "10.71.71.55";
              prefixLength = 24;
            }
          ];
        };

        defaultGateway = "10.71.71.1";

        # Simple firewall - allow proxy port
        firewall = {
          enable = true;
          allowedTCPPorts = [ 8888 ];
        };
      };

      # Minimal system configuration for container
      system.stateVersion = "24.11";

      # Container needs these packages
      environment.systemPackages = with pkgs; [
        curl
        htop
        tinyproxy
      ];

      # -----------------------------------------------------------------------
      # Tinyproxy Service Configuration
      # -----------------------------------------------------------------------
      services.tinyproxy = {
        enable = true;
        
        settings = {
          # Listen on all interfaces in the container
          Port = 8888;
          Listen = "0.0.0.0";
          
          # Timeout settings
          Timeout = 600;
          
          # Allow connections from LAN network only
          Allow = "10.71.71.0/24";
          
          # Logging
          LogFile = "/var/log/tinyproxy/tinyproxy.log";
          LogLevel = "Info";
          
          # Performance tuning
          MaxClients = 100;
          MinSpareServers = 5;
          MaxSpareServers = 20;
          StartServers = 10;
          
          # Security - disable via header
          DisableViaHeader = "Yes";
          
          # Filtering
          FilterURLs = "No";
          FilterExtended = "No";
        };
      };

      # Create log directory
      systemd.tmpfiles.rules = [
        "d /var/log/tinyproxy 0755 tinyproxy tinyproxy -"
      ];
    };
  };

  # ---------------------------------------------------------------------------
  # Host Configuration for Container
  # ---------------------------------------------------------------------------
  
  # No additional host configuration needed for tinyproxy
  # Container will automatically route through router's default gateway (wg0)
}
