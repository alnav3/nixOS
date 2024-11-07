{pkgs, ...}: {
  services.blueman.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
    };
  };

  # Activate hardware buttons for bluetooth headsets
  systemd.user.services.mpris-proxy = {
    description = "Mpris proxy";
    after = ["network.target" "sound.target"];
    wantedBy = ["default.target"];
    serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
  };

  environment.systemPackages = [
    pkgs.rofi-bluetooth
    pkgs.alsa-utils
    pkgs.pavucontrol
    pkgs.easyeffects
  ];
}
