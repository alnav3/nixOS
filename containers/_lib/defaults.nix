{ lib }:

{
  # Network configuration
  network = {
    name = "custom-net";
    baseIP = "172.42.0";
    internalProxyIP = "10.71.71.75";
    externalProxyIP = "10.71.71.193";
  };

  # Default environment variables for containers
  environment = {
    PUID = "994";
    PGID = "104";
    TZ = "Etc/UTC";
  };

  # Common paths
  paths = {
    dataDir = "/var/containers-data";
    mediaDir = "/mnt/media";
    downloadsDir = "/mnt/things";
  };

  # Common ports for *arr services
  ports = {
    sonarr = 8989;
    radarr = 7878;
    prowlarr = 9696;
    bazarr = 6767;
    jellyseerr = 5055;
    transmission = 9091;
    deluge = 8112;
    calibre = 8083;
  };
}
