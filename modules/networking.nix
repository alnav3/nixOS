{ config, lib, pkgs, pkgs-unstable ? pkgs, ... }:

let
  cfg = config.mymodules.networking;
in
{
  options.mymodules.networking = {
    enable = lib.mkEnableOption "Networking configuration";

    # NetworkManager
    networkManager = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NetworkManager";
    };

    # DNS configuration
    dns = {
      resolved = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable systemd-resolved DNS";
      };

      dnssec = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable DNSSEC validation";
      };

      fallbackDns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "9.9.9.9" "149.112.112.112" ];
        description = "Fallback DNS servers";
      };
    };

    # IPv6 configuration
    ipv6 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable IPv6 (disabled by default for privacy)";
      };
    };

    # WiFi configuration
    wifi = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable WiFi with wpa_supplicant";
      };

      networks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            pskRaw = lib.mkOption {
              type = lib.types.str;
              description = "PSK reference (e.g., ext:home_psk)";
            };
          };
        });
        default = {};
        description = "WiFi network configurations";
      };
    };

    # VPN configuration
    vpn = {
      openvpn = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable OpenVPN support";
        };

        servers = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {};
          description = "OpenVPN server configurations";
        };
      };
    };

    # Firewall configuration
    firewall = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable firewall";
      };

      allowedTCPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [];
        description = "Allowed TCP ports";
      };

      allowedUDPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [];
        description = "Allowed UDP ports";
      };
    };

    # Monitoring tools
    monitoring = {
      opensnitch = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable OpenSnitch application firewall";
      };
    };

    # Diagnostic tools
    diagnostics = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable network diagnostic tools (ethtool, iw)";
    };

    # /etc/hosts entries
    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      description = "Custom /etc/hosts entries";
    };

    # Extra packages
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional networking packages";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base networking
    {
      networking = {
        networkmanager.enable = cfg.networkManager;
        enableIPv6 = cfg.ipv6.enable;
        hosts = cfg.hosts;
      };

      environment.systemPackages = with pkgs; [
        nfs-utils
        ethtool
        iw
      ] ++ cfg.extraPackages;
    }

    # IPv6 disable
    (lib.mkIf (!cfg.ipv6.enable) {
      boot.kernel.sysctl = {
        "net.ipv6.conf.all.disable_ipv6" = 1;
        "net.ipv6.conf.default.disable_ipv6" = 1;
        "net.ipv6.conf.lo.disable_ipv6" = 1;
        "net.ipv6.conf.all.autoconf" = 0;
        "net.ipv6.conf.default.autoconf" = 0;
        "net.ipv6.conf.all.accept_ra" = 0;
        "net.ipv6.conf.default.accept_ra" = 0;
      };
    })

    # systemd-resolved
    (lib.mkIf cfg.dns.resolved {
      services.resolved = {
        enable = true;
        settings.Resolve = {
          DNSSEC = if cfg.dns.dnssec then "true" else "false";
          Domains = [ "~." ];
          FallbackDNS = cfg.dns.fallbackDns;
        };
      };
    })

    # WiFi
    (lib.mkIf cfg.wifi.enable {
      networking.wireless = {
        enable = true;
        userControlled.enable = true;
        networks = lib.mapAttrs (name: value: {
          pskRaw = value.pskRaw;
        }) cfg.wifi.networks;
      };
    })

    # OpenVPN
    (lib.mkIf cfg.vpn.openvpn.enable {
      environment.etc.openvpn.source = "${pkgs.update-resolv-conf}/libexec/openvpn";
      services.openvpn.servers = cfg.vpn.openvpn.servers;
    })

    # Firewall
    (lib.mkIf cfg.firewall.enable {
      networking.firewall = {
        enable = true;
        allowedTCPPorts = cfg.firewall.allowedTCPPorts;
        allowedUDPPorts = cfg.firewall.allowedUDPPorts;
      };
    })

    # OpenSnitch
    (lib.mkIf cfg.monitoring.opensnitch {
      services.opensnitch.enable = true;
      environment.systemPackages = [ pkgs-unstable.opensnitch-ui ];
    })

    # Network diagnostics
    (lib.mkIf cfg.diagnostics {
      environment.systemPackages = with pkgs; [
        ethtool
        iw
      ];
    })
  ]);
}
