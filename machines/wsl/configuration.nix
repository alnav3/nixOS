{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.default
    ./development.nix
  ];

  wsl.enable = true;
  wsl.defaultUser = "alnav";

  networking.hostName = "wsl";

  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    settings = {
      secret-key-files = "/etc/nix/signing-key";
      trusted-substituters = [ "ssh://mjolnir.home" ];
      trusted-public-keys = [ "mjolnir.home:AE24oIg+8t8NWRQcjOHZuwHQiQG2QAzIcheHA/bliIY=" ];
    };
  };

  services.openssh = {
    enable = true;
    ports = [ 2022 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    neovim
    ungoogled-chromium
    xauth
  ];

  users.users.alnav = {
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiP2WKxf0TUiFAlb/rg/dpimYTpzMntD7UmUYQxxiVUt6OCg34iKgDHHiC+nK2nRMuy1viT84dR0qUiG9J+vLTVJ1nuBgg1HI5w/RJ3f7oKSmV2rSnK0jetGU8yeJ8H/9MmwYGQ6Oc2896q0IukojFc7ULRKr1/fMOFTNL9v++IwpuTL05D1OkVbpcB1rKM5vSjYEWen+1SBuQWW91BepyLwiX4CrLttaJyZIHUVYgtcUbAIcduduA4lkCrFHud4N93R1QqIXqf4WYew5OoxNjhXhLq6yJ9w+MvbmeCzqEgSkwSj9jFb97Se4FCHeeiV20Y6mM7/yeTC73i77w3DpnDPO0iYtNtcbZ1EmKOF2N7LXwW5jqZT8e/w4TbRFYJ+zfe0zWRO/27H3DSNPcb8LcEpYFNFQ+plgRRO9fBwLRhgHSVolU6JudOoe6g+TCUaR4CMV+xF/Ir6A6P5vwPR6Y1cTjufXrx/SdsfPNk5q1YK6qRxPxPt3tCNVGdO68psfDwpXxYxwUiPtytEvgenr1aXbauA4QqM1qMTOLa14Q/je5D5regg497RFXVjgLeQf3bDrhsSlaaHuARme9OkcKr8vyzIyPGIvmxvl6zlQBrBGHHKey1gMtB4QH/xeA8dLofD83p/Yl174omx+2L5XiP0QqfHu4T/cC0j1baGL2BQ== alnav@nixos"
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "25.11";
}
