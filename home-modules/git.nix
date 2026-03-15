{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  hlib = import ./_lib {inherit lib;};
  cfg = config.myhome.git;
in {
  options.myhome.git = {
    enable = lib.mkEnableOption "Git configuration";

    withLibsecret = lib.mkOption {
      type = lib.types.bool;
      default = hlib.defaults.git.credential.helper.withLibsecret;
      description = "Enable libsecret credential helper";
    };

    autoSetupRemote = lib.mkOption {
      type = lib.types.bool;
      default = hlib.defaults.git.push.autoSetupRemote;
      description = "Automatically setup remote tracking";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional git settings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = lib.mkMerge [
        {
          credential.helper = lib.mkIf cfg.withLibsecret "${
            pkgs.git.override {withLibsecret = true;}
          }/bin/git-credential-libsecret";
          push.autoSetupRemote = lib.mkIf cfg.autoSetupRemote true;
        }
        cfg.extraSettings
      ];
    };
  };
}