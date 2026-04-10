{ config, lib, pkgs, ... }:
{
  # ===========================================================================
  # Monitoring Configuration (Prometheus + Grafana + Per-Client Bandwidth)
  # ===========================================================================
  # This module sets up comprehensive monitoring for the router:
  # - Prometheus: Time-series database for metrics collection
  # - Grafana: Visualization and dashboards
  # - Node Exporter: System metrics (CPU, memory, disk, network)
  # - Client Traffic Tracker: Per-client bandwidth monitoring via nftables
  #
  # Access:
  # - Grafana: http://10.71.71.1:3030 (default login: admin/admin)
  # - Prometheus: http://10.71.71.1:9090
  #
  # Based on: https://blog.arsfeld.dev/posts/2025/07/22/nixos-router-blog-post-3-monitoring/
  #
  # ---------------------------------------------------------------------------
  # Optional: Advanced Per-Client Metrics with network-metrics-exporter
  # ---------------------------------------------------------------------------
  # For more advanced per-client bandwidth metrics with persistent names,
  # add the arsfeld-nixos flake input and enable network-metrics-exporter:
  #
  # 1. Add to flake.nix inputs:
  #    arsfeld-nixos.url = "github:arsfeld/nixos";
  #
  # 2. Add the module to router's modules list in flake.nix:
  #    arsfeld-nixos.nixosModules.network-metrics-exporter
  #
  # 3. Configure in this file or separately:
  #    services.network-metrics-exporter = {
  #      enable = true;
  #      lanInterface = "brlan";
  #      wanInterface = "ppp0";
  #      localSubnet = "10.71.71.0/24";
  #      enableNftables = true;
  #      port = 9101;
  #      staticClients = {
  #        "10.71.71.100" = "my-desktop";
  #        "10.71.71.101" = "smart-tv";
  #      };
  #    };
  #
  # 4. Add scrape config to Prometheus (uncomment in scrapeConfigs below)
  # ===========================================================================

  # ===========================================================================
  # Secrets (via sops-nix)
  # ===========================================================================
  sops.secrets.grafana_secret_key = {
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  # ===========================================================================
  # Per-Client Network Metrics (via textfile collector)
  # ===========================================================================
  # Reads nftables counters from CLIENT_TRAFFIC chain and exposes them
  # as Prometheus metrics via node-exporter's textfile collector.
  # ===========================================================================
  
  # Static client names - customize for your network
  # Maps IP addresses to friendly hostnames
  environment.etc."network-metrics/static-clients.conf" = {
    mode = "0644";
    text = ''
      # Format: IP=hostname
      # Internet infrastructure
      10.71.71.2=omada
      10.71.71.3=Access-Point
      10.71.71.4=unifi-switch
      10.71.71.9=homeassistant
      # MQTT app & devices
      10.71.71.40=everything_remote
      10.71.71.47=mqtt
      # IoT devices
      192.168.6.2=tv-lights
      192.168.6.4=Creality_K1
      192.168.6.5=vacuum
      # alnav trusted devices
      10.71.71.11=deck
      10.71.71.12=mjolnir
      10.71.71.13=PixelPro
      10.71.71.14=framework
      # alnav work laptop
      192.168.6.3=work-laptop
      # Home untrusted devices
      10.71.71.91=Living-TV
    '';
  };
  
  # Script to collect per-client metrics from conntrack
  environment.etc."network-metrics/collect-metrics.sh" = {
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      # Collects per-client connection counts from conntrack
      # Note: Byte counters don't work with flow offloading enabled
      # Outputs in Prometheus text format for node-exporter textfile collector
      
      set -euo pipefail
      
      OUTPUT_FILE="/var/lib/prometheus-node-exporter/client_traffic.prom"
      TMP_FILE="$OUTPUT_FILE.tmp"
      STATIC_CLIENTS="/etc/network-metrics/static-clients.conf"
      CONNTRACK="${pkgs.conntrack-tools}/bin/conntrack"
      AWK="${pkgs.gawk}/bin/awk"
      GREP="${pkgs.gnugrep}/bin/grep"
      SORT="${pkgs.coreutils}/bin/sort"
      UNIQ="${pkgs.coreutils}/bin/uniq"
      DATE="${pkgs.coreutils}/bin/date"
      
      # LAN subnets to monitor (patterns for grep)
      LAN_PATTERNS="10\.71\.71\.|10\.71\.72\.|10\.71\.73\.|192\.168\.6\."
      
      # Load static client names
      declare -A CLIENT_NAMES
      if [[ -f "$STATIC_CLIENTS" ]]; then
        while IFS='=' read -r ip hostname; do
          [[ "$ip" =~ ^#.*$ || -z "$ip" ]] && continue
          ip=$(echo "$ip" | xargs)  # trim whitespace
          hostname=$(echo "$hostname" | xargs)
          [[ -n "$ip" ]] && CLIENT_NAMES["$ip"]="$hostname"
        done < "$STATIC_CLIENTS"
      fi
      
      # Get hostname for IP
      get_hostname() {
        local ip="$1"
        if [[ -n "''${CLIENT_NAMES[$ip]:-}" ]]; then
          echo "''${CLIENT_NAMES[$ip]}"
        else
          echo "$ip"
        fi
      }
      
      # Create directories
      mkdir -p "$(dirname "$OUTPUT_FILE")"
      mkdir -p /var/lib/network-metrics
      
      # Get conntrack data and count connections per client
      declare -A CONN_COUNT
      
      while read -r ip; do
        [[ -n "$ip" ]] && CONN_COUNT[$ip]=$(( ''${CONN_COUNT[$ip]:-0} + 1 ))
      done < <($CONNTRACK -L 2>/dev/null | $GREP -oE "src=($LAN_PATTERNS)[0-9]+" | $GREP -oE "($LAN_PATTERNS)[0-9]+" | $SORT)
      
      # Write metrics
      {
        echo "# HELP client_active_connections Number of active connections for client"
        echo "# TYPE client_active_connections gauge"
        echo "# HELP client_online Client is currently online (has active connections)"
        echo "# TYPE client_online gauge"
        
        now=$($DATE +%s)
        
        for ip in "''${!CONN_COUNT[@]}"; do
          # Skip router IPs
          [[ "$ip" == "10.71.71.1" || "$ip" == "10.71.72.1" || "$ip" == "10.71.73.1" || "$ip" == "192.168.6.1" ]] && continue
          
          hostname=$(get_hostname "$ip")
          conns="''${CONN_COUNT[$ip]}"
          
          echo "client_active_connections{ip=\"$ip\",hostname=\"$hostname\"} $conns"
          echo "client_online{ip=\"$ip\",hostname=\"$hostname\"} 1"
        done
        
      } > "$TMP_FILE"
      
      # Atomic move
      mv "$TMP_FILE" "$OUTPUT_FILE"
    '';
  };

  # ===========================================================================
  # Prometheus - Metrics Collection
  # ===========================================================================
  services.prometheus = {
    enable = true;
    port = 9090;

    # Global scrape configuration
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    # Scrape configurations for all exporters
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
        }];
      }
      {
        job_name = "prometheus";
        static_configs = [{
          targets = [ "localhost:9090" ];
        }];
      }
      #   job_name = "network-metrics";
      #   static_configs = [{
      #     targets = [ "localhost:9101" ];
      #   }];
      #   scrape_interval = "5s";  # More frequent for real-time data
      # }
    ];

    # Alert rules for bandwidth monitoring
    rules = [
      ''
        groups:
        - name: bandwidth
          rules:
          - alert: HighBandwidthUsage
            expr: rate(node_network_receive_bytes_total{device="brlan"}[5m]) > 100000000
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High bandwidth usage on LAN"
              description: "LAN interface receiving at {{ $value | humanize }}B/s"

          - alert: WireguardDown
            expr: absent(node_network_up{device="wg0"}) or node_network_up{device="wg0"} == 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "WireGuard VPN is down"
              description: "The wg0 interface is not up"

          - alert: PPPoEDown
            expr: absent(node_network_up{device="ppp0"}) or node_network_up{device="ppp0"} == 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "PPPoE connection is down"
              description: "The ppp0 interface is not up"
      ''
    ];
  };

  # ===========================================================================
  # Node Exporter - System Metrics
  # ===========================================================================
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [
      "systemd"
      "diskstats"
      "filesystem"
      "loadavg"
      "meminfo"
      "netdev"
      "netclass"
      "stat"
      "time"
      "uname"
      "conntrack"
      "textfile"  # Enable textfile collector for custom metrics
    ];
    extraFlags = [
      "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|run)($|/)"
      "--collector.textfile.directory=/var/lib/prometheus-node-exporter"
    ];
  };
  
  # Create textfile collector directory
  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus-node-exporter 0755 root root -"
    "d /var/lib/network-metrics 0755 root root -"
  ];
  
  # Service to collect client metrics
  systemd.services.collect-client-metrics = {
    description = "Collect per-client network metrics from conntrack";
    after = [ "network.target" "nftables.service" ];
    requires = [ "nftables.service" ];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/network-metrics/collect-metrics.sh";
      RemainAfterExit = false;
      # Need CAP_NET_ADMIN to read conntrack
      AmbientCapabilities = [ "CAP_NET_ADMIN" ];
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
    };
    
    path = with pkgs; [ bash nftables conntrack-tools gnugrep gawk coreutils ];
  };
  
  # Timer to run collection every 5 seconds
  systemd.timers.collect-client-metrics = {
    description = "Periodic client metrics collection";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5s";
      Unit = "collect-client-metrics.service";
    };
  };

  # ===========================================================================
  # Grafana - Visualization
  # ===========================================================================
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";  # Listen on all interfaces
        http_port = 3030;
        domain = "10.71.71.1";  # Router LAN IP
        root_url = "http://10.71.71.1:3030";
      };

      # Disable analytics/telemetry
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
      };

      # Anonymous read-only access for dashboards
      "auth.anonymous" = {
        enabled = true;
        org_role = "Viewer";
      };

      # Security settings
      security = {
        admin_user = "admin";
        # Default password - change after first login!
        admin_password = "admin";
        allow_embedding = true;
        # Secret key for signing (loaded from sops)
        secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";
      };
    };

    # Automatic datasource provisioning
    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        deleteDatasources = [];
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:9090";
            access = "proxy";
            isDefault = true;
          }
        ];
      };
      # Dashboard provisioning
      dashboards.settings.providers = [
        {
          name = "Router Dashboards";
          type = "file";
          folder = "Router";
          options.path = "/etc/grafana-dashboards";
          disableDeletion = false;
          updateIntervalSeconds = 10;
        }
      ];
    };
  };

  # Router overview dashboard
  environment.etc."grafana-dashboards/router-overview.json" = {
    mode = "0644";
    text = builtins.toJSON {
      annotations.list = [];
      editable = true;
      fiscalYearStartMonth = 0;
      graphTooltip = 0;
      id = null;
      links = [];
      panels = [
        # CPU Usage Panel
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "palette-classic";
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisLabel = "";
                axisPlacement = "auto";
                barAlignment = 0;
                drawStyle = "line";
                fillOpacity = 10;
                gradientMode = "none";
                lineInterpolation = "linear";
                lineWidth = 1;
                pointSize = 5;
                showPoints = "never";
                spanNulls = false;
                stacking.mode = "none";
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  { color = "green"; value = null; }
                  { color = "yellow"; value = 50; }
                  { color = "red"; value = 80; }
                ];
              };
              unit = "percent";
              max = 100;
              min = 0;
            };
          };
          gridPos = { h = 8; w = 12; x = 0; y = 0; };
          id = 1;
          options = {
            legend = { calcs = [ "mean" "max" ]; displayMode = "list"; placement = "bottom"; };
            tooltip.mode = "multi";
          };
          targets = [
            {
              expr = ''100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
              legendFormat = "CPU Usage";
              refId = "A";
            }
          ];
          title = "CPU Usage";
          type = "timeseries";
        }
        # Memory Usage Panel
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "palette-classic";
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisPlacement = "auto";
                drawStyle = "line";
                fillOpacity = 10;
                lineWidth = 1;
                pointSize = 5;
                showPoints = "never";
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  { color = "green"; value = null; }
                  { color = "yellow"; value = 70; }
                  { color = "red"; value = 90; }
                ];
              };
              unit = "percent";
              max = 100;
              min = 0;
            };
          };
          gridPos = { h = 8; w = 12; x = 12; y = 0; };
          id = 2;
          targets = [
            {
              expr = ''(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100'';
              legendFormat = "Memory Usage";
              refId = "A";
            }
          ];
          title = "Memory Usage";
          type = "timeseries";
        }
        # Network Traffic - WAN (ppp0)
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "palette-classic";
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisPlacement = "auto";
                drawStyle = "line";
                fillOpacity = 10;
                lineWidth = 1;
                pointSize = 5;
                showPoints = "never";
              };
              mappings = [];
              unit = "bps";
            };
          };
          gridPos = { h = 8; w = 12; x = 0; y = 8; };
          id = 3;
          targets = [
            {
              expr = ''rate(node_network_receive_bytes_total{device="ppp0"}[1m]) * 8'';
              legendFormat = "Download (ppp0)";
              refId = "A";
            }
            {
              expr = ''rate(node_network_transmit_bytes_total{device="ppp0"}[1m]) * 8'';
              legendFormat = "Upload (ppp0)";
              refId = "B";
            }
          ];
          title = "WAN Traffic (ppp0)";
          type = "timeseries";
        }
        # Network Traffic - VPN (wg0)
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "palette-classic";
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisPlacement = "auto";
                drawStyle = "line";
                fillOpacity = 10;
                lineWidth = 1;
                pointSize = 5;
                showPoints = "never";
              };
              mappings = [];
              unit = "bps";
            };
          };
          gridPos = { h = 8; w = 12; x = 12; y = 8; };
          id = 4;
          targets = [
            {
              expr = ''rate(node_network_receive_bytes_total{device="wg0"}[1m]) * 8'';
              legendFormat = "Download (wg0)";
              refId = "A";
            }
            {
              expr = ''rate(node_network_transmit_bytes_total{device="wg0"}[1m]) * 8'';
              legendFormat = "Upload (wg0)";
              refId = "B";
            }
          ];
          title = "VPN Traffic (wg0)";
          type = "timeseries";
        }
        # Network Traffic - LAN Bridge
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "palette-classic";
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisPlacement = "auto";
                drawStyle = "line";
                fillOpacity = 10;
                lineWidth = 1;
                pointSize = 5;
                showPoints = "never";
              };
              mappings = [];
              unit = "bps";
            };
          };
          gridPos = { h = 8; w = 12; x = 0; y = 16; };
          id = 5;
          targets = [
            {
              expr = ''rate(node_network_receive_bytes_total{device="brlan"}[1m]) * 8'';
              legendFormat = "RX (brlan)";
              refId = "A";
            }
            {
              expr = ''rate(node_network_transmit_bytes_total{device="brlan"}[1m]) * 8'';
              legendFormat = "TX (brlan)";
              refId = "B";
            }
          ];
          title = "LAN Traffic (brlan)";
          type = "timeseries";
        }
        # Per-Client Active Connections
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "palette-classic";
              custom = {
                axisBorderShow = false;
                axisCenteredZero = false;
                axisColorMode = "text";
                axisPlacement = "auto";
                drawStyle = "line";
                fillOpacity = 10;
                lineWidth = 1;
                pointSize = 5;
                showPoints = "never";
                stacking.mode = "normal";
              };
              mappings = [];
              unit = "short";
            };
          };
          gridPos = { h = 8; w = 12; x = 12; y = 16; };
          id = 6;
          options = {
            legend = { calcs = [ "mean" "max" "last" ]; displayMode = "table"; placement = "right"; };
            tooltip.mode = "multi";
          };
          targets = [
            {
              expr = ''client_active_connections'';
              legendFormat = "{{hostname}}";
              refId = "A";
            }
          ];
          title = "Per-Client Active Connections";
          type = "timeseries";
        }
        # System Load
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "thresholds";
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  { color = "green"; value = null; }
                  { color = "yellow"; value = 2; }
                  { color = "red"; value = 4; }
                ];
              };
              unit = "short";
            };
          };
          gridPos = { h = 4; w = 6; x = 0; y = 24; };
          id = 7;
          options = {
            colorMode = "value";
            graphMode = "area";
            justifyMode = "auto";
            orientation = "auto";
            reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
          };
          targets = [
            {
              expr = "node_load1";
              legendFormat = "Load 1m";
              refId = "A";
            }
          ];
          title = "System Load (1m)";
          type = "stat";
        }
        # Uptime
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "thresholds";
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  { color = "green"; value = null; }
                ];
              };
              unit = "s";
            };
          };
          gridPos = { h = 4; w = 6; x = 6; y = 24; };
          id = 8;
          options = {
            colorMode = "value";
            graphMode = "none";
            justifyMode = "auto";
            orientation = "auto";
            reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
          };
          targets = [
            {
              expr = "time() - node_boot_time_seconds";
              legendFormat = "Uptime";
              refId = "A";
            }
          ];
          title = "Uptime";
          type = "stat";
        }
        # Disk Usage
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "thresholds";
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  { color = "green"; value = null; }
                  { color = "yellow"; value = 70; }
                  { color = "red"; value = 90; }
                ];
              };
              unit = "percent";
              max = 100;
              min = 0;
            };
          };
          gridPos = { h = 4; w = 6; x = 12; y = 24; };
          id = 9;
          options = {
            colorMode = "value";
            graphMode = "area";
            justifyMode = "auto";
            orientation = "auto";
            reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
          };
          targets = [
            {
              expr = ''(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100'';
              legendFormat = "Root Disk";
              refId = "A";
            }
          ];
          title = "Disk Usage (/)";
          type = "stat";
        }
        # Network Interfaces Status
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "thresholds";
              mappings = [
                { options = { "0" = { color = "red"; index = 1; text = "DOWN"; }; }; type = "value"; }
                { options = { "1" = { color = "green"; index = 0; text = "UP"; }; }; type = "value"; }
              ];
              thresholds = {
                mode = "absolute";
                steps = [
                  { color = "red"; value = null; }
                  { color = "green"; value = 1; }
                ];
              };
            };
          };
          gridPos = { h = 4; w = 6; x = 18; y = 24; };
          id = 10;
          options = {
            colorMode = "background";
            graphMode = "none";
            justifyMode = "auto";
            orientation = "horizontal";
            reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
          };
          targets = [
            {
              expr = ''node_network_up{device=~"ppp0|wg0|brlan|brguest|briot"}'';
              legendFormat = "{{device}}";
              refId = "A";
            }
          ];
          title = "Interface Status";
          type = "stat";
        }
        # Active Clients Count
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "thresholds";
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  { color = "green"; value = null; }
                  { color = "yellow"; value = 20; }
                  { color = "red"; value = 50; }
                ];
              };
              unit = "short";
            };
          };
          gridPos = { h = 4; w = 6; x = 0; y = 36; };
          id = 13;
          options = {
            colorMode = "value";
            graphMode = "area";
            justifyMode = "auto";
            orientation = "auto";
            reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
          };
          targets = [
            {
              expr = ''count(client_active_connections > 0)'';
              legendFormat = "Active Clients";
              refId = "A";
            }
          ];
          title = "Active Clients";
          type = "stat";
        }
        # Client Connections Table
        {
          datasource = "Prometheus";
          fieldConfig = {
            defaults = {
              color.mode = "thresholds";
              custom = {
                align = "auto";
                displayMode = "auto";
              };
              mappings = [];
              thresholds = {
                mode = "absolute";
                steps = [
                  { color = "green"; value = null; }
                ];
              };
            };
            overrides = [
              {
                matcher = { id = "byName"; options = "Value"; };
                properties = [{ id = "displayName"; value = "Connections"; }];
              }
            ];
          };
          gridPos = { h = 8; w = 18; x = 6; y = 36; };
          id = 14;
          options = {
            showHeader = true;
            sortBy = [{ desc = true; displayName = "Connections"; }];
          };
          targets = [
            {
              expr = ''client_active_connections'';
              format = "table";
              instant = true;
              legendFormat = "";
              refId = "A";
            }
          ];
          title = "Client Connections";
          transformations = [
            { id = "organize"; options = { excludeByName = { Time = true; __name__ = true; job = true; instance = true; }; }; }
          ];
          type = "table";
        }
      ];
      refresh = "5s";
      schemaVersion = 39;
      tags = [ "router" "network" ];
      templating.list = [];
      time = { from = "now-1h"; to = "now"; };
      timepicker = {};
      timezone = "browser";
      title = "Router Overview";
      uid = "router-overview";
      version = 1;
    };
  };

  # Ensure Grafana starts after secrets are available
  systemd.services.grafana.after = [ "sops-nix.service" ];

  # ===========================================================================
  # Client Traffic Tracker Service
  # ===========================================================================
  # This service discovers active clients on the network and creates
  # nftables accounting rules for per-client bandwidth tracking.
  #
  # It periodically scans ARP table and connection tracking to find clients,
  # then creates counter rules in the CLIENT_TRAFFIC chain.
  # ===========================================================================

  # Client traffic tracker script
  environment.etc."client-traffic-tracker.sh" = {
    mode = "0755";
    text = ''
      #!${pkgs.bash}/bin/bash
      # Client Traffic Tracker - Discovers clients and creates nftables accounting rules
      # This script creates per-client counter rules for bandwidth monitoring

      set -euo pipefail

      # Configuration
      STATE_DIR="/var/lib/client-traffic"
      SUBNETS=("10.71.71.0/24" "10.71.72.0/24" "192.168.6.0/24" "10.71.73.0/24")
      EXCLUDE_IPS=("10.71.71.1" "10.71.72.1" "192.168.6.1" "10.71.73.1" "10.71.71.255" "10.71.72.255" "192.168.6.255" "10.71.73.255")

      # Create state directory
      mkdir -p "$STATE_DIR"

      # Check if CLIENT_TRAFFIC chain exists, create if not
      if ! ${pkgs.nftables}/bin/nft list chain inet filter CLIENT_TRAFFIC &>/dev/null; then
        echo "Creating CLIENT_TRAFFIC chain..."
        ${pkgs.nftables}/bin/nft add chain inet filter CLIENT_TRAFFIC
      fi

      # Function to check if IP should be excluded
      is_excluded() {
        local ip="$1"
        for exclude in "''${EXCLUDE_IPS[@]}"; do
          if [[ "$ip" == "$exclude" ]]; then
            return 0
          fi
        done
        return 1
      }

      # Function to check if rule exists for IP
      rule_exists() {
        local ip="$1"
        local direction="$2"  # tx or rx
        ${pkgs.nftables}/bin/nft list chain inet filter CLIENT_TRAFFIC 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "comment \"''${direction}_''${ip}\""
      }

      # Function to add accounting rules for an IP
      add_client_rules() {
        local ip="$1"
        
        # Add TX rule (traffic FROM client)
        if ! rule_exists "$ip" "tx"; then
          echo "Adding TX rule for $ip"
          ${pkgs.nftables}/bin/nft add rule inet filter CLIENT_TRAFFIC ip saddr "$ip" counter comment "\"tx_$ip\""
        fi
        
        # Add RX rule (traffic TO client)
        if ! rule_exists "$ip" "rx"; then
          echo "Adding RX rule for $ip"
          ${pkgs.nftables}/bin/nft add rule inet filter CLIENT_TRAFFIC ip daddr "$ip" counter comment "\"rx_$ip\""
        fi
      }

      # Discover clients from ARP table
      echo "Discovering clients from ARP table..."
      while read -r ip _; do
        if [[ -n "$ip" ]] && ! is_excluded "$ip"; then
          add_client_rules "$ip"
        fi
      done < <(${pkgs.iproute2}/bin/ip neigh show | ${pkgs.gnugrep}/bin/grep -E '(brlan|brguest|briot|brdirect)' | ${pkgs.gnugrep}/bin/grep -v FAILED | ${pkgs.gawk}/bin/awk '{print $1}')

      # Discover clients from connection tracking
      echo "Discovering clients from conntrack..."
      for subnet in "''${SUBNETS[@]}"; do
        prefix="''${subnet%.*}"  # Get network prefix (e.g., 10.71.71)
        while read -r ip; do
          if [[ -n "$ip" ]] && ! is_excluded "$ip"; then
            add_client_rules "$ip"
          fi
        done < <(${pkgs.conntrack-tools}/bin/conntrack -L 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oE "''${prefix}\.[0-9]+" | ${pkgs.coreutils}/bin/sort -u)
      done

      echo "Client discovery complete"
    '';
  };

  # Systemd service for client traffic tracking
  systemd.services.client-traffic-tracker = {
    description = "Client Traffic Tracker - Per-client bandwidth monitoring";
    after = [ "network.target" "nftables.service" ];
    requires = [ "nftables.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/client-traffic-tracker.sh";
      RemainAfterExit = false;
    };
  };

  # Timer to run client discovery periodically
  systemd.timers.client-traffic-tracker = {
    description = "Periodic client traffic discovery";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "60s";
      Unit = "client-traffic-tracker.service";
    };
  };

  # ===========================================================================
  # Firewall Rules for Monitoring Services
  # ===========================================================================
  # Note: No additional firewall rules needed - the main firewall.nix already
  # accepts all traffic from brlan to the router:
  #   iifname "brlan" counter accept
  #
  # Access:
  # - Grafana: http://10.71.71.1:3030 (from brlan)
  # - Prometheus: http://10.71.71.1:9090 (from brlan)
  # ===========================================================================

  # ===========================================================================
  # Additional Packages
  # ===========================================================================
  environment.systemPackages = with pkgs; [
    # Useful for debugging metrics
    prometheus-node-exporter
  ];
}
