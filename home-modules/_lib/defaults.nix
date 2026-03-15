{lib}: {
  user = {
    username = "alnav";
    homeDirectory = "/home/alnav";
    stateVersion = "26.05";
  };

  paths = {
    dotfiles = "dotfiles"; # This will be resolved from inputs
    tpm = "tpm"; # This will be resolved from inputs
  };

  jdk = {
    versions = [
      "temurin-bin-11"
      "temurin-bin-17"
      "temurin-bin-21"
    ];
  };

  git = {
    credential.helper.withLibsecret = true;
    push.autoSetupRemote = true;
  };

  kitty = {
    confirmClose = false;
  };

  theme = {
    font = {
      name = "CaskaydiaCove NF";
      size = "16px";
    };
  };
}