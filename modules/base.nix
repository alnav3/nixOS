{ config, lib, pkgs, overlays, inputs, ... }:

let
  cfg = config.mymodules.base;
  mlib = import ./_lib { inherit lib; };
in
{
  options.mymodules.base = {
    enable = lib.mkEnableOption "base system configuration" // {
      default = true;
    };

    # User configuration
    user = {
      username = lib.mkOption {
        type = lib.types.str;
        default = mlib.helpers.defaultUser;
        description = "Primary username";
      };

      hashedPassword = lib.mkOption {
        type = lib.types.str;
        default = "$6$Ld6VVI/GPx3tS3HO$pAjCdjWroN88QoCPCER7UdXq1XTbC1C8linCar7/ykEsgtya4JesK1ILX5ffoRqgMkTR/NPN10NfYsvI2yHzE.";
        description = "Hashed password for the user";
      };

      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "wheel"
          "audio"
          "networkmanager"
          "input"
          "disk"
          "dialout"
        ];
        description = "Additional groups for the user";
      };

      sshKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiP2WKxf0TUiFAlb/rg/dpimYTpzMntD7UmUYQxxiVUt6OCg34iKgDHHiC+nK2nRMuy1viT84dR0qUiG9J+vLTVJ1nuBgg1HI5w/RJ3f7oKSmV2rSnK0jetGU8yeJ8H/9MmwYGQ6Oc2896q0IukojFc7ULRKr1/fMOFTNL9v++IwpuTL05D1OkVbpcB1rKM5vSjYEWen+1SBuQWW91BepyLwiX4CrLttaJyZIHUVYgtcUbAIcduduA4lkCrFHud4N93R1QqIXqf4WYew5OoxNjhXhLq6yJ9w+MvbmeCzqEgSkwSj9jFb97Se4FCHeeiV20Y6mM7/yeTC73i77w3DpnDPO0iYtNtcbZ1EmKOF2N7LXwW5jqZT8e/w4TbRFYJ+zfe0zWRO/27H3DSNPcb8LcEpYFNFQ+plgRRO9fBwLRhgHSVolU6JudOoe6g+TCUaR4CMV+xF/Ir6A6P5vwPR6Y1cTjufXrx/SdsfPNk5q1YK6qRxPxPt3tCNVGdO68psfDwpXxYxwUiPtytEvgenr1aXbauA4QqM1qMTOLa14Q/je5D5regg497RFXVjgLeQf3bDrhsSlaaHuARme9OkcKr8vyzIyPGIvmxvl6zlQBrBGHHKey1gMtB4QH/xeA8dLofD83p/Yl174omx+2L5XiP0QqfHu4T/cC0j1baGL2BQ== alnav@nixos"
        ];
        description = "SSH public keys for the user";
      };
    };

    # Nix configuration
    nix = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.nixVersions.stable;
        description = "Nix package to use";
      };

      flakes = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable flakes and nix-command";
      };

      secretKeyFiles = lib.mkOption {
        type = lib.types.str;
        default = "/etc/nix/signing-key";
        description = "Path to signing key for binary cache";
      };

      trustedSubstituters = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "ssh://mjolnir.home" ];
        description = "Trusted binary cache substituters";
      };

      trustedPublicKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "mjolnir.home:AE24oIg+8t8NWRQcjOHZuwHQiQG2QAzIcheHA/bliIY=" ];
        description = "Public keys for trusted substituters";
      };
    };

    # SSH server configuration
    ssh = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SSH server";
      };

      passwordAuthentication = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow password authentication";
      };

      kbdInteractiveAuthentication = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow keyboard-interactive authentication";
      };

      permitRootLogin = lib.mkOption {
        type = lib.types.str;
        default = "no";
        description = "Whether to allow root login";
      };

      ports = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ 22 ];
        description = "SSH server ports";
      };

      x11Forwarding = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable X11 forwarding";
      };
    };

    # Boot configuration
    boot = {
      systemdBoot = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable systemd-boot EFI boot loader";
      };

      efiCanTouchVariables = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow modifying EFI variables";
      };
    };

    # SOPS encryption
    sops = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SOPS for secret management";
      };

      defaultSopsFile = lib.mkOption {
        type = lib.types.path;
        default = ../secrets/secrets.yaml;
        description = "Default SOPS file path";
      };

      sshKeyPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "/etc/ssh/ssh_host_ed25519_key" ];
        description = "SSH key paths for SOPS age encryption";
      };
    };

    # Localization
    locale = {
      timeZone = lib.mkOption {
        type = lib.types.str;
        default = "Europe/Madrid";
        description = "System timezone";
      };

      defaultLocale = lib.mkOption {
        type = lib.types.str;
        default = "en_US.UTF-8";
        description = "System default locale";
      };
    };

    # Security
    security = {
      polkit = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable polkit";
      };

      sudoNoPassword = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow sudo without password for the main user";
      };
    };

    # VM configuration
    vm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable VM-specific configuration";
      };

      memorySize = lib.mkOption {
        type = lib.types.int;
        default = 8192;
        description = "VM memory size in MB";
      };

      cores = lib.mkOption {
        type = lib.types.int;
        default = 6;
        description = "VM CPU cores";
      };
    };

    # System state version
    stateVersion = lib.mkOption {
      type = lib.types.str;
      default = "24.11";
      description = "NixOS state version";
    };

    # Extra packages
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional system packages";
    };
  };

  config = lib.mkIf cfg.enable {
    # Security
    security.polkit.enable = cfg.security.polkit;

    # Add overlays
    nixpkgs.overlays = [
      overlays.additions
    ];

    # Nix configuration
    nix = {
      package = cfg.nix.package;
      extraOptions = lib.mkIf cfg.nix.flakes ''
        experimental-features = nix-command flakes
      '';
      settings = {
        secret-key-files = cfg.nix.secretKeyFiles;
        trusted-substituters = cfg.nix.trustedSubstituters;
        trusted-public-keys = cfg.nix.trustedPublicKeys;
      };
    };

    # SSH configuration
    services.openssh = lib.mkIf cfg.ssh.enable {
      enable = true;
      inherit (cfg.ssh) ports;
      settings = {
        X11Forwarding = cfg.ssh.x11Forwarding;
        PasswordAuthentication = cfg.ssh.passwordAuthentication;
        KbdInteractiveAuthentication = cfg.ssh.kbdInteractiveAuthentication;
        PermitRootLogin = cfg.ssh.permitRootLogin;
      };
    };

    # Boot loader
    boot.loader = lib.mkIf cfg.boot.systemdBoot {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = cfg.boot.efiCanTouchVariables;
    };

    # SOPS configuration
    sops = lib.mkIf cfg.sops.enable {
      defaultSopsFile = cfg.sops.defaultSopsFile;
      defaultSopsFormat = "yaml";
      age.sshKeyPaths = cfg.sops.sshKeyPaths;
    };

    # Timezone and locale
    time.timeZone = cfg.locale.timeZone;
    i18n.defaultLocale = cfg.locale.defaultLocale;

    # User configuration
    users.users.${cfg.user.username} = {
      isNormalUser = true;
      extraGroups = cfg.user.extraGroups;
      hashedPassword = cfg.user.hashedPassword;
      openssh.authorizedKeys.keys = cfg.user.sshKeys;
    };

    # Sudo configuration
    security.sudo.extraRules = lib.mkIf cfg.security.sudoNoPassword [
      {
        users = [ cfg.user.username ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Base system packages
    environment.systemPackages = with pkgs; [
      cifs-utils
      age
      sops
      killall
    ] ++ (lib.optionals cfg.vm.enable [
      qemu
      quickemu
    ]) ++ cfg.extraPackages;

    # VM variant configuration
    virtualisation.vmVariant = lib.mkIf cfg.vm.enable {
      swapDevices = lib.mkForce [];
      virtualisation = {
        memorySize = cfg.vm.memorySize;
        cores = cfg.vm.cores;
      };
    };

    # System state version
    system.stateVersion = cfg.stateVersion;
  };
}
