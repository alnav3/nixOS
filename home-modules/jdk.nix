{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  hlib = import ./_lib {inherit lib;};
  cfg = config.myhome.jdk;
in {
  options.myhome.jdk = {
    enable = lib.mkEnableOption "JDK management";

    versions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = hlib.defaults.jdk.versions;
      description = "List of JDK package names to install";
    };

    extraVersions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional JDK versions to install";
    };
  };

  config = lib.mkIf cfg.enable (let
    allVersions = cfg.versions ++ cfg.extraVersions;
    jdkFiles = hlib.helpers.mkJdkFiles pkgs allVersions;
  in {
    home.file = hlib.helpers.mkStaticFiles jdkFiles;
  });
}