{ lib, pkgs, config, ... }:

let
  myContainerIPs = {
    synapse = "172.42.0.40";
    mautrix-whatsapp = "172.42.0.50";
  };
in
{
  ## Create the data directory
  #systemd.tmpfiles.rules = [
  #  "d /var/containers-data/mautrix-whatsapp 0755 root root -"
  #];

  virtualisation.oci-containers.containers = {
    mautrix-whatsapp = {
      image = "dock.mau.dev/mautrix/whatsapp:latest";
      volumes = [
        "/var/containers-data/mautrix-whatsapp:/data"
      ];
      environment = {
        "MAUTRIX_WHATSAPP_ENCRYPTION_ALLOW" = "true";
        "MAUTRIX_WHATSAPP_ENCRYPTION_DEFAULT" = "true";
        "MAUTRIX_WHATSAPP_ENCRYPTION_REQUIRE" = "false";
        "MAUTRIX_WHATSAPP_ENCRYPTION_VERIFICATION_LEVELS_RECEIVE" = "unverified";
        "MAUTRIX_WHATSAPP_ENCRYPTION_VERIFICATION_LEVELS_SEND" = "unverified";
        "MAUTRIX_WHATSAPP_ENCRYPTION_VERIFICATION_LEVELS_SHARE" = "unverified";
      };
      extraOptions = [
        "--net" "custom-net"
        "--ip" "${myContainerIPs.mautrix-whatsapp}"
      ];
      dependsOn = [ "synapse" ];
    };
  };
}
