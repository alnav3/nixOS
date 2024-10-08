{pkgs, ...}:
{
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
  environment.systemPackages = with pkgs; [
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
    neovim
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
  ];
  # zsh minimal configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableAutosuggestions = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      cl = "clear";
      update = "sudo nixos-rebuild switch";
    };
  };
  users.defaultUserShell = pkgs.zsh;
  services = {
      gnome.gnome-keyring.enable = true;
  };

  # docker config
  #virtualisation.docker = {
  #  enable = true;
  #  setSocketVariable = true;
  #  daemon.settings = {
  #    data-root = "/var/lib/docker";
  #  };
  #};

}
