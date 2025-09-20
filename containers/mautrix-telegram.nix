{ lib, pkgs, config, ... }:

let
  myContainerIPs = {
    synapse = "172.42.0.40";
    mautrix-telegram = "172.42.0.51";
  };
in
{
  virtualisation.oci-containers.containers = {
    mautrix-telegram = {
      image = "dock.mau.dev/mautrix/telegram:latest";
      volumes = [
        "/var/containers-data/mautrix-telegram:/data"
      ];
      extraOptions = [
        "--net" "custom-net"
        "--ip" "${myContainerIPs.mautrix-telegram}"
      ];
      dependsOn = [ "synapse" ];
    };
  };
}
