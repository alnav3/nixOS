{ lib, pkgs, ... }:

let
  myContainerIPs = {
    windmill-db = "172.42.0.30";
    windmill-server = "172.42.0.31";
    windmill-worker = "172.42.0.32";
    windmill-worker-native = "172.42.0.33";
    windmill-lsp = "172.42.0.34";
    windmill-indexer = "172.42.0.35";
  };

  # Environment variables for configuration
  databaseUrl = "postgres://postgres:changeme@${myContainerIPs.windmill-db}:5432/windmill";
  wmImage = "ghcr.io/windmill-labs/windmill:main";
  subdomain = "windmill";
  domainName = "home";
  genericTimezone = "Etc/UTC";
in
{
  # Create directories with proper permissions
  systemd.tmpfiles.rules = [
    "d /var/containers-data/windmill-db 0755 999 999 -"
    "d /var/containers-data/windmill-worker-dependency-cache 0755 1000 1000 -"
    "d /var/containers-data/windmill-worker-logs 0755 1000 1000 -"
    "d /var/containers-data/windmill-index 0755 1000 1000 -"
    "d /var/containers-data/windmill-lsp-cache 0755 1000 1000 -"
  ];

  virtualisation.oci-containers.containers = {
    # PostgreSQL database for Windmill (matches official compose)
    windmill-db = {
      image = "postgres:16";
      environment = {
        POSTGRES_PASSWORD = "changeme";
        POSTGRES_DB = "windmill";
      };
      extraOptions = [ 
        "--net" "custom-net" 
        "--ip" "${myContainerIPs.windmill-db}"
        "--shm-size" "1g"
      ];
      volumes = [
        "/var/containers-data/windmill-db:/var/lib/postgresql/data"
      ];
      ports = [ ];
    };

    # Windmill Server
    windmill-server = {
      image = wmImage;
      environment = {
        DATABASE_URL = databaseUrl;
        MODE = "server";
      };
      extraOptions = [ 
        "--net" "custom-net" 
        "--ip" "${myContainerIPs.windmill-server}"
      ];
      volumes = [
        "/var/containers-data/windmill-worker-logs:/tmp/windmill/logs"
      ];
      ports = [ ];
      dependsOn = [ "windmill-db" ];
    };

    # Windmill Default Workers (3 replicas equivalent)
    windmill-worker-1 = {
      image = wmImage;
      environment = {
        DATABASE_URL = databaseUrl;
        MODE = "worker";
        WORKER_GROUP = "default";
      };
      extraOptions = [ 
        "--net" "custom-net" 
      ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "/var/containers-data/windmill-worker-dependency-cache:/tmp/windmill/cache"
        "/var/containers-data/windmill-worker-logs:/tmp/windmill/logs"
      ];
      ports = [ ];
      dependsOn = [ "windmill-db" ];
    };

    windmill-worker-2 = {
      image = wmImage;
      environment = {
        DATABASE_URL = databaseUrl;
        MODE = "worker";
        WORKER_GROUP = "default";
      };
      extraOptions = [ 
        "--net" "custom-net" 
      ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "/var/containers-data/windmill-worker-dependency-cache:/tmp/windmill/cache"
        "/var/containers-data/windmill-worker-logs:/tmp/windmill/logs"
      ];
      ports = [ ];
      dependsOn = [ "windmill-db" ];
    };

    windmill-worker-3 = {
      image = wmImage;
      environment = {
        DATABASE_URL = databaseUrl;
        MODE = "worker";
        WORKER_GROUP = "default";
      };
      extraOptions = [ 
        "--net" "custom-net" 
      ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "/var/containers-data/windmill-worker-dependency-cache:/tmp/windmill/cache"
        "/var/containers-data/windmill-worker-logs:/tmp/windmill/logs"
      ];
      ports = [ ];
      dependsOn = [ "windmill-db" ];
    };

    # Native Worker (specialized for lightweight jobs)
    windmill-worker-native = {
      image = wmImage;
      environment = {
        DATABASE_URL = databaseUrl;
        MODE = "worker";
        WORKER_GROUP = "native";
        NUM_WORKERS = "8";
        SLEEP_QUEUE = "200";
      };
      extraOptions = [ 
        "--net" "custom-net" 
        "--ip" "${myContainerIPs.windmill-worker-native}"
      ];
      volumes = [
        "/var/containers-data/windmill-worker-logs:/tmp/windmill/logs"
      ];
      ports = [ ];
      dependsOn = [ "windmill-db" ];
    };

    # Language Server Protocol (LSP) for code completion
    windmill-lsp = {
      image = "ghcr.io/windmill-labs/windmill-lsp:latest";
      extraOptions = [ 
        "--net" "custom-net" 
        "--ip" "${myContainerIPs.windmill-lsp}"
      ];
      volumes = [
        "/var/containers-data/windmill-lsp-cache:/pyls/.cache"
      ];
      ports = [ ];
    };

    # Indexer for full-text search (disabled by default - set replicas to 1 to enable)
    # windmill-indexer = {
    #   image = wmImage;
    #   environment = {
    #     PORT = "8002";
    #     DATABASE_URL = databaseUrl;
    #     MODE = "indexer";
    #   };
    #   extraOptions = [
    #     "--net" "custom-net"
    #     "--ip" "${myContainerIPs.windmill-indexer}"
    #     "--restart" "unless-stopped"
    #   ];
    #   volumes = [
    #     "/var/containers-data/windmill-index:/tmp/windmill/search"
    #     "/var/containers-data/windmill-worker-logs:/tmp/windmill/logs"
    #   ];
    #   ports = [ ];
    #   dependsOn = [ "windmill-db" ];
    # };
  };

  # Nginx reverse proxy configuration for Windmill
  containers.nginx-internal.config.services.nginx.virtualHosts."windmill.home" = {
    serverName = "windmill.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations = {
      "/" = {
        proxyPass = "http://${myContainerIPs.windmill-server}:8000";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_buffering off;
        '';
      };

      # Proxy LSP requests to the LSP service
      "/api/lsp/" = {
        proxyPass = "http://${myContainerIPs.windmill-lsp}:3001/";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
