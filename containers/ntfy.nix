{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.ntfy;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.ntfy = {
    enable = lib.mkEnableOption "Ntfy notification service";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 38;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 80;
      description = "Internal port for Ntfy";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Internal domain name";
      };
      
      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "ntfy.alnav.dev";
        description = "External domain name (enables external access)";
      };
    };
    
    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://ntfy.alnav.dev";
      description = "Base URL for ntfy service";
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/ntfy";
      description = "Directory for Ntfy data";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.oci-containers.containers.ntfy = {
        image = "binwiederhier/ntfy:latest";
        cmd = [ "serve" ];
        environment = clib.helpers.mkEnv ({
          PUID = "1000";
          PGID = "1000";
        } // cfg.environment);
        volumes = [
          "${cfg.dataDir}/cache:/var/cache/ntfy"
          "${cfg.dataDir}/etc:/etc/ntfy"
        ];
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
        ];
      };
      
      # Create data directories
      systemd.tmpfiles.rules = clib.helpers.mkDataDirs [
        "ntfy"
        "ntfy/cache"
        "ntfy/etc"
      ];
      
      # Create basic ntfy config
      environment.etc."ntfy/server.yml".text = ''
        base-url: "${cfg.baseUrl}"
        listen: ":${toString cfg.port}"
        cache-file: "/var/cache/ntfy/cache.db"
        auth-default-access: "read-write"
        auth-file: "/var/cache/ntfy/user.db"
        behind-proxy: true
      '';
    }
    
    # Internal nginx proxy
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = containerIP;
          targetPort = cfg.port;
          extraConfig = clib.nginx.webSocketHeaders;
        };
    })
    
    # External nginx proxy with WebSocket support
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" = 
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = containerIP;
          targetPort = cfg.port;
          extraConfig = clib.nginx.webSocketHeaders;
        };
    })
  ]);
}
