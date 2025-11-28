{
  pkgs,
  meta,
  overlays,
  ...
}: {
    security.polkit.enable = true;
  # Add overlays
  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      overlays.additions
    ];
  };
  imports =
    [./machines/${meta.hostname}/configuration.nix];
  networking.hostName = meta.hostname;


  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  services.openssh.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # sops config
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  #sops.age.keyFile = "/home/alnav/.config/sops/age/keys.txt";

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # user config
  users.users.duck = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiP2WKxf0TUiFAlb/rg/dpimYTpzMntD7UmUYQxxiVUt6OCg34iKgDHHiC+nK2nRMuy1viT84dR0qUiG9J+vLTVJ1nuBgg1HI5w/RJ3f7oKSmV2rSnK0jetGU8yeJ8H/9MmwYGQ6Oc2896q0IukojFc7ULRKr1/fMOFTNL9v++IwpuTL05D1OkVbpcB1rKM5vSjYEWen+1SBuQWW91BepyLwiX4CrLttaJyZIHUVYgtcUbAIcduduA4lkCrFHud4N93R1QqIXqf4WYew5OoxNjhXhLq6yJ9w+MvbmeCzqEgSkwSj9jFb97Se4FCHeeiV20Y6mM7/yeTC73i77w3DpnDPO0iYtNtcbZ1EmKOF2N7LXwW5jqZT8e/w4TbRFYJ+zfe0zWRO/27H3DSNPcb8LcEpYFNFQ+plgRRO9fBwLRhgHSVolU6JudOoe6g+TCUaR4CMV+xF/Ir6A6P5vwPR6Y1cTjufXrx/SdsfPNk5q1YK6qRxPxPt3tCNVGdO68psfDwpXxYxwUiPtytEvgenr1aXbauA4QqM1qMTOLa14Q/je5D5regg497RFXVjgLeQf3bDrhsSlaaHuARme9OkcKr8vyzIyPGIvmxvl6zlQBrBGHHKey1gMtB4QH/xeA8dLofD83p/Yl174omx+2L5XiP0QqfHu4T/cC0j1baGL2BQ== alnav@nixos"
    ];
  };

  users.users.alnav = {
    isNormalUser = true;
    extraGroups = [
      "uinput"
      "wheel"
      "docker"
      "audio"
      "input"
      "disk"
      "libvirtd"
      "qemu-libvirtd"
      "libvirt"
      "dialout"
    ];

    hashedPassword = "$6$Ld6VVI/GPx3tS3HO$pAjCdjWroN88QoCPCER7UdXq1XTbC1C8linCar7/ykEsgtya4JesK1ILX5ffoRqgMkTR/NPN10NfYsvI2yHzE.";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiP2WKxf0TUiFAlb/rg/dpimYTpzMntD7UmUYQxxiVUt6OCg34iKgDHHiC+nK2nRMuy1viT84dR0qUiG9J+vLTVJ1nuBgg1HI5w/RJ3f7oKSmV2rSnK0jetGU8yeJ8H/9MmwYGQ6Oc2896q0IukojFc7ULRKr1/fMOFTNL9v++IwpuTL05D1OkVbpcB1rKM5vSjYEWen+1SBuQWW91BepyLwiX4CrLttaJyZIHUVYgtcUbAIcduduA4lkCrFHud4N93R1QqIXqf4WYew5OoxNjhXhLq6yJ9w+MvbmeCzqEgSkwSj9jFb97Se4FCHeeiV20Y6mM7/yeTC73i77w3DpnDPO0iYtNtcbZ1EmKOF2N7LXwW5jqZT8e/w4TbRFYJ+zfe0zWRO/27H3DSNPcb8LcEpYFNFQ+plgRRO9fBwLRhgHSVolU6JudOoe6g+TCUaR4CMV+xF/Ir6A6P5vwPR6Y1cTjufXrx/SdsfPNk5q1YK6qRxPxPt3tCNVGdO68psfDwpXxYxwUiPtytEvgenr1aXbauA4QqM1qMTOLa14Q/je5D5regg497RFXVjgLeQf3bDrhsSlaaHuARme9OkcKr8vyzIyPGIvmxvl6zlQBrBGHHKey1gMtB4QH/xeA8dLofD83p/Yl174omx+2L5XiP0QqfHu4T/cC0j1baGL2BQ== alnav@nixos"
    ];
  };
  #security.sudo.extraConfig = ''
  #  Defaults        timestamp_timeout=40
  #'';

  security.sudo.extraRules = [
    {
      users = ["alnav"];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  environment.systemPackages = with pkgs; [
    cifs-utils
    age
    qemu
    quickemu
    sops
    killall
  ];

  system.stateVersion = "24.11";
}
