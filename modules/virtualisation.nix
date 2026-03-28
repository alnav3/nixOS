{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.virtualisation;
  mlib = import ./_lib { inherit lib; };
in
{
  options.mymodules.virtualisation = {
    enable = lib.mkEnableOption "Virtualisation support";

    # Docker configuration
    docker = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Docker";
      };

      batteryOptimized = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use battery-optimized Docker settings (reduced logging, storage limits)";
      };

      rootless = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable rootless Docker";
      };

      autoPrune = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable automatic Docker cleanup";
        };

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "weekly";
          description = "Prune schedule (daily, weekly)";
        };

        aggressive = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Aggressive pruning (all images, volumes)";
        };
      };

      # Custom networks
      networks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            subnet = lib.mkOption {
              type = lib.types.str;
              description = "Network subnet (e.g., 172.42.0.0/24)";
            };
            dependsOn = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "Services that depend on this network";
            };
          };
        });
        default = {};
        description = "Custom Docker networks to create";
      };
    };

    # Container backend
    containers = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NixOS containers support";
      };

      backend = lib.mkOption {
        type = lib.types.enum [ "docker" "podman" ];
        default = "docker";
        description = "OCI container backend";
      };
    };

    # SPICE USB redirection (for VMs)
    spice = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable SPICE USB redirection";
    };

    # Distrobox
    distrobox = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Distrobox";
    };

    # QEMU/KVM
    qemu = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable QEMU/KVM virtualisation";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Docker configuration
    (lib.mkIf cfg.docker.enable (lib.mkMerge [
      # Base Docker config
      {
        virtualisation.docker = {
          enable = true;
          rootless = lib.mkIf cfg.docker.rootless {
            enable = true;
            setSocketVariable = true;
          };
        };

        users.users.${mlib.helpers.defaultUser}.extraGroups = [ "docker" ];

        environment.systemPackages = [ pkgs.docker-compose ];
      }

      # Auto-prune configuration
      (lib.mkIf cfg.docker.autoPrune.enable {
        virtualisation.docker.autoPrune = {
          enable = true;
          dates = cfg.docker.autoPrune.schedule;
          flags = if cfg.docker.autoPrune.aggressive
            then [ "--all" "--force" "--volumes" ]
            else [ "--filter=until=24h" "--filter=label!=important" ];
        };
      })

      # Battery-optimized settings (for laptops)
      (lib.mkIf cfg.docker.batteryOptimized {
        # Don't start Docker on boot - it activates via socket when you run a docker command.
        # This prevents containers with restart policies from auto-launching and draining battery.
        virtualisation.docker.enableOnBoot = false;

        # Disable live-restore to reduce daemon overhead
        virtualisation.docker.liveRestore = false;

        virtualisation.docker.daemon.settings = {
          # Reduce logging overhead
          "log-driver" = "none";
          "log-level" = "warn";

          # Reduce storage driver overhead
          "storage-driver" = "overlay2";

          # Resource limits to prevent runaway containers
          "default-ulimits" = {
            "memlock" = {
              "Hard" = 67108864;
              "Name" = "memlock";
              "Soft" = 67108864;
            };
          };
        };
      })

      # Custom networks
      (lib.mkIf (cfg.docker.networks != {}) {
        systemd.services = lib.mapAttrs' (name: netCfg:
          lib.nameValuePair "docker-${name}-net" {
            description = "Create ${name} Docker network";
            wantedBy = [ "multi-user.target" ];
            before = map (s: "docker-${s}.service") netCfg.dependsOn;
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.bash}/bin/sh -c '${pkgs.docker}/bin/docker network inspect ${name} >/dev/null 2>&1 || ${pkgs.docker}/bin/docker network create --subnet=${netCfg.subnet} ${name}'";
              RemainAfterExit = true;
            };
          }
        ) cfg.docker.networks;
      })
    ]))

    # Container backend configuration
    (lib.mkIf cfg.containers.enable {
      boot.enableContainers = true;
      virtualisation.oci-containers.backend = cfg.containers.backend;
    })

    # SPICE USB redirection
    (lib.mkIf cfg.spice {
      virtualisation.spiceUSBRedirection.enable = true;
      environment.systemPackages = with pkgs; [
        spice-gtk
        spice-vdagent
      ];
    })

    # Distrobox
    (lib.mkIf cfg.distrobox {
      environment.systemPackages = [ pkgs.distrobox ];
    })

    # QEMU/KVM
    (lib.mkIf cfg.qemu {
      environment.systemPackages = with pkgs; [
        qemu
        quickemu
      ];
    })
  ]);
}
