{
  pkgs,
  ...
}: let
  hibernateEnvironment = {
    HIBERNATE_SECONDS = "1800";
    HIBERNATE_LOCK = "/var/run/autohibernate.lock";
  };
in {
  boot.kernelParams = [ "amd_pstate=passive" ];

  environment.systemPackages = with pkgs; [
    brightnessctl
    btop
    powertop
    hypridle
  ];
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
        ${pkgs.utillinux}/bin/rtcwake -m no -s $HIBERNATE_SECONDS
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
        ${pkgs.utillinux}/bin/rtcwake -m no -s 1
      fi
    '';
    serviceConfig.Type = "simple";
  };

  # power save modes
  services.power-profiles-daemon.enable = false;
  services.auto-cpufreq = {
      enable = true;
      settings = {
          battery = {
              governor = "powersave";
              scaling_min_freq = "500000";
              scaling_max_freq = "500000";
              turbo = "never";
          };
          charger = {
              governor = "performance";
              scaling_min_freq = "1000000";
              scaling_max_freq = "3501000";
              turbo = "auto";
          };
      };
  };
}
