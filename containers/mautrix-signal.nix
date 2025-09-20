{ lib, pkgs, config, ... }:

let
  myContainerIPs = {
    synapse = "172.42.0.40";
    mautrix-signal= "172.42.0.52";
  };
in
{
  virtualisation.oci-containers.containers = {
    mautrix-signal = {
      image = "dock.mau.dev/mautrix/signal:latest";
      volumes = [
        "/var/containers-data/mautrix-signal:/data"
      ];
      extraOptions = [
        "--net" "custom-net"
        "--ip" "${myContainerIPs.mautrix-signal}"
      ];
      dependsOn = [ "synapse" ];
    };
  };
}

