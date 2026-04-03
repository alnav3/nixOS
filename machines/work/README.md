# Work Laptop Configuration

This is the NixOS configuration for the work laptop. It's designed to be a professional, productivity-focused machine without entertainment or non-free software (except Teams).

## Key Features

### Enabled
- **Development Tools**: Go, Node.js, Java, Python, Nix
- **Infrastructure Tools**: Docker (with user permissions), Kubernetes, databases
- **Work Applications**: 
  - Teams for Linux (communication)
  - Bruno (API testing)
  - Thunderbird (email)
  - Browser (Zen browser via desktop.apps.browser)
  - Neovim, tmux
- **VPN Support**: OpenConnect for corporate VPN via NetworkManager
- **Desktop Environment**: Hyprland with Stylix theming
- **Battery Optimization**: TLP with conservative power settings
- **Hardware Support**: WiFi, Bluetooth (with power management), AMD graphics
- **Backup**: Syncthing and Pika Backup
- **Security**: OpenSnitch application firewall

### Disabled/Not Included
- **Gaming**: Steam, Lutris, Heroic, emulators - completely disabled
- **Entertainment**: MPV, Jellyfin, music streaming (Finamp, Soulseek)
- **Social Media**: Discord, Signal, Telegram
- **Media Tools**: YouTube downloaders, streaming rippers
- **Non-essential**: 3D printing tools, media casting

## Important Notes

### SOPS Secrets Not Used
The following secrets would typically be managed via SOPS but are **not configured** in this work laptop:

1. **WiFi Passwords** (`networking.wifi.networks`)
   - Configure manually via NetworkManager or add to config later
   - Framework uses SOPS with `config.sops.secrets.home_psk.path`

2. **VPN Credentials**
   - Corporate VPN credentials should be managed separately
   - Consider using system keyring or manual configuration
   - OpenConnect will prompt for credentials interactively

3. **Email Configuration** (Thunderbird)
   - Configure email accounts manually after installation
   - Framework may have email settings in SOPS

4. **SSH Keys**
   - User SSH public key is configured in `base.nix` (default)
   - Private keys should be added manually after installation

5. **Build/Deploy Keys**
   - The Mjolnir binary cache signing key (`/etc/nix/signing-key`)
   - Framework has this in SOPS: `config.sops.secrets.mjolnir-build.path`
   - **TODO**: Add this manually or configure SOPS later

### Hardware-Specific Adjustments Needed

After installation, you may need to adjust:

1. **CPU Type** (`hardware-configuration.nix`):
   - Currently assumes AMD CPU (`boot.kernelModules = ["kvm-amd"]`)
   - Change to `kvm-intel` if using Intel CPU
   - Update microcode line accordingly

2. **GPU Type** (`configuration.nix`):
   - Currently set to AMD (`hardware.graphics.gpu = "amd"`)
   - Change to `intel` or `nvidia` if needed
   - Adjust initrd settings

3. **Disk Device** (`disko-config.nix`):
   - Currently uses `/dev/nvme0n1`
   - Change to `/dev/sda` or appropriate device

4. **Swap Size** (`disko-config.nix`):
   - Currently 34GB (adjust based on RAM)
   - Recommended: 1.5x RAM for hibernation support

5. **Resume Device** (`configuration.nix`):
   - Currently `/dev/nvme0n1p3`
   - Verify partition after installation

6. **Keyboard Device Path** (`configuration.nix`):
   - Kanata uses `/dev/input/by-path/platform-i8042-serio-0-event-kbd`
   - May need adjustment based on actual hardware
   - Run `ls /dev/input/by-path/` to find correct device

### Docker Configuration

Docker is enabled and the `alnav` user is added to the `docker` group, allowing Docker usage without sudo:

```nix
user.extraGroups = [
  "docker"
  # ... other groups
];

virtualisation.docker.enable = true;
```

After first login, you may need to log out and back in for group membership to take effect.

### VPN Setup

OpenConnect is configured for corporate VPN access:

```bash
# Via NetworkManager GUI (recommended)
nm-connection-editor

# Or via command line
nmcli connection add type vpn vpn-type openconnect ...

# Or direct openconnect
sudo openconnect vpn.company.com
```

The NetworkManager OpenConnect plugin provides GUI integration in network settings.

## Installation

1. Boot from NixOS installer
2. Run hardware detection:
   ```bash
   nixos-generate-config --root /mnt
   ```
3. Copy generated `hardware-configuration.nix` to `/home/alnav/nixOS/machines/work/`
4. Adjust hardware-specific settings (see above)
5. Install:
   ```bash
   sudo nixos-install --flake github:alnav3/nixos#work
   ```

## Post-Installation

1. **Setup VPN**: Configure corporate VPN via NetworkManager
2. **SSH Keys**: Copy private SSH keys to `~/.ssh/`
3. **Git Config**: Set up work email and signing keys
4. **Email**: Configure Thunderbird with work email
5. **Docker**: Test docker access (`docker ps`)
6. **Verify WiFi/Bluetooth**: Test connectivity and pairing
7. **Battery**: Verify TLP settings are working (`tlp-stat`)

## Maintenance

Update system:
```bash
update  # Alias defined in zsh config
```

Clean old generations:
```bash
clean-disk  # Alias for wiping old profiles
```

## Future Considerations

- **SOPS Integration**: Add SOPS for secret management
- **Nix Containers**: Add declarative containers as needed
- **Hardware-Specific Tweaks**: Framework-specific modules if needed
- **Additional Work Tools**: Add as requirements evolve
