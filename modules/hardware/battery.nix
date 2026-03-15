{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.hardware.battery;
  hibernateEnvironment = {
    HIBERNATE_SECONDS = toString cfg.hibernateAfterSeconds;
    HIBERNATE_LOCK = "/var/run/autohibernate.lock";
  };
in
{
  options.mymodules.hardware.battery = {
    enable = lib.mkEnableOption "Battery and power management (for laptops)";

    # TLP power management
    tlp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable TLP advanced power management";
      };

      # Battery charge thresholds
      chargeThresholds = {
        start = lib.mkOption {
          type = lib.types.int;
          default = 40;
          description = "Start charging when battery drops below this percentage";
        };

        stop = lib.mkOption {
          type = lib.types.int;
          default = 80;
          description = "Stop charging when battery reaches this percentage";
        };
      };
    };

    # Suspend/hibernate behavior
    suspend = {
      hibernateAfterSuspend = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Hibernate after suspend timeout (battery only)";
      };

      lidAction = lib.mkOption {
        type = lib.types.enum [ "suspend" "hibernate" "suspend-then-hibernate" "lock" "ignore" ];
        default = "suspend";
        description = "Action when lid is closed";
      };

      lidActionOnAC = lib.mkOption {
        type = lib.types.enum [ "suspend" "hibernate" "suspend-then-hibernate" "lock" "ignore" ];
        default = "ignore";
        description = "Action when lid is closed while on AC";
      };
    };

    hibernateAfterSeconds = lib.mkOption {
      type = lib.types.int;
      default = 1800;
      description = "Seconds after suspend to hibernate (30 min default)";
    };

    # Resume device for hibernation
    resumeDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Resume device for hibernation (e.g., /dev/nvme0n1p3)";
    };

    # AMD-specific settings
    amd = {
      pstate = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable AMD P-State driver";
      };
    };

    # Extra packages
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional power management packages";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base power management
    {
      powerManagement = {
        enable = true;
        powertop.enable = true;
        cpuFreqGovernor = "schedutil";
      };

      # Disable power-profiles-daemon (conflicts with TLP)
      services.power-profiles-daemon.enable = false;

      # Thermald for thermal management
      services.thermald.enable = true;

      # D-Bus broker (more efficient)
      services.dbus.implementation = "broker";

      environment.systemPackages = with pkgs; [
        brightnessctl
        btop
        powertop
        hypridle
        acpi
      ] ++ (lib.optionals cfg.tlp.enable [ tlp ]) ++ cfg.extraPackages;
    }

    # Kernel parameters
    {
      boot.kernelParams = [
        "pcie_aspm=force"
        "pcie_aspm.policy=powersupersave"
        "acpi_osi=Linux"
        "processor.max_cstate=5"
        "intel_idle.max_cstate=5"
        "ahci.mobile_lpm_policy=3"
      ] ++ (lib.optionals cfg.amd.pstate [ "amd_pstate=active" ])
        ++ (lib.optionals (cfg.resumeDevice != null) [ "resume=${cfg.resumeDevice}" ]);

      # Kernel sysctl optimizations
      boot.kernel.sysctl = {
        "vm.dirty_background_ratio" = 15;
        "vm.dirty_ratio" = 40;
        "vm.dirty_expire_centisecs" = 3000;
        "vm.dirty_writeback_centisecs" = 1500;
        "vm.laptop_mode" = 5;
        "vm.swappiness" = 10;
        "net.core.default_qdisc" = "fq_codel";
      };

      # Disable PC speaker
      boot.blacklistedKernelModules = [ "pcspkr" "snd_pcsp" ];
    }

    # TLP configuration
    (lib.mkIf cfg.tlp.enable {
      services.tlp = {
        enable = true;
        settings = {
          # CPU scaling
          CPU_SCALING_GOVERNOR_ON_AC = "performance";
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
          CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
          CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
          CPU_BOOST_ON_AC = 1;
          CPU_BOOST_ON_BAT = 0;
          CPU_HWP_DYN_BOOST_ON_AC = 1;
          CPU_HWP_DYN_BOOST_ON_BAT = 0;

          # Platform profiles
          PLATFORM_PROFILE_ON_AC = "performance";
          PLATFORM_PROFILE_ON_BAT = "low-power";

          # GPU power management
          RADEON_DPM_STATE_ON_AC = "performance";
          RADEON_DPM_STATE_ON_BAT = "battery";
          RADEON_POWER_PROFILE_ON_AC = "high";
          RADEON_POWER_PROFILE_ON_BAT = "low";

          # WiFi power saving
          WIFI_PWR_ON_AC = "off";
          WIFI_PWR_ON_BAT = "on";
          WOL_DISABLE = "Y";

          # USB autosuspend
          USB_AUTOSUSPEND = 1;
          USB_BLACKLIST_PRINTER = 1;

          # Battery thresholds
          START_CHARGE_THRESH_BAT0 = cfg.tlp.chargeThresholds.start;
          STOP_CHARGE_THRESH_BAT0 = cfg.tlp.chargeThresholds.stop;

          # Runtime PM
          RUNTIME_PM_ON_AC = "on";
          RUNTIME_PM_ON_BAT = "auto";
          RUNTIME_PM_ALL = 1;

          # SATA/PCIe power management
          SATA_LINKPWR_ON_AC = "med_power_with_dipm";
          SATA_LINKPWR_ON_BAT = "min_power";
          PCIE_ASPM_ON_AC = "performance";
          PCIE_ASPM_ON_BAT = "powersupersave";

          # Disk parameters
          DISK_APM_LEVEL_ON_AC = "254 254";
          DISK_APM_LEVEL_ON_BAT = "128 128";

          # Audio power saving
          SOUND_POWER_SAVE_ON_AC = 0;
          SOUND_POWER_SAVE_ON_BAT = 1;
          SOUND_POWER_SAVE_CONTROLLER = "Y";
        };
      };
    })

    # Logind/lid behavior
    {
      services.logind.settings.Login = {
        HandleLidSwitch = cfg.suspend.lidAction;
        HandleLidSwitchExternalPower = cfg.suspend.lidActionOnAC;
        HandlePowerKey = "suspend-then-hibernate";
        IdleAction = "suspend-then-hibernate";
        IdleActionSec = "20min";
      };
    }

    # Udev rules for power saving
    {
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="auto"
        ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
        ACTION=="add", SUBSYSTEM=="sound", ATTR{power/control}="auto"
        ACTION=="add", KERNEL=="card*", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power/control}="auto"
      '';
    }

    # NetworkManager WiFi power saving
    {
      networking.networkmanager.wifi = {
        scanRandMacAddress = false;
        powersave = true;
      };
    }

    # Hibernate after suspend
    (lib.mkIf cfg.suspend.hibernateAfterSuspend {
      systemd.services."awake-after-suspend-for-a-time" = {
        description = "Sets up suspend-then-hibernate on battery";
        wantedBy = [ "suspend.target" ];
        before = [ "systemd-suspend.service" ];
        environment = hibernateEnvironment;
        script = ''
          if [ -f /sys/class/power_supply/ACAD/online ] && [ $(cat /sys/class/power_supply/ACAD/online) -eq 0 ]; then
            curtime=$(date +%s)
            mkdir -p $(dirname $HIBERNATE_LOCK)
            echo "$curtime" > $HIBERNATE_LOCK
            ${pkgs.util-linux}/bin/rtcwake -m no -s $HIBERNATE_SECONDS
          fi
        '';
        serviceConfig.Type = "simple";
      };

      systemd.services."hibernate-after-recovery" = {
        description = "Hibernates after suspend recovery timeout";
        wantedBy = [ "suspend.target" ];
        after = [ "systemd-suspend.service" ];
        environment = hibernateEnvironment;
        script = ''
          curtime=$(date +%s)
          if [ -f "$HIBERNATE_LOCK" ]; then
            sustime=$(cat $HIBERNATE_LOCK)
            rm $HIBERNATE_LOCK
            if [ $(($curtime - $sustime)) -ge $HIBERNATE_SECONDS ]; then
              systemctl hibernate
            else
              ${pkgs.util-linux}/bin/rtcwake -m no -s 1
            fi
          fi
        '';
        serviceConfig.Type = "simple";
      };
    })

    # Systemd timer optimizations
    {
      systemd.timers.fstrim.timerConfig = {
        OnCalendar = "weekly";
        RandomizedDelaySec = "1h";
      };

      systemd.services.systemd-journald.serviceConfig = {
        SystemMaxUse = "50M";
        RuntimeMaxUse = "50M";
        SystemMaxFileSize = "10M";
      };
    }
  ]);
}
