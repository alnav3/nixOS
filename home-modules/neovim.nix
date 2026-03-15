{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  hlib = import ./_lib {inherit lib;};
  cfg = config.myhome.neovim;
in {
  options.myhome.neovim = {
    enable = lib.mkEnableOption "Neovim configuration";

    javaSupport = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Java development support";
    };

    extraPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional neovim plugins";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      plugins = lib.mkMerge [
        (lib.mkIf cfg.javaSupport [
          pkgs.vimPlugins.nvim-java
          pkgs.vimPlugins.nvim-java-dap
        ])
        cfg.extraPlugins
      ];
    };
  };
}