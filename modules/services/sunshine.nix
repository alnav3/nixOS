{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.services.sunshine;
  mlib = import ../_lib { inherit lib; };
in
{
  options.mymodules.services.sunshine = {
    enable = lib.mkEnableOption "Sunshine game streaming server";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Sunshine ports in the firewall (TCP 47984-47990, UDP 47998-48010)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      openFirewall = cfg.openFirewall;
    };
  };
}
