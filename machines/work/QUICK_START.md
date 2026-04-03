# Work Laptop - Quick Start Guide

## Installation

### 1. Prepare Installation Media
```bash
# From another machine
nix build .#nixosConfigurations.isoInstaller.config.system.build.isoImage
# Flash to USB
```

### 2. Boot and Partition
```bash
# Boot from USB
# The disko config will handle partitioning automatically during install
```

### 3. Install NixOS
```bash
sudo nixos-install --flake github:alnav3/nixos#work
# Set root password when prompted
sudo reboot
```

### 4. First Boot Setup
```bash
# Login as alnav (password: default from base.nix)
# Change password
passwd

# Setup SSH keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# Copy your private keys to ~/.ssh/

# Setup Git
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"
git config --global user.signingkey "YOUR_KEY_ID"

# Test Docker (may need to logout/login first)
docker ps
```

## Common Commands

### System Updates
```bash
# Update system
update  # or: sudo nixos-rebuild switch --flake '/home/alnav/nixOS#work'

# Update flake inputs
update-flake nixpkgs

# Clean old generations
clean-disk
```

### VPN Connection

#### GUI Method (Recommended)
1. Open network settings (Super+V or system tray)
2. Add new VPN connection
3. Type: OpenConnect
4. Gateway: vpn.company.com
5. Enter credentials

#### Command Line Method
```bash
# List VPN connections
nmcli connection show

# Connect to VPN
nmcli connection up "VPN Name"

# Or use openconnect directly
sudo openconnect vpn.company.com
```

### Docker
```bash
# Run container
docker run -it ubuntu bash

# List containers
docker ps -a

# Cleanup
docker system prune
```

### Development

#### Node.js Projects
```bash
npm install
npm run dev
```

#### Go Projects
```bash
go mod download
go run main.go
```

#### Java Projects
```bash
mvn clean install
gradle build
```

#### Python Projects
```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Tmux
```bash
# Start tmux
tmux

# Common keybindings (prefix is Ctrl+b)
Ctrl+b c    # Create new window
Ctrl+b n/p  # Next/previous window
Ctrl+b %    # Split vertically
Ctrl+b "    # Split horizontally
Ctrl+b d    # Detach

# Reattach
tmux attach
```

### WiFi
```bash
# List networks
nmcli device wifi list

# Connect
nmcli device wifi connect "SSID" password "PASSWORD"

# Or use rofi
rofi-wifi
```

## Useful Paths

- **System config**: `/home/alnav/nixOS/machines/work/configuration.nix`
- **Hardware config**: `/home/alnav/nixOS/machines/work/hardware-configuration.nix`
- **SSH keys**: `~/.ssh/`
- **Docker data**: `/var/lib/docker/`
- **Syncthing**: `~/.config/syncthing/`

## Troubleshooting

### Docker Permission Denied
```bash
# Verify user in docker group
groups | grep docker

# If not, logout and login again
# Or: sudo usermod -aG docker $USER && newgrp docker
```

### VPN Won't Connect
```bash
# Check NetworkManager status
systemctl status NetworkManager

# Check OpenConnect
which openconnect
openconnect --version

# Try direct connection for debugging
sudo openconnect -v vpn.company.com
```

### WiFi Not Working
```bash
# Check device
ip link

# Check NetworkManager
nmcli device status

# Restart NetworkManager
sudo systemctl restart NetworkManager
```

### Battery Draining Fast
```bash
# Check TLP status
tlp-stat -s

# Check TLP settings
tlp-stat -c

# Check CPU frequency
watch -n1 'grep MHz /proc/cpuinfo'
```

### Bluetooth Issues
```bash
# Check Bluetooth service
systemctl status bluetooth

# Scan for devices
bluetoothctl
> scan on
> pair XX:XX:XX:XX:XX:XX
> connect XX:XX:XX:XX:XX:XX
```

## Hardware Adjustments

If you need to adjust for different hardware, edit:

### For Intel CPU
In `hardware-configuration.nix`:
```nix
boot.kernelModules = ["kvm-intel"];
hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
```

### For Intel GPU
In `configuration.nix`:
```nix
hardware.graphics.gpu = "intel";
```
And remove AMD-specific settings.

### For NVIDIA GPU
In `configuration.nix`:
```nix
hardware.graphics.gpu = "nvidia";
```

### For Different Disk
In `disko-config.nix`:
```nix
device = "/dev/sda";  # Instead of /dev/nvme0n1
```

## Customization

### Add More Packages
Edit `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  openconnect
  # ... existing packages
  your-package-here
];
```

### Change Wallpaper
```bash
# Wallpapers are in dotfiles
# Edit hyprland config or use hyprpaper
```

### Change Theme
In `configuration.nix`:
```nix
desktop.stylix = {
  theme = "catppuccin-mocha";  # or other theme
  polarity = "dark";  # or "light"
};
```

## Getting Help

- NixOS Manual: https://nixos.org/manual/nixos/stable/
- Home Flake: https://github.com/alnav3/nixos
- Hyprland Wiki: https://wiki.hyprland.org/
