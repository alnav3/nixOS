{ config, lib, pkgs, ... }: {
  imports = [
    # SteamOS module brings in gaming optimizations.
    ./../../modules/steamos.nix
    ./../../modules/networking.nix
    ./../../modules/bluetooth.nix
  ];

  # Use a recent kernel version (6.11) which can improve hardware performance.
  boot.kernelPackages = pkgs.linuxPackages_6_11;

  # Activate ollama for llm usage
  services.ollama.enable = true;

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
}

