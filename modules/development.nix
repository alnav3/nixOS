{
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  # Needed for OSX-KVM
  virtualisation.libvirtd.enable = true;
  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
    options kvm_intel emulate_invalid_guest_state=0
    options kvm ignore_msrs=1
  '';

  # nix-ld libraries needed for language-servers to work on neovim
  programs.nix-ld.enable = true;
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
  nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];

  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin"
  ];

  # packages needed for development
  environment.systemPackages = with pkgs; [
    air
    alejandra
    bat
    eza
    fzf
    android-tools
    gcc
    # Git will be configured by home-manager
    git
    go
    helmfile
    kaf
    kubectl
    kubernetes-helm
    lsof
    maven
    neovim
    nixd
    nodejs_22
    pkgs-unstable.oh-my-posh
    python3
    qemu
    ripgrep
    templ
    temurin-bin-17
    tmux
    tree-sitter
    unzip
    wl-clipboard
    zoxide
    zsh-autosuggestions
    zsh-fzf-history-search
    zsh-vi-mode
  ];

  # zsh minimal configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      cl = "clear";
      update = "sudo nixos-rebuild switch --flake '/home/alnav/nixOS#framework'";
      clean-disk = "nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 1d";
      rofi-wifi = "${inputs.rofi-wifi}/rofi-wifi-menu.sh";
      update-flake = "nix flake lock --update-input";
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
