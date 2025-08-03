{ config, lib, pkgs, ... }: {
  imports = [
    # SteamOS module brings in gaming optimizations.
    ./../../modules/android.nix
    ./../../modules/bluetooth.nix
    ./../../modules/desktop.nix
    ./../../modules/loginSteam.nix
    ./../../modules/networking.nix
    ./../../modules/ricing.nix
    ./../../modules/steamos.nix
  ];

  # Use a recent kernel version (6.11) which can improve hardware performance.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "boot.shell_on_fail"
    ];
    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    kernelModules = [ "kvm-amd" ];
  };
  networking.interfaces.enp13s0.wakeOnLan = {
    enable = true;
  };

  # Activate ollama for llm usage
  services.ollama ={
      enable = true;
      acceleration = "rocm";
      host = "[::]";
      openFirewall = true;
      environmentVariables = {
        HSA_OVERRIDE_GFX_VERSION = "11.0.0";
      };
  };

  # Ensure AMD GPU firmware is loaded early in the initramfs.
  hardware.amdgpu.initrd.enable = true;

  # Allow unfree Steam-related packages.
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-original"
      "steam-run"
      "steam-jupiter-original"
      "steam-jupiter-unwrapped"
      "steamdeck-hw-theme"
    ];
  environment.systemPackages = with pkgs; [
    tmux
    neovim
    steamtinkerlaunch
  ];

  systemd.services.usb-wake = {
      description = "Enables wakeup for all usb devices";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
          Type = "oneshot";
          ExecStart = [ "/etc/usb-wake.sh" ];
      };
  };

  environment.etc."usb-wake.sh".source = pkgs.writeScript "enable-wakeup" ''
    #!${pkgs.runtimeShell}

    # Disable all USB wakeups first
    for device in /sys/bus/usb/devices/usb[0-9]*; do
      echo disabled > "$device/power/wakeup"
    done

    # Only enable USB3 and USB5 (used by 8BitDo)
    echo enabled > /sys/bus/usb/devices/usb3/power/wakeup
    echo enabled > /sys/bus/usb/devices/usb5/power/wakeup
  '';
}

