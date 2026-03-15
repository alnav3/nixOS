{ lib }:

let
  defaults = import ./defaults.nix { inherit lib; };
in
{
  # Create a module option with enable flag
  mkModule = {
    name,
    description,
    default ? false,
  }: lib.mkOption {
    type = lib.types.bool;
    inherit default;
    description = "Whether to enable ${description}";
  };

  # Create an enable option (shorthand)
  mkEnable = description: lib.mkEnableOption description;

  # Create a package list option
  mkPackageOption = description: lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [];
    description = "Additional packages for ${description}";
  };

  # Get default user
  defaultUser = defaults.user.name;

  # Get default home directory
  defaultHome = defaults.paths.home;

  # Create conditional config
  mkIfEnabled = cfg: config: lib.mkIf cfg.enable config;

  # Merge multiple conditional configs
  mkMergeIf = conditions: lib.mkMerge (lib.filter (x: x != null) conditions);
}
