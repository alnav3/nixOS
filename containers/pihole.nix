{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.pihole;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.pihole = {
    enable = lib.mkEnableOption "Pi-hole DNS ad blocker";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 14;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 80;
      description = "Internal HTTP port for Pi-hole";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "pihole.home";
        description = "Internal domain name";
      };
      
      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "External domain name (enables external access)";
      };
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/pihole";
      description = "Directory for Pi-hole data";
    };
    
    timezone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/London";
      description = "Timezone for Pi-hole";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.oci-containers.containers.pihole = {
        image = "pihole/pihole:latest";
        environment = {
          TZ = cfg.timezone;
          FTLCONF_dns_listeningMode = "ALL";
        } // cfg.environment;
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
          "--cap-add=NET_ADMIN"
        ];
        volumes = [
          "${cfg.dataDir}/etc-pihole:/etc/pihole"
          "${cfg.dataDir}/etc-dnsmasq.d:/etc/dnsmasq.d"
        ];
        ports = [
          "53:53/tcp"
          "53:53/udp"
        ];
      };
    }
    
    # Internal nginx proxy
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = containerIP;
          targetPort = cfg.port;
        };
    })
    
    # External nginx proxy
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" = 
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = containerIP;
          targetPort = cfg.port;
        };
    })
  ]);
}
