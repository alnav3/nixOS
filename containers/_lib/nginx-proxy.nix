{ lib }:

let
  defaults = import ./defaults.nix { inherit lib; };
in
{
  # Create an internal nginx proxy configuration
  mkInternalProxy = {
    domain,
    targetIP,
    targetPort,
    extraConfig ? "",
    extraLocations ? {},
    clientMaxBodySize ? null,
  }: {
    serverName = domain;
    listen = [{ addr = defaults.network.internalProxyIP; port = 80; }];
    
    locations = {
      "/" = {
        proxyPass = "http://${targetIP}:${toString targetPort}";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          ${if clientMaxBodySize != null then "client_max_body_size ${clientMaxBodySize};" else ""}
          ${extraConfig}
        '';
      };
    } // extraLocations;
  };

  # Create an external nginx proxy configuration with SSL
  mkExternalProxy = {
    domain,
    targetIP,
    targetPort,
    extraConfig ? "",
    extraLocations ? {},
    acmeHost ? "alnav.dev",
    clientMaxBodySize ? null,
  }: {
    forceSSL = true;
    useACMEHost = acmeHost;
    serverName = domain;
    listen = [
      { addr = defaults.network.externalProxyIP; port = 80; }
      { addr = defaults.network.externalProxyIP; port = 443; ssl = true; }
    ];
    
    locations = {
      "/" = {
        proxyPass = "http://${targetIP}:${toString targetPort}";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          ${if clientMaxBodySize != null then "client_max_body_size ${clientMaxBodySize};" else ""}
          ${extraConfig}
        '';
      };
    } // extraLocations;
  };

  # Standard proxy headers (for manual use)
  standardProxyHeaders = ''
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  '';

  # WebSocket support headers
  webSocketHeaders = ''
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  '';
}
