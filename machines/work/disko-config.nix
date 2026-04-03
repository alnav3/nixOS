{
  disko.devices = {
    disk = {
      vdb = {
        type = "disk";
        device = "/dev/nvme0n1";  # Adjust if using different disk (e.g., /dev/sda)
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "512M";
              type = "EF02";
            };
            ESP = {
              size = "4G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              size = "34G"; # Adjust based on RAM (recommended: 1.5x RAM for hibernation)
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = true;
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "luks_btrfs";
                content = {
                  type = "btrfs";
                  extraArgs = ["-f"]; # Override existing partition
                  subvolumes = {
                    "/rootfs" = {
                      mountpoint = "/";
                    };
                    "/home" = {
                      mountOptions = ["compress=zstd"];
                      mountpoint = "/home";
                    };
                    "/home/alnav" = {};
                    "/nix" = {
                      mountOptions = ["compress=zstd" "noatime"];
                      mountpoint = "/nix";
                    };
                  };
                  mountpoint = "/partition-root";
                };
              };
            };
          };
        };
      };
    };
  };
}
