{ lib, ... }:
let
  myContainerIPs = {
    transmission = "172.42.0.11";
  };
in
{
  virtualisation.oci-containers.containers = {
    transmission = {
      image = "lscr.io/linuxserver/transmission:latest";
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Etc/UTC";
      };
      extraOptions = [ "--net" "my-custom-net" "--ip" "${myContainerIPs.transmission}" ];
      volumes = [
        "/home/alnav/transmission/config:/config"
        "/home/alnav/transmission/downloads:/downloads"
        "/home/alnav/transmission/watch:/watch"
      ];
      ports = [ "51413:51413/tcp" "51413:51413/udp" ];
    };
  };

  # Join the list with newlines to create a single string
  networking.extraHosts = lib.concatStrings (
    lib.mapAttrsToList (ip: name: "${name} ${ip}\n") myContainerIPs
  );
}

