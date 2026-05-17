{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # Speedtest Tracker Container — isolated speedtest tracker in nixos-container
  # ===========================================================================
  # This module configures an isolated Speedtest Tracker in a NixOS container.
  # 
  # Architecture:
  # - Container runs on brlan network (10.71.71.0/24)
  # - Container has its own IP: 10.71.71.54
  # - Uses native NixOS speedtest-tracker service from nixpkgs-unstable
  # - Traffic routes through wg0 (VPN) via router's default routing
  # 
  # Isolation benefits:
  # - Speedtest service is separated from main router
  # - Container can be restarted without affecting router
  # - Easier to debug and maintain
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Container Configuration
  # ---------------------------------------------------------------------------
  containers.speedtest-tracker = {
    autoStart = true;

    # Use bridge networking - connect directly to brlan bridge
    privateNetwork = true;
    hostBridge = "brlan";

    # Bind host directories to container for persistent state
    bindMounts = {
      "/var/lib/speedtest-tracker" = {
        hostPath = "/var/lib/speedtest-tracker-container";
        isReadOnly = false;
      };
    };

    config = { config, pkgs, lib, ... }: {
      # Allow unfree package for ookla-speedtest
      nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "ookla-speedtest"
      ];

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
              address = "10.71.71.54";
              prefixLength = 24;
            }
          ];
        };

        defaultGateway = "10.71.71.1";

        # Simple firewall - allow nginx
        firewall = {
          enable = true;
          allowedTCPPorts = [ 80 ];
        };
      };

      # Minimal system configuration for container
      system.stateVersion = "24.11";

      # Container needs these packages
      environment.systemPackages = with pkgs; [
        curl
        htop
      ];

      # -----------------------------------------------------------------------
      # Speedtest Tracker Service Configuration
      # -----------------------------------------------------------------------
      services.speedtest-tracker = {
        enable = true;
        
        # Enable nginx for web interface
        enableNginx = true;
        
        # Virtual host configuration
        virtualHost = "speedtest.home";
        
        # Data directory
        dataDir = "/var/lib/speedtest-tracker";
        
        # Optimize PHP-FPM pool for minimal resource usage
        # This is a low-traffic application, no need for multiple workers
        poolConfig = {
          "pm" = "dynamic";
          "pm.max_children" = 2;
          "pm.start_servers" = 1;
          "pm.min_spare_servers" = 1;
          "pm.max_spare_servers" = 1;
          "pm.max_requests" = 500;
        };
        
        # Service settings
        settings = {
          # App URL
          APP_URL = "http://speedtest.home";
          
          # Database configuration - use SQLite
          DB_CONNECTION = "sqlite";
          DB_DATABASE = "/var/lib/speedtest-tracker/database.sqlite";
          
          # Laravel app key file - generated on first boot
          APP_KEY_FILE = "/var/lib/speedtest-tracker/app-key";
          
          # Speedtest schedule - run every 10 minutes
          SPEEDTEST_SCHEDULE = "*/10 * * * *";
        };
      };

      # Generate APP_KEY on first boot if it doesn't exist
      systemd.services.speedtest-tracker-generate-key = {
        description = "Generate Speedtest Tracker APP_KEY on first boot";
        wantedBy = [ "multi-user.target" ];
        before = [ "speedtest-tracker-setup.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ pkgs.openssl pkgs.coreutils ];
        script = ''
          KEY_FILE="/var/lib/speedtest-tracker/app-key"
          
          # Only generate if key doesn't exist
          if [ ! -f "$KEY_FILE" ]; then
            echo "Generating new APP_KEY..."
            # Generate a random 32-byte key and base64 encode it
            echo -n "base64:" > "$KEY_FILE"
            openssl rand -base64 32 | tr -d '\n' >> "$KEY_FILE"
            # Set permissions so speedtest-tracker user can read it
            chown speedtest-tracker:nginx "$KEY_FILE"
            chmod 640 "$KEY_FILE"
            echo "APP_KEY generated successfully"
          else
            echo "APP_KEY already exists, ensuring correct permissions..."
            chown speedtest-tracker:nginx "$KEY_FILE"
            chmod 640 "$KEY_FILE"
          fi
        '';
      };

      # Configure nginx to listen on all interfaces
      services.nginx = {
        enable = true;
        virtualHosts."speedtest.home" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 80;
            }
          ];
        };
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Host Configuration for Container
  # ---------------------------------------------------------------------------
  
  # Create directories for container's persistent state
  systemd.tmpfiles.rules = [
    "d /var/lib/speedtest-tracker-container 0755 root root -"
  ];

  # DNS configuration - make speedtest.home resolve to container IP
  # Add dnsmasq host entry to override wildcard *.home -> 10.71.71.75
  services.dnsmasq.settings = {
    address = [
      "/speedtest.home/10.71.71.54"
    ];
  };
}
