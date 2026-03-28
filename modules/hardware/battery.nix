{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.hardware.battery;
  # Build CPU frequency TLP attrs, only including non-null values
  cpuFreqAttrs = lib.filterAttrs (_: v: v != null) {
    CPU_SCALING_MIN_FREQ_ON_AC = cfg.tlp.cpuFreq.minOnAC;
    CPU_SCALING_MAX_FREQ_ON_AC = cfg.tlp.cpuFreq.maxOnAC;
    CPU_SCALING_MIN_FREQ_ON_BAT = cfg.tlp.cpuFreq.minOnBAT;
    CPU_SCALING_MAX_FREQ_ON_BAT = cfg.tlp.cpuFreq.maxOnBAT;
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

      # CPU frequency limits (critical for battery life)
      cpuFreq = {
        minOnAC = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Minimum CPU frequency on AC power (kHz). null = TLP auto";
        };

        maxOnAC = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Maximum CPU frequency on AC power (kHz). null = TLP auto";
        };

        minOnBAT = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Minimum CPU frequency on battery (kHz). null = TLP auto";
        };

        maxOnBAT = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Maximum CPU frequency on battery (kHz). Strongly recommended to set this.";
        };
      };
    };

    # Suspend/hibernate behavior
    suspend = {
      lidAction = lib.mkOption {
        type = lib.types.enum [ "suspend" "hibernate" "suspend-then-hibernate" "lock" "ignore" ];
        default = "lock";
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
      description = "Seconds after suspend to hibernate (used by systemd suspend-then-hibernate)";
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

      # Thermald is Intel-only; skip on AMD where it wastes resources
      services.thermald.enable = !cfg.amd.pstate;

      # D-Bus broker (more efficient than dbus-daemon)
      services.dbus.implementation = "broker";

      # Suspend-then-hibernate: hibernate after this delay
      systemd.sleep.settings.Sleep.HibernateDelaySec = "${toString cfg.hibernateAfterSeconds}s";

      environment.systemPackages = with pkgs; [
        brightnessctl
        btop
        powertop
        hypridle
        acpi
      ] ++ (lib.optionals cfg.tlp.enable [ tlp ])
        ++ (lib.optionals cfg.amd.pstate [ ryzenadj ])
        ++ cfg.extraPackages;
    }

    # Kernel parameters for power saving
    {
      boot.kernelParams = [
        "pcie_aspm=force"
        "pcie_aspm.policy=powersupersave"
        "acpi_osi=Linux"
        "processor.max_cstate=5"
        "intel_idle.max_cstate=5"
        "ahci.mobile_lpm_policy=3"
        # Disable watchdog timers - they cause periodic CPU wakeups that waste power
        "nowatchdog"
        "nmi_watchdog=0"
        # Audio codec power save (auto-suspend after 1 second of silence)
        "snd_hda_intel.power_save=1"
      ] ++ (lib.optionals cfg.amd.pstate [ "amd_pstate=active" ])
        ++ (lib.optionals (cfg.resumeDevice != null) [ "resume=${cfg.resumeDevice}" ]);

      # Kernel sysctl optimizations for power
      boot.kernel.sysctl = {
        # Delay writes to disk - reduces disk wakeups on battery
        "vm.dirty_background_ratio" = 15;
        "vm.dirty_ratio" = 40;
        "vm.dirty_expire_centisecs" = 3000;
        "vm.dirty_writeback_centisecs" = 1500;
        "vm.laptop_mode" = 5;
        "vm.swappiness" = 10;
        # Better network queue discipline
        "net.core.default_qdisc" = "fq_codel";
        # Disable NMI watchdog via sysctl as well (belt and suspenders with kernel param)
        "kernel.nmi_watchdog" = 0;
      };

      # Disable unnecessary kernel modules
      boot.blacklistedKernelModules = [ "pcspkr" "snd_pcsp" ];
    }

    # TLP configuration
    (lib.mkIf cfg.tlp.enable {
      services.tlp = {
        enable = true;
        settings = {
          # CPU scaling governor
          CPU_SCALING_GOVERNOR_ON_AC = "performance";
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

          # CPU energy performance preference
          CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
          CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

          # CPU boost control - disable on battery to prevent power spikes
          CPU_BOOST_ON_AC = 1;
          CPU_BOOST_ON_BAT = 0;
          CPU_HWP_DYN_BOOST_ON_AC = 1;
          CPU_HWP_DYN_BOOST_ON_BAT = 0;

          # Platform profiles
          PLATFORM_PROFILE_ON_AC = "performance";
          PLATFORM_PROFILE_ON_BAT = "low-power";

          # GPU power management (Radeon/AMDGPU)
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
          USB_BLACKLIST_BTUSB = 0;
          USB_BLACKLIST_PHONE = 0;
          USB_BLACKLIST_PRINTER = 1;
          USB_BLACKLIST_WWAN = 0;

          # Battery charge thresholds
          START_CHARGE_THRESH_BAT0 = cfg.tlp.chargeThresholds.start;
          STOP_CHARGE_THRESH_BAT0 = cfg.tlp.chargeThresholds.stop;

          # Runtime power management for PCI/USB devices
          RUNTIME_PM_ON_AC = "on";
          RUNTIME_PM_ON_BAT = "auto";
          RUNTIME_PM_ALL = 1;

          # SATA link power management
          SATA_LINKPWR_ON_AC = "med_power_with_dipm";
          SATA_LINKPWR_ON_BAT = "min_power";

          # PCIe ASPM
          PCIE_ASPM_ON_AC = "performance";
          PCIE_ASPM_ON_BAT = "powersupersave";

          # Disk power management
          DISK_APM_LEVEL_ON_AC = "254 254";
          DISK_APM_LEVEL_ON_BAT = "128 128";
          DISK_SPINDOWN_TIMEOUT_ON_AC = "0 0";
          DISK_SPINDOWN_TIMEOUT_ON_BAT = "24 24";
          DISK_IOSCHED = "mq-deadline mq-deadline";

          # Audio power saving
          SOUND_POWER_SAVE_ON_AC = 0;
          SOUND_POWER_SAVE_ON_BAT = 1;
          SOUND_POWER_SAVE_CONTROLLER = "Y";
        } // cpuFreqAttrs;
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

      # Listen for systemd-logind Lock signal and call noctalia-shell to lock
      systemd.user.services.logind-lock-handler = {
        description = "Lock screen via noctalia-shell on systemd Lock signal";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = 3;
          ExecStart = pkgs.writeShellScript "logind-lock-handler" ''
            session_path="/org/freedesktop/login1/session/''${XDG_SESSION_ID:-auto}"
            ${pkgs.glib}/bin/gdbus monitor --system \
              --dest org.freedesktop.login1 \
              --object-path "$session_path" |
            while read -r line; do
              case "$line" in
                *"Lock ()"*)
                  noctalia-shell ipc call lockScreen lock
                  ;;
              esac
            done
          '';
        };
      };
    }

    # Udev rules for power saving
    {
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="auto"
        ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
        ACTION=="add", SUBSYSTEM=="sound", ATTR{power/control}="auto"
        ACTION=="add", KERNEL=="card*", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power/control}="auto"
        ACTION=="add", SUBSYSTEM=="net", KERNEL=="wl*", RUN+="${pkgs.iw}/bin/iw dev %k set power_save on"
      '';
    }

    # NetworkManager WiFi power saving
    {
      networking.networkmanager.wifi = {
        scanRandMacAddress = false;
        powersave = true;
      };
    }

    # Systemd service & timer optimizations
    {
      # Weekly TRIM with jitter to avoid thundering herd
      systemd.timers.fstrim.timerConfig = {
        OnCalendar = "weekly";
        RandomizedDelaySec = "1h";
      };

      # Limit journal size to reduce disk writes
      systemd.services.systemd-journald.serviceConfig = {
        SystemMaxUse = "50M";
        RuntimeMaxUse = "50M";
        SystemMaxFileSize = "10M";
      };

      # Reduce NTP polling frequency to save power (fewer network wakeups)
      services.timesyncd.extraConfig = ''
        PollIntervalMinSec=300
        PollIntervalMaxSec=3600
      '';
    }
  ]);
}
