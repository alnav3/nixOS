{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.hardware.bluetooth;
in
{
  options.mymodules.hardware.bluetooth = {
    enable = lib.mkEnableOption "Bluetooth support";

    # Power management options
    powerManagement = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable smart Bluetooth power management (battery-aware)";
      };

      disableOnBattery = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically disable Bluetooth when on battery (if no devices connected)";
      };
    };

    # Audio features
    audio = {
      mprisProxy = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable MPRIS proxy for Bluetooth headset controls";
      };

      highQuality = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable high quality audio codecs";
      };
    };

    # UI tools
    ui = {
      blueman = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Blueman GTK Bluetooth manager";
      };

      rofiBluetooth = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable rofi-bluetooth for quick access";
      };
    };

    # Extra packages
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional Bluetooth packages";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base Bluetooth configuration
    {
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = !cfg.powerManagement.enable;
        settings = {
          General = {
            Enable = "Source,Sink,Media,Socket";
          } // (lib.optionalAttrs cfg.powerManagement.enable {
            Experimental = true;
            FastConnectable = false;
            DiscoverableTimeout = 0;
          });
        };
      };

      environment.systemPackages = with pkgs; [
        bluez
        bluez-tools
      ] ++ cfg.extraPackages;
    }

    # Blueman UI
    (lib.mkIf cfg.ui.blueman {
      services.blueman.enable = true;
    })

    # Rofi Bluetooth
    (lib.mkIf cfg.ui.rofiBluetooth {
      environment.systemPackages = [ pkgs.rofi-bluetooth ];
    })

    # Audio packages
    (lib.mkIf cfg.audio.highQuality {
      environment.systemPackages = with pkgs; [
        alsa-utils
        pavucontrol
        easyeffects
      ];
    })

    # MPRIS proxy for headset controls
    (lib.mkIf cfg.audio.mprisProxy {
      systemd.user.services.mpris-proxy = {
        description = "Mpris proxy";
        after = [ "network.target" "sound.target" ];
        wantedBy = [ "default.target" ];
        serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
      };
    })

    # Smart power management
    (lib.mkIf cfg.powerManagement.enable {
      # Udev rules for AC/battery changes
      services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl start smart-bluetooth.service"
        SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start smart-bluetooth.service"
        SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl start smart-bluetooth.service"
        SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start smart-bluetooth.service"
      '';

      # Smart Bluetooth power management service
      systemd.services.smart-bluetooth = {
        description = "Smart Bluetooth Power Management - AC/Battery aware";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = false;
          User = "root";
        };
        script = ''
          #!/bin/bash
          set -e

          check_power_source() {
            if [ -f /sys/class/power_supply/ACAD/online ]; then
              cat /sys/class/power_supply/ACAD/online
            else
              find /sys/class/power_supply -name "A*" -type d -exec cat {}/online \; 2>/dev/null | head -1 || echo "0"
            fi
          }

          count_connected_devices() {
            ${pkgs.bluez}/bin/bluetoothctl devices Connected 2>/dev/null | wc -l
          }

          enable_bluetooth() {
            ${pkgs.systemd}/bin/systemctl start bluetooth.service 2>/dev/null || true
            sleep 2
            ${pkgs.bluez}/bin/bluetoothctl power on 2>/dev/null || true
          }

          disable_bluetooth() {
            ${pkgs.bluez}/bin/bluetoothctl power off 2>/dev/null || true
          }

          power_source=$(check_power_source)

          if [ "$power_source" = "1" ]; then
            enable_bluetooth
          else
            ${pkgs.systemd}/bin/systemctl start bluetooth.service 2>/dev/null || true
            sleep 3
            connected_devices=$(count_connected_devices)
            if [ "$connected_devices" -eq 0 ]; then
              disable_bluetooth
            fi
          fi
        '';
        path = with pkgs; [ bash bluez systemd coreutils findutils ];
      };

      # Periodic check timer
      systemd.timers.bluetooth-power-check = {
        description = "Timer for Bluetooth Power Optimization";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "10min";
          OnUnitActiveSec = "5min";
          Unit = "bluetooth-power-check.service";
        };
      };

      systemd.services.bluetooth-power-check = {
        description = "Periodic Bluetooth Power Optimization Check";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        script = ''
          ${pkgs.systemd}/bin/systemctl start smart-bluetooth.service
        '';
      };
    })
  ]);
}
