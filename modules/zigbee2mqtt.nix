{ config, pkgs, ... }:
{
  services.zigbee2mqtt = {
    enable = true;
    settings = {
      permit_join = true;  # Allows new devices to join initially
      homeassistant =  true;
      serial = {
        port = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_8265569d2b53ef11aa3822e0174bec31-if00-port0";
      };
      mqtt = {
        server = "mqtt://10.71.71.47:1883";
      };
      frontend = {
        enable = true;
        port = 42069;
        host = "0.0.0.0";
      };
    };
  };
}
