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
  ];

  environment.systemPackages = with pkgs; [
    brightnessctl
    ryzenadj
    btop
    powertop
    hypridle
    tlp
    acpi
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
        echo "$curtime $1" >> /tmp/autohibernate.log
        echo "$curtime" > $HIBERNATE_LOCK
        ${pkgs.util-linux}/bin/rtcwake -m no -s $HIBERNATE_SECONDS
      else
        echo "System is on AC power, skipping wake-up scheduling for hibernation." >> /tmp/autohibernate.log
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
      sustime=$(cat $HIBERNATE_LOCK)
      rm $HIBERNATE_LOCK
      if [ $(($curtime - $sustime)) -ge $HIBERNATE_SECONDS ] ; then
        systemctl hibernate
      else
        ${pkgs.util-linux}/bin/rtcwake -m no -s 1
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

  # Enable USB autosuspend for all devices by default
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

  # Additional power-saving optimizations
  services.dbus.implementation = "broker"; # More efficient D-Bus
  
  # Reduce network manager scanning
  networking.networkmanager.wifi = {
    scanRandMacAddress = false; # Reduces power
    powersave = true;
  };

  # Bluetooth power optimizations
  hardware.bluetooth = {
    powerOnBoot = false; # Don't auto-enable bluetooth
    settings.General = {
      Experimental = true;
      FastConnectable = false;
    };
  };
}
