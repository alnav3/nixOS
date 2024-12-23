{
  config,
  pkgs,
  ...
}: let
  hibernateEnvironment = {
    HIBERNATE_SECONDS = "1800";
    HIBERNATE_LOCK = "/var/run/autohibernate.lock";
  };
in {
  environment.systemPackages = with pkgs; [
    brightnessctl
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
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 5;

      #Optional helps save long term battery health
      START_CHARGE_THRESH_BAT1 = 40;
      STOP_CHARGE_THRESH_BAT1 = 80;
    };
  };
}
