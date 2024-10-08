{ config, lib, pkgs, meta, ... }:

{
  imports =
    if builtins.substr 0 (builtins.stringLength "homelab") meta.hostname == "homelab" then
      [ ./machine/homelab/configuration.nix ]
    else
      [ ./machine/${meta.hostname}/configuration.nix ];

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # sops config
  sops.defaultSopsFile = "./secrets/secrets.yaml";
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/home/alnav/.config/sops/age/keys.txt";

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # user config
  users.users.alnav = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];

    hashedPassword = "$6$Ld6VVI/GPx3tS3HO$pAjCdjWroN88QoCPCER7UdXq1XTbC1C8linCar7/ykEsgtya4JesK1ILX5ffoRqgMkTR/NPN10NfYsvI2yHzE.";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2PZ42g+dR8d/Qroi9ShxEvrvv5hEuTQaiqmcBrpT0O2TsMulIf6KAAID4gDEE7uzjPp/yu5SvNpoMYZEbM/SDnnGDE3c1OmfvvuWtkl/sDiT5laXsYlm58S5tXf48gxmIeXiXx0SD/ZuNjQCBzwjjLVqOdyl0vniw05u1J2kv4dy3Dk1bcs0VlxG09FyNQjogE7rE2MsbzQVf1+jMUjyFe24nRK2xn4JPGlfP7q6wXcTrYAolYzmAWh1bnnLlA8xGY8bk3QVMgmUAtajyYbwYaAxI1lBPUkFmz7T5re9BeBsPlKa/rGp7UJokIfs1NYKfsI2ekWRhpIrO7Clv/+s4xGEqO2pnVo658ut8243sAWa8WsVVHNB0Eem49+XWaxvOndjTBkz7wNMEf+L76h7rePRHnti1J3liROkJJP4k7T4ls44lK8acLRwbSGnaxk4189Ivh7LakbjZrZuFqP7tcXqVVTBimYvymcZSq9K9Ivi3cFe91ZamjZdNTjtUjo9TJlMc/+WMcrjVOMymCsQBzzoHLuRg/A4ePKud+BpcHZF1w8XRoy583JrWiy+t3XTGUX56mScpvoXn/VAnx+nVb0ifbZQ7mY8P7apuxhDcu/aNQdDmmkWvno6xh6ufc5P8U/BlY+QpUkZ2K5v69pyAV8/lJbTKFNt/WKTNERsdyQ== alexnavia3@MacBook-Air.local"
    ];
  };
  #security.sudo.extraConfig = ''
  #  Defaults        timestamp_timeout=40
  #'';

  security.sudo.extraRules = [
    { users = [ "alnav" ];
       commands = [
         { command = "ALL" ;
             options= [ "NOPASSWD" ];
         }
       ];
    }
  ];

  environment.systemPackages = with pkgs; [
    age
  ];

}

