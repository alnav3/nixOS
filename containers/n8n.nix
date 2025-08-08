{lib, ...}:
let
  myContainerIPs = {
    n8n= "172.42.0.13";
  };
in
{
    networking.firewall.allowedTCPPorts = [5678];

    virtualisation.oci-containers.containers.n8n = {
        image = "docker.n8n.io/n8nio/n8n:1.83.2";
        environment = {
            N8N_HOST = myContainerIPs.n8n;
            N8N_PORT = "5678";
            N8N_PROTOCOL = "http";
            NODE_ENV = "production";
            #WEBHOOK_URL = "https://${config.environment.variables.N8N_HOST}/";
            GENERIC_TIMEZONE = "Europe/Berlin";
            N8N_SECURE_COOKIE = "false";
        };
        extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.n8n}" ];
        ports = [
            "5678:5678"
        ];
        volumes = [
            "n8n_data:/home/node/.n8n"
        ];
    };

    containers.nginx-internal.config.services.nginx.virtualHosts."n8n.home" = {
        serverName = "n8n.home";
        listen = [{ addr = "10.71.71.75"; port = 80; }];
        locations."/" = {
            proxyPass = "http://${myContainerIPs.n8n}:5678";
            extraConfig = ''
                proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            '';
        };
    };

}
