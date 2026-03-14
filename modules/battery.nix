{
  pkgs,
  ...
}: let
  hibernateEnvironment = {
    HIBERNATE_SECONDS = "1800";
    HIBERNATE_LOCK = "/var/run/autohibernate.lock";
  };
in {
  # Enhanced kernel parameters for maximum power saving
  boot.kernelParams = [ 
    "amd_pstate=active"          # Use active P-state driver for better power management
    "pcie_aspm=force"            # Force PCIe Active State Power Management 
    "pcie_aspm.policy=powersupersave"  # Most aggressive PCIe power saving
    "i915.enable_rc6=1"          # Enable Intel GPU render context 6 deep sleep (if applicable)
    "i915.enable_fbc=1"          # Frame buffer compression
    "i915.lvds_downclock=1"      # LVDS downclocking
    "acpi_osi=Linux"             # Better ACPI support
    "processor.max_cstate=5"     # Allow deeper CPU sleep states
    "intel_idle.max_cstate=5"    # Allow deeper idle states
    "ahci.mobile_lpm_policy=3"   # SATA link power management
    "resume=/dev/nvme0n1p3"      # Resume device for hibernation
  ];

  # TLP - Advanced power management
  services.tlp = {
    enable = true;
    settings = {
      # CPU scaling governor and frequencies
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      
      # CPU energy performance preferences (EPP)
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      
      # CPU boost on AC/battery
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      
      # CPU HWP dynamic boost
      CPU_HWP_DYN_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;
      
      # AMD P-State EPP
      CPU_SCALING_MIN_FREQ_ON_AC = 1000000;
      CPU_SCALING_MAX_FREQ_ON_AC = 4972000;
      CPU_SCALING_MIN_FREQ_ON_BAT = 400000;
      CPU_SCALING_MAX_FREQ_ON_BAT = 2000000;
      
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
      
      # Disable Wake on LAN
      WOL_DISABLE = "Y";
      
      # USB autosuspend
      USB_AUTOSUSPEND = 1;
      USB_BLACKLIST_BTUSB = 0;
      USB_BLACKLIST_PHONE = 0;
      USB_BLACKLIST_PRINTER = 1;
      USB_BLACKLIST_WWAN = 0;
      
      # ThinkPad battery thresholds (may work on Framework)
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
      
      # Runtime PM for PCI devices
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";
      
      # Runtime PM for all devices
      RUNTIME_PM_ALL = 1;
      
      # SATA link power management
      SATA_LINKPWR_ON_AC = "med_power_with_dipm";
      SATA_LINKPWR_ON_BAT = "min_power";
      
      # PCIe ASPM
      PCIE_ASPM_ON_AC = "performance";
      PCIE_ASPM_ON_BAT = "powersupersave";
      
      # Disk parameters
      DISK_APM_LEVEL_ON_AC = "254 254";
      DISK_APM_LEVEL_ON_BAT = "128 128";
      DISK_SPINDOWN_TIMEOUT_ON_AC = "0 0";
      DISK_SPINDOWN_TIMEOUT_ON_BAT = "24 24";
      DISK_IOSCHED = "mq-deadline mq-deadline";
      
      # Audio power saving
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";
    };
  };
  systemd.services."awake-after-suspend-for-a-time" = {
    description = "Sets up the suspend so that it'll wake for hibernation only if not on AC power";
    wantedBy = ["suspend.target"];
    before = ["systemd-suspend.service"];
    environment = hibernateEnvironment;
    script = ''
      if [ $(cat /sys/class/power_supply/ACAD/online) -eq 0 ]; then
        curtime=$(date +%s)
        echo "$(date): Battery power detected, scheduling hibernation in $HIBERNATE_SECONDS seconds" >> /tmp/autohibernate.log
        
        # Ensure lock file directory exists
        mkdir -p $(dirname $HIBERNATE_LOCK)
        echo "$curtime" > $HIBERNATE_LOCK
        
        # Schedule wake-up for hibernation check
        ${pkgs.util-linux}/bin/rtcwake -m no -s $HIBERNATE_SECONDS
        echo "$(date): RTC wake scheduled for hibernation check" >> /tmp/autohibernate.log
      else
        echo "$(date): System is on AC power, skipping wake-up scheduling for hibernation." >> /tmp/autohibernate.log
      fi
    '';
    serviceConfig.Type = "simple";
  };

  systemd.services."hibernate-after-recovery" = {
    description = "Hibernates after a suspend recovery due to timeout";
    wantedBy = ["suspend.target"];
    after = ["systemd-suspend.service"];
    environment = hibernateEnvironment;
    script = ''
      curtime=$(date +%s)
      
      # Check if hibernate lock file exists
      if [ -f "$HIBERNATE_LOCK" ]; then
        sustime=$(cat $HIBERNATE_LOCK)
        rm $HIBERNATE_LOCK
        
        # Check if enough time has passed for hibernation
        if [ $(($curtime - $sustime)) -ge $HIBERNATE_SECONDS ] ; then
          echo "$(date): Hibernate timeout reached, hibernating system" >> /tmp/autohibernate.log
          systemctl hibernate
        else
          echo "$(date): Not enough time passed, scheduling another check" >> /tmp/autohibernate.log
          ${pkgs.util-linux}/bin/rtcwake -m no -s 1
        fi
      else
        echo "$(date): No hibernate lock file found, system likely woke up due to user activity" >> /tmp/autohibernate.log
        # Check if we're still on battery and no active connections
        if [ $(cat /sys/class/power_supply/ACAD/online) -eq 0 ]; then
          echo "$(date): Still on battery power, but no auto-hibernate scheduled" >> /tmp/autohibernate.log
        fi
      fi
    '';
    serviceConfig.Type = "simple";
  };

  # Disable power-profiles-daemon as it conflicts with TLP
  services.power-profiles-daemon.enable = false;
  
  # Additional power optimizations
  powerManagement = {
    enable = true;
    powertop.enable = true;
    cpuFreqGovernor = "schedutil"; # Good balance between performance and power
  };

  # Enable USB autosuspend for all devices by default + Smart Bluetooth triggers
  services.udev.extraRules = ''
    # USB autosuspend
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
    
    # Enable ASPM for all PCIe devices
    ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
    
    # Aggressive power management for network devices
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="wl*", RUN+="${pkgs.iw}/bin/iw dev %k set power_save on"
    
    # Audio device power management
    ACTION=="add", SUBSYSTEM=="sound", ATTR{power/control}="auto"
    
    # Enable runtime PM for AMD GPU
    ACTION=="add", KERNEL=="card*", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power/control}="auto"
    
    # Smart Bluetooth management on power source changes
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl start smart-bluetooth.service"
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start smart-bluetooth.service"
    
    # Additional trigger for AC adapter changes
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl start smart-bluetooth.service" 
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl start smart-bluetooth.service"
  '';

  # Enable thermald for better thermal management
  services.thermald.enable = true;
  
  # Additional system optimizations
  boot.kernel.sysctl = {
    # VM and memory optimizations for power saving
    "vm.dirty_background_ratio" = 15;
    "vm.dirty_ratio" = 40;
    "vm.dirty_expire_centisecs" = 3000;
    "vm.dirty_writeback_centisecs" = 1500;
    "vm.laptop_mode" = 5;
    "vm.swappiness" = 10;
    
    # Network power optimizations
    "net.core.default_qdisc" = "fq_codel";
  };

  # Graphics and display power optimizations
  environment.sessionVariables = {
    # AMD GPU power saving
    "AMD_VULKAN_ICD" = "RADV";
    "RADV_PERFTEST" = "sam,rt,gpl";
    "AMD_DEBUG" = "nohyperz";
    
    # Force applications to use less power
    "MESA_GL_VERSION_OVERRIDE" = "4.6";
    "MESA_GLSL_VERSION_OVERRIDE" = "460";
    
    # Wayland optimizations for power saving
    "WLR_NO_HARDWARE_CURSORS" = "1";
    "WLR_RENDERER_ALLOW_SOFTWARE" = "1";
  };

  # Configure hardware graphics for power saving
  hardware.amdgpu = {
    opencl.enable = false; # Disable if not needed
  };

  # Additional display and compositor optimizations
  # Note: Hyprland power optimizations should be configured in user dotfiles
  # to avoid conflicts with the main desktop configuration

  # Service optimizations for battery life
  systemd.services = {
    # Reduce systemd journal size and frequency
    systemd-journald.serviceConfig = {
      SystemMaxUse = "50M";
      RuntimeMaxUse = "50M";
      SystemMaxFileSize = "10M";
    };
    
    # Network time sync less frequently
    systemd-timesyncd.serviceConfig = {
      PollIntervalMinSec = "300";
      PollIntervalMaxSec = "3600";
    };
  };

  # Optimize systemd timers for battery
  systemd.timers.fstrim.timerConfig = {
    OnCalendar = "weekly";
    RandomizedDelaySec = "1h";
  };

  # Disable unnecessary hardware when on battery
  services.logind = {
    lidSwitch = "suspend-then-hibernate";
    lidSwitchExternalPower = "lock";
    settings.Login = {
      HandlePowerKey = "suspend-then-hibernate";
      IdleAction = "suspend-then-hibernate";
      IdleActionSec = "20min";
    };
  };

  # Optimize Docker for power (if you need it running)
  virtualisation.docker = {
    autoPrune = {
      enable = true;
      dates = "daily";
    };
    daemon.settings = {
      experimental = true;
      live-restore = false; # Reduce overhead
    };
  };

  # Disable unnecessary kernel modules for power saving
  boot.blacklistedKernelModules = [
    "pcspkr"      # PC speaker
    "snd_pcsp"    # PC speaker sound
  ];

  # TLP hooks for enhanced Bluetooth management
  environment.etc."tlp.d/01-bluetooth-management".text = ''
    # Smart Bluetooth management hooks for TLP
    
    # Function to check connected Bluetooth devices
    check_bt_connections() {
        ${pkgs.bluez}/bin/bluetoothctl devices Connected 2>/dev/null | wc -l
    }
    
    # Hook when switching to AC power
    tlp_ac_func() {
        echo "TLP Hook: AC power detected - enabling Bluetooth..." | ${pkgs.systemd}/bin/systemd-cat -t tlp-bluetooth
        ${pkgs.systemd}/bin/systemctl start bluetooth.service 2>/dev/null || true
        sleep 2
        ${pkgs.bluez}/bin/bluetoothctl power on 2>/dev/null || true
    }
    
    # Hook when switching to battery power
    tlp_bat_func() {
        echo "TLP Hook: Battery power detected - checking Bluetooth connections..." | ${pkgs.systemd}/bin/systemd-cat -t tlp-bluetooth
        
        # Small delay to ensure services are ready
        sleep 3
        
        # Check for active connections
        connected=$(check_bt_connections)
        
        if [ "$connected" -eq 0 ]; then
            echo "TLP Hook: No devices connected - disabling Bluetooth for power saving" | ${pkgs.systemd}/bin/systemd-cat -t tlp-bluetooth  
            ${pkgs.bluez}/bin/bluetoothctl power off 2>/dev/null || true
        else
            echo "TLP Hook: $connected device(s) connected - keeping Bluetooth enabled" | ${pkgs.systemd}/bin/systemd-cat -t tlp-bluetooth
        fi
    }
    
    # Register hooks
    case "$1" in
        ac)   tlp_ac_func ;;
        bat)  tlp_bat_func ;;
    esac
  '';

  # Additional power-saving optimizations
  services.dbus.implementation = "broker"; # More efficient D-Bus
  
  # Reduce network manager scanning
  networking.networkmanager.wifi = {
    scanRandMacAddress = false; # Reduces power
    powersave = true;
  };

  # Smart Bluetooth power management - auto enable/disable with AC/battery
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # Don't auto-enable on boot
    settings.General = {
      Experimental = true;
      FastConnectable = false;
      DiscoverableTimeout = 0; # Never discoverable unless explicitly set
    };
  };

  # Add required packages for Bluetooth management  
  environment.systemPackages = with pkgs; [
    brightnessctl
    ryzenadj
    btop
    powertop
    hypridle
    tlp
    acpi
    bluez
    bluez-tools
  ];

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
      
      # Function to check power source
      check_power_source() {
        if [ -f /sys/class/power_supply/ACAD/online ]; then
          cat /sys/class/power_supply/ACAD/online
        else
          # Fallback for different AC adapter naming
          find /sys/class/power_supply -name "A*" -type d -exec cat {}/online \; 2>/dev/null | head -1 || echo "0"
        fi
      }
      
      # Function to count connected Bluetooth devices
      count_connected_devices() {
        ${pkgs.bluez}/bin/bluetoothctl devices Connected 2>/dev/null | wc -l
      }
      
      # Function to enable Bluetooth
      enable_bluetooth() {
        echo "Enabling Bluetooth..."
        ${pkgs.systemd}/bin/systemctl start bluetooth.service 2>/dev/null || true
        sleep 2
        ${pkgs.bluez}/bin/bluetoothctl power on 2>/dev/null || true
        echo "Bluetooth enabled"
      }
      
      # Function to disable Bluetooth
      disable_bluetooth() {
        echo "Disabling Bluetooth for power saving..."
        ${pkgs.bluez}/bin/bluetoothctl power off 2>/dev/null || true
        echo "Bluetooth disabled"
      }
      
      # Main logic
      power_source=$(check_power_source)
      
      if [ "$power_source" = "1" ]; then
        # On AC power - always enable Bluetooth
        echo "AC power detected - enabling Bluetooth automatically"
        enable_bluetooth
      else
        # On battery power - check for connected devices
        echo "Battery power detected - checking Bluetooth usage..."
        
        # Ensure bluetooth service is running to check connections
        ${pkgs.systemd}/bin/systemctl start bluetooth.service 2>/dev/null || true
        sleep 3
        
        connected_devices=$(count_connected_devices)
        
        if [ "$connected_devices" -eq 0 ]; then
          echo "No Bluetooth devices connected ($connected_devices devices) - disabling for power saving"
          disable_bluetooth
        else
          echo "Bluetooth devices connected ($connected_devices devices) - keeping enabled"
        fi
      fi
      
      echo "Smart Bluetooth management completed"
    '';
    path = with pkgs; [ bash bluez systemd coreutils findutils ];
  };

  # Periodic check for Bluetooth optimization (fallback)
  systemd.services.bluetooth-power-check = {
    description = "Periodic Bluetooth Power Optimization Check";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      # Run the smart bluetooth logic
      ${pkgs.systemd}/bin/systemctl start smart-bluetooth.service
    '';
  };

  # Timer for periodic Bluetooth checks (every 5 minutes when on battery)
  systemd.timers.bluetooth-power-check = {
    description = "Timer for Bluetooth Power Optimization";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "5min";
      Unit = "bluetooth-power-check.service";
    };
  };

  # Helper script for manual Bluetooth management
  environment.etc."bluetooth-power-helper".text = ''
    #!/bin/bash
    # Manual Bluetooth Power Management Helper
    
    case "$1" in
      "status")
        echo "=== Bluetooth Power Management Status ==="
        echo -n "Power source: "
        if [ -f /sys/class/power_supply/ACAD/online ]; then
          if [ "$(cat /sys/class/power_supply/ACAD/online)" = "1" ]; then
            echo "AC (plugged in)"
          else
            echo "Battery"
          fi
        else
          echo "Unknown"
        fi
        
        echo -n "Bluetooth power: "
        ${pkgs.bluez}/bin/bluetoothctl show | grep "Powered:" || echo "Unknown"
        
        echo "Connected devices:"
        ${pkgs.bluez}/bin/bluetoothctl devices Connected || echo "None"
        ;;
        
      "force-on")
        echo "Manually enabling Bluetooth..."
        ${pkgs.systemd}/bin/systemctl start bluetooth.service
        ${pkgs.bluez}/bin/bluetoothctl power on
        ;;
        
      "force-off")  
        echo "Manually disabling Bluetooth..."
        ${pkgs.bluez}/bin/bluetoothctl power off
        ;;
        
      "auto")
        echo "Running automatic Bluetooth management..."
        ${pkgs.systemd}/bin/systemctl start smart-bluetooth.service
        ;;
        
      *)
        echo "Usage: bluetooth-power-helper {status|force-on|force-off|auto}"
        echo ""
        echo "  status    - Show current Bluetooth and power status"
        echo "  force-on  - Manually enable Bluetooth"
        echo "  force-off - Manually disable Bluetooth"
        echo "  auto      - Run automatic power management logic"
        ;;
    esac
  '';

  # Make helper script executable
  system.activationScripts.bluetooth-helper = ''
    if [ -f /etc/bluetooth-power-helper ]; then
      chmod +x /etc/bluetooth-power-helper
    fi
  '';
}
