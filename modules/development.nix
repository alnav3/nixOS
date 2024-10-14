{pkgs, inputs, ...}:
{
    # Needed for OSX-KVM
    virtualisation.libvirtd.enable = true;
    boot.extraModprobeConfig = ''
        options kvm_intel nested=1
        options kvm_intel emulate_invalid_guest_state=0
        options kvm ignore_msrs=1
        '';

  # nix-ld libraries needed for language-servers to work on neovim
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat
  ];

  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin"
  ];

  # packages needed for development
  environment.systemPackages = (with pkgs; [
    air
    bat
    eza
    fzf
    gcc
    git
    go
    helmfile
    kaf
    kubernetes
    kubernetes-helm
    lsof
    maven
    nodejs_22
    oh-my-posh
    python3
    ripgrep
    templ
    temurin-bin-17
    tmux
    unzip
    zoxide
    zsh-autosuggestions
    zsh-fzf-history-search
    zsh-vi-mode
    neovim
    qemu
  ]);

  # zsh minimal configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable= true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      cl = "clear";
      update = "sudo nixos-rebuild switch --flake '/home/alnav/nixOS#framework'";
      rofi-wifi = "${inputs.rofi-wifi}/rofi-wifi-menu.sh";
      update-flake = "nix flake lock --update-input";
      hibernate = "hyprlock & systemctl hibernate";
    };
  };
  users.defaultUserShell = pkgs.zsh;
  services = {
      gnome.gnome-keyring.enable = true;
  };

  # docker config
  virtualisation.docker = {
    enable = true;
  };

}
