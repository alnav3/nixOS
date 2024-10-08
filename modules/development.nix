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
    fzf
    ripgrep
    bat
    tmux
    zoxide
    git
    gcc
    go
    templ
    lsof
    air
    kubernetes
    kubernetes-helm
    helmfile
    oh-my-posh
    temurin-bin-17
    maven
    python3
    kaf
    nodejs_22
    neovim
    eza
  ];
  # zsh minimal configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableAutosuggestions = true;
    enableSyntaxHighlighting = true;
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
