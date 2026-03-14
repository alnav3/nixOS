{ lib }:

let
  defaults = import ./defaults.nix { inherit lib; };
in
{
  # Create a standard OCI container configuration
  mkContainer = {
    name,
    image,
    ipSuffix,
    port ? null,
    environment ? {},
    volumes ? [],
    extraOptions ? [],
    cmd ? null,
    dependsOn ? [],
    ...
  }: {
    inherit image;
    
    environment = defaults.environment // environment;
    
    extraOptions = [
      "--net" defaults.network.name
      "--ip" "${defaults.network.baseIP}.${toString ipSuffix}"
    ] ++ extraOptions;
    
    volumes = volumes;
    
    ports = [];
  } // (if cmd != null then { inherit cmd; } else {})
    // (if dependsOn != [] then { inherit dependsOn; } else {});

  # Generate IP address from suffix
  mkIP = ipSuffix: "${defaults.network.baseIP}.${toString ipSuffix}";

  # Create data directory rules for systemd-tmpfiles
  mkDataDirs = dirs: map (dir: "d ${defaults.paths.dataDir}/${dir} 0755 root root -") dirs;

  # Merge environment with defaults
  mkEnv = env: defaults.environment // env;
}
