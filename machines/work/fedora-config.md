# Fedora Workstation Configuration for Work Laptop

This document lists all system-level configuration that was removed from the Nix
config because it cannot be managed by Home Manager standalone. Each section
explains what was removed, why, and the commands to replicate it on Fedora.

## Table of Contents

1. [Install Nix and Home Manager](#1-install-nix-and-home-manager)
2. [Rebuild / Apply Configuration](#2-rebuild--apply-configuration)
3. [User and Shell Setup](#3-user-and-shell-setup)
4. [Hyprland Session](#4-hyprland-session)
5. [Docker](#5-docker)
6. [TLP / Power Management](#6-tlp--power-management)
7. [Bluetooth](#7-bluetooth)
8. [NetworkManager and VPN](#8-networkmanager-and-vpn)
9. [Firewall](#9-firewall)
10. [DNS (systemd-resolved)](#10-dns-systemd-resolved)
11. [IPv6 Disable](#11-ipv6-disable)
12. [SSH Server](#12-ssh-server)
13. [Kanata (Key Remapping)](#13-kanata-key-remapping)
14. [Intel GPU](#14-intel-gpu)
15. [Firmware Updates](#15-firmware-updates)
16. [Kernel Parameters](#16-kernel-parameters)
17. [Logind / Lid Behavior](#17-logind--lid-behavior)
18. [Udev Rules (Power Saving)](#18-udev-rules-power-saving)
19. [Polkit and Sudo](#19-polkit-and-sudo)
20. [GNOME Keyring](#20-gnome-keyring)
21. [XDG Portal](#21-xdg-portal)
22. [GVFS (for Pika Backup)](#22-gvfs-for-pika-backup)
23. [Chromium System Policy](#23-chromium-system-policy)

---

## 1. Install Nix and Home Manager

**What was removed:** The entire NixOS base system, Nix daemon configuration,
flakes enablement, binary cache settings.

**Why:** NixOS manages Nix natively. On Fedora, Nix must be installed as a
standalone package manager.

```bash
# Install Nix (multi-user, recommended)
sh <(curl -L https://nixos.org/nix/install) --daemon

# Enable flakes (add to ~/.config/nix/nix.conf or /etc/nix/nix.conf)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# (Optional) Add your binary cache for faster builds
# In /etc/nix/nix.conf (needs sudo):
#   trusted-substituters = ssh://mjolnir.home
#   trusted-public-keys = mjolnir.home:AE24oIg+8t8NWRQcjOHZuwHQiQG2QAzIcheHA/bliIY=
#   secret-key-files = /etc/nix/signing-key

# Install Home Manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
```

---

## 2. Rebuild / Apply Configuration

**What was removed:** `nixos-rebuild switch` workflow, `rebuild-remote` script.

**Why:** `nixos-rebuild` is NixOS-specific. Home Manager has its own switch command.

### Local rebuild (on the Fedora machine)

```bash
# Clone the repo (first time)
git clone --recurse-submodules <your-repo-url> ~/nixOS

# Apply the Home Manager configuration
home-manager switch --flake '/home/alnav/nixOS#alnav@work'

# Or use the alias (after first successful switch):
update
```

### Remote rebuild (from build host like mjolnir)

```bash
# Build the activation package on the build host
nix build '/home/alnav/nixOS#homeConfigurations.alnav@work.activationPackage' --print-out-paths

# Copy the closure to the target
nix copy --to ssh://work $(readlink -f ./result)

# Activate on the target via SSH
ssh work "$(readlink -f ./result)/activate"
```

---

## 3. User and Shell Setup

**What was removed:** `users.users.alnav` (user creation, groups, hashed
password, SSH keys), `users.defaultUserShell = pkgs.zsh`.

**Why:** User management is a system-level NixOS feature. Fedora manages users
via `useradd`/`usermod`.

```bash
# Add user to necessary groups
sudo usermod -aG wheel,docker,audio,input,disk,dialout,networkmanager,uinput alnav

# Install ZSH via DNF (needed in /etc/shells for chsh)
sudo dnf install -y zsh

# Set ZSH as default shell
chsh -s $(which zsh)

# Add SSH authorized key
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat >> ~/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiP2WKxf0TUiFAlb/rg/dpimYTpzMntD7UmUYQxxiVUt6OCg34iKgDHHiC+nK2nRMuy1viT84dR0qUiG9J+vLTVJ1nuBgg1HI5w/RJ3f7oKSmV2rSnK0jetGU8yeJ8H/9MmwYGQ6Oc2896q0IukojFc7ULRKr1/fMOFTNL9v++IwpuTL05D1OkVbpcB1rKM5vSjYEWen+1SBuQWW91BepyLwiX4CrLttaJyZIHUVYgtcUbAIcduduA4lkCrFHud4N93R1QqIXqf4WYew5OoxNjhXhLq6yJ9w+MvbmeCzqEgSkwSj9jFb97Se4FCHeeiV20Y6mM7/yeTC73i77w3DpnDPO0iYtNtcbZ1EmKOF2N7LXwW5jqZT8e/w4TbRFYJ+zfe0zWRO/27H3DSNPcb8LcEpYFNFQ+plgRRO9fBwLRhgHSVolU6JudOoe6g+TCUaR4CMV+xF/Ir6A6P5vwPR6Y1cTjufXrx/SdsfPNk5q1YK6qRxPxPt3tCNVGdO68psfDwpXxYxwUiPtytEvgenr1aXbauA4QqM1qMTOLa14Q/je5D5regg497RFXVjgLeQf3bDrhsSlaaHuARme9OkcKr8vyzIyPGIvmxvl6zlQBrBGHHKey1gMtB4QH/xeA8dLofD83p/Yl174omx+2L5XiP0QqfHu4T/cC0j1baGL2BQ== alnav@nixos
EOF
chmod 600 ~/.ssh/authorized_keys
```

---

## 4. Hyprland Session

**What was removed:** `programs.hyprland` (NixOS module that registers the
Wayland session, sets up XDG portals, and installs the package system-wide).

**Why:** The NixOS Hyprland module writes session files to system paths and
configures system-level XDG portals. On Fedora, we install Hyprland via Nix
`home.packages` but need a manual session file for GDM.

```bash
# Create a Hyprland session file for GDM
# Use the full path to the Nix-installed Hyprland binary
HYPRLAND_BIN=$(readlink -f $(which Hyprland))

sudo tee /usr/share/wayland-sessions/hyprland.desktop << EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=$HYPRLAND_BIN
Type=Application
DesktopNames=Hyprland
EOF

# After logging out, GDM should show "Hyprland" as a session option.
# Select it from the gear icon on the login screen.

# NOTE: After each `home-manager switch`, the Hyprland store path may change.
# You may need to re-run the above commands to update the session file.
# Alternatively, create a wrapper script:
sudo tee /usr/local/bin/start-hyprland << 'SCRIPT'
#!/bin/bash
exec /home/alnav/.nix-profile/bin/Hyprland "$@"
SCRIPT
sudo chmod +x /usr/local/bin/start-hyprland

# Then use Exec=/usr/local/bin/start-hyprland in the .desktop file.
```

---

## 5. Docker

**What was removed:** `virtualisation.docker` (daemon, socket activation,
battery-optimized settings, auto-prune, rootless mode).

**Why:** Docker requires a system daemon managed by systemd. Home Manager cannot
manage system services.

```bash
# Install Docker CE
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# Add user to docker group (already done in user setup)
sudo usermod -aG docker alnav

# --- Battery-optimized settings (from original NixOS config) ---

# Disable Docker starting on boot (socket-activated on demand)
sudo systemctl disable docker.service
sudo systemctl enable docker.socket

# Configure daemon for battery optimization
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "none",
  "log-level": "warn",
  "storage-driver": "overlay2",
  "live-restore": false,
  "default-ulimits": {
    "memlock": {
      "Hard": 67108864,
      "Name": "memlock",
      "Soft": 67108864
    }
  }
}
EOF

# --- Auto-prune (daily, aggressive) ---
# Create a systemd timer for Docker cleanup

sudo tee /etc/systemd/system/docker-prune.service << 'EOF'
[Unit]
Description=Docker system prune
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/docker system prune --all --force --volumes
EOF

sudo tee /etc/systemd/system/docker-prune.timer << 'EOF'
[Unit]
Description=Daily Docker system prune

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now docker-prune.timer

# Install distrobox (for container environments)
sudo dnf install -y distrobox
```

---

## 6. TLP / Power Management

**What was removed:** `services.tlp` (CPU governors, charge thresholds, WiFi
power saving, USB autosuspend, SATA link power, PCIe ASPM), `powerManagement`,
`services.thermald`, `services.power-profiles-daemon`.

**Why:** TLP is a system service with kernel-level power management. Cannot be
managed by Home Manager.

```bash
# Install TLP
sudo dnf install -y tlp tlp-rdw

# Disable power-profiles-daemon (conflicts with TLP)
sudo systemctl disable --now power-profiles-daemon.service
sudo systemctl mask power-profiles-daemon.service

# Enable TLP
sudo systemctl enable --now tlp.service

# Install thermald (Intel CPU)
sudo dnf install -y thermald
sudo systemctl enable --now thermald.service

# Configure TLP
sudo tee /etc/tlp.d/99-work-laptop.conf << 'EOF'
# CPU scaling governor
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# CPU frequency limits
CPU_SCALING_MIN_FREQ_ON_AC=1000000
CPU_SCALING_MAX_FREQ_ON_AC=3500000
CPU_SCALING_MIN_FREQ_ON_BAT=400000
CPU_SCALING_MAX_FREQ_ON_BAT=2000000

# CPU energy performance preference
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# CPU boost - disable on battery
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0

# Platform profiles
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=low-power

# Battery charge thresholds (40-80%)
START_CHARGE_THRESH_BAT0=40
STOP_CHARGE_THRESH_BAT0=80

# WiFi power saving
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
WOL_DISABLE=Y

# USB autosuspend
USB_AUTOSUSPEND=1
USB_BLACKLIST_BTUSB=0
USB_BLACKLIST_PHONE=0
USB_BLACKLIST_PRINTER=1
USB_BLACKLIST_WWAN=0

# Runtime PM
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto
RUNTIME_PM_ALL=1

# SATA link power
SATA_LINKPWR_ON_AC=med_power_with_dipm
SATA_LINKPWR_ON_BAT=min_power

# PCIe ASPM
PCIE_ASPM_ON_AC=performance
PCIE_ASPM_ON_BAT=powersupersave

# Disk power management
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"
DISK_SPINDOWN_TIMEOUT_ON_AC="0 0"
DISK_SPINDOWN_TIMEOUT_ON_BAT="24 24"
DISK_IOSCHED="mq-deadline mq-deadline"

# Audio power saving
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y

# Radeon/AMDGPU (Intel laptop, but set defaults anyway)
RADEON_DPM_STATE_ON_AC=performance
RADEON_DPM_STATE_ON_BAT=battery
RADEON_POWER_PROFILE_ON_AC=high
RADEON_POWER_PROFILE_ON_BAT=low
EOF

# Restart TLP to apply
sudo tlp start

# Install powertop for monitoring (also available via Nix home.packages)
sudo dnf install -y powertop
```

---

## 7. Bluetooth

**What was removed:** `hardware.bluetooth` (enable, power management settings,
experimental features), `services.blueman`, udev rules for smart power
management, systemd services for battery-aware bluetooth on/off.

**Why:** Bluetooth hardware configuration and system services require root and
systemd system-level units.

```bash
# Bluetooth should already be working on Fedora. Configure it:

# Install Blueman (GTK Bluetooth manager)
sudo dnf install -y blueman

# Configure Bluetooth settings
sudo tee /etc/bluetooth/main.conf.d/99-work.conf << 'EOF'
[General]
Enable=Source,Sink,Media,Socket
Experimental=true
FastConnectable=false
DiscoverableTimeout=0
EOF

# Restart Bluetooth
sudo systemctl restart bluetooth.service

# (Optional) Smart Bluetooth power management - disable on battery if no devices
# Create the script:
sudo tee /usr/local/bin/smart-bluetooth.sh << 'SCRIPT'
#!/bin/bash
set -e

check_power_source() {
    if [ -f /sys/class/power_supply/ACAD/online ]; then
        cat /sys/class/power_supply/ACAD/online
    else
        find /sys/class/power_supply -name "A*" -type d -exec cat {}/online \; 2>/dev/null | head -1 || echo "0"
    fi
}

count_connected_devices() {
    bluetoothctl devices Connected 2>/dev/null | wc -l
}

power_source=$(check_power_source)

if [ "$power_source" = "1" ]; then
    systemctl start bluetooth.service 2>/dev/null || true
    sleep 2
    bluetoothctl power on 2>/dev/null || true
else
    systemctl start bluetooth.service 2>/dev/null || true
    sleep 3
    connected_devices=$(count_connected_devices)
    if [ "$connected_devices" -eq 0 ]; then
        bluetoothctl power off 2>/dev/null || true
    fi
fi
SCRIPT
sudo chmod +x /usr/local/bin/smart-bluetooth.sh

# Create systemd service for it
sudo tee /etc/systemd/system/smart-bluetooth.service << 'EOF'
[Unit]
Description=Smart Bluetooth Power Management

[Service]
Type=oneshot
ExecStart=/usr/local/bin/smart-bluetooth.sh
RemainAfterExit=false
EOF

# Create udev rules to trigger on AC/battery changes
sudo tee /etc/udev/rules.d/99-bluetooth-power.rules << 'EOF'
SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="/usr/bin/systemctl start smart-bluetooth.service"
SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="/usr/bin/systemctl start smart-bluetooth.service"
EOF

sudo udevadm control --reload-rules
```

---

## 8. NetworkManager and VPN

**What was removed:** `networking.networkmanager` (enable, plugins for OpenVPN
and OpenConnect), `networking.useDHCP`, `networking.firewall.checkReversePath`.

**Why:** NetworkManager is a system service. VPN plugins integrate at the system
level.

```bash
# NetworkManager is already the default on Fedora Workstation

# Install VPN plugins
sudo dnf install -y NetworkManager-openvpn NetworkManager-openvpn-gnome \
                     NetworkManager-openconnect NetworkManager-openconnect-gnome \
                     openconnect

# Disable reverse path check (for VPN compatibility)
sudo tee /etc/sysctl.d/99-vpn.conf << 'EOF'
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
EOF
sudo sysctl --system
```

---

## 9. Firewall

**What was removed:** `networking.firewall` (enable, allowed TCP ports 80, 443,
8080).

**Why:** Fedora uses `firewalld` instead of NixOS's iptables-based firewall.

```bash
# Fedora uses firewalld by default
sudo systemctl enable --now firewalld

# Open required ports
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=8080/tcp

# Open Syncthing ports (22000 TCP, 21027 UDP)
sudo firewall-cmd --permanent --add-port=22000/tcp
sudo firewall-cmd --permanent --add-port=21027/udp

# Open LocalSend port (53317)
sudo firewall-cmd --permanent --add-port=53317/tcp
sudo firewall-cmd --permanent --add-port=53317/udp

# Reload
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-all
```

---

## 10. DNS (systemd-resolved)

**What was removed:** `services.resolved` (enable, DNSSEC, fallback DNS servers
9.9.9.9 and 149.112.112.112).

**Why:** DNS resolver configuration is system-level.

```bash
# systemd-resolved should already be running on Fedora

# Configure it
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/99-work.conf << 'EOF'
[Resolve]
DNS=9.9.9.9 149.112.112.112
FallbackDNS=9.9.9.9 149.112.112.112
DNSSEC=false
Domains=~.
EOF

# Restart
sudo systemctl restart systemd-resolved
```

---

## 11. IPv6 Disable

**What was removed:** `boot.kernel.sysctl` (disable IPv6 on all interfaces,
disable autoconf and router advertisements).

**Why:** Kernel sysctl parameters require root.

```bash
sudo tee /etc/sysctl.d/99-disable-ipv6.conf << 'EOF'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.default.autoconf=0
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0
EOF

sudo sysctl --system
```

---

## 12. SSH Server

**What was removed:** `services.openssh` (enable, port 22, key-only auth, no
root login, no password auth).

**Why:** SSH is a system service.

```bash
sudo dnf install -y openssh-server

# Configure SSH
sudo tee /etc/ssh/sshd_config.d/99-work.conf << 'EOF'
Port 22
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
EOF

sudo systemctl enable --now sshd
```

---

## 13. Kanata (Key Remapping)

**What was removed:** `services.kanata` (caps-lock as tap-hold esc/ctrl, n as
tap-hold n/ñ).

**Why:** Kanata needs access to `/dev/input/` devices which requires either root
or uinput group membership and a system service.

```bash
# Install Kanata
sudo dnf copr enable -y alternateved/kanata
sudo dnf install -y kanata

# Or download from GitHub releases:
# https://github.com/jtroo/kanata/releases

# Create config
mkdir -p ~/.config/kanata
tee ~/.config/kanata/config.kbd << 'EOF'
(defcfg
  process-unmapped-keys yes
)

(defsrc
  caps
  n
)

(defalias
  caps (tap-hold 175 175 esc lctl)
  n (tap-hold 200 200 n (unicode ñ))
)

(deflayer base
  @caps
  @n
)
EOF

# Create systemd service
sudo tee /etc/systemd/system/kanata.service << 'EOF'
[Unit]
Description=Kanata key remapping daemon
After=local-fs.target

[Service]
Type=simple
ExecStart=/usr/bin/kanata -c /home/alnav/.config/kanata/config.kbd --device /dev/input/by-path/platform-i8042-serio-0-event-kbd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Ensure user has uinput access
sudo usermod -aG uinput alnav
echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput"' | sudo tee /etc/udev/rules.d/99-uinput.rules
sudo udevadm control --reload-rules

sudo systemctl daemon-reload
sudo systemctl enable --now kanata.service
```

---

## 14. Intel GPU

**What was removed:** `hardware.graphics` (enable, Intel VA-API driver,
intel-gpu-tools), `services.xserver.videoDrivers = ["modesetting"]`,
`hardware.intel-gpu-tools.enable`.

**Why:** GPU drivers are kernel/system level. Fedora already ships Intel GPU
support.

```bash
# Intel GPU drivers should work out of the box on Fedora

# Install VA-API support (hardware video acceleration)
sudo dnf install -y intel-media-driver libva-utils

# Install Intel GPU tools (optional, for debugging)
sudo dnf install -y intel-gpu-tools

# Verify VA-API is working
vainfo

# The LIBVA_DRIVER_NAME=iHD session variable is already set in
# the Home Manager config (home.sessionVariables).
```

---

## 15. Firmware Updates

**What was removed:** `services.fwupd.enable = true`.

**Why:** fwupd is a system service.

```bash
# fwupd is already installed on Fedora Workstation
sudo systemctl enable --now fwupd.service

# Check for firmware updates
fwupdmgr get-updates
fwupdmgr update
```

---

## 16. Kernel Parameters

**What was removed:** `boot.kernelPackages = pkgs.linuxPackages_latest`,
`boot.kernelParams` (pcie_aspm, acpi_osi, processor.max_cstate, nowatchdog,
snd_hda_intel.power_save, resume device), `boot.blacklistedKernelModules`,
`boot.kernel.sysctl` (vm.dirty_*, vm.laptop_mode, vm.swappiness,
net.core.default_qdisc, kernel.nmi_watchdog).

**Why:** Kernel and boot configuration is system-level.

```bash
# Add kernel parameters via GRUB
# Edit /etc/default/grub and add to GRUB_CMDLINE_LINUX:
sudo sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 pcie_aspm=force pcie_aspm.policy=powersupersave acpi_osi=Linux processor.max_cstate=5 intel_idle.max_cstate=5 ahci.mobile_lpm_policy=3 nowatchdog nmi_watchdog=0 snd_hda_intel.power_save=1"/' /etc/default/grub

# Regenerate GRUB config
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Blacklist noisy kernel modules
echo "blacklist pcspkr" | sudo tee /etc/modprobe.d/blacklist-pcspkr.conf
echo "blacklist snd_pcsp" | sudo tee /etc/modprobe.d/blacklist-snd_pcsp.conf

# Kernel sysctl for power saving and performance
sudo tee /etc/sysctl.d/99-power-saving.conf << 'EOF'
vm.dirty_background_ratio=15
vm.dirty_ratio=40
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=1500
vm.laptop_mode=5
vm.swappiness=10
net.core.default_qdisc=fq_codel
kernel.nmi_watchdog=0
EOF

sudo sysctl --system
```

---

## 17. Logind / Lid Behavior

**What was removed:** `services.logind.settings.Login` (HandleLidSwitch =
suspend-then-hibernate, HandleLidSwitchExternalPower = lock, HandlePowerKey =
suspend-then-hibernate, IdleAction, IdleActionSec).

**Why:** Logind is a system service.

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/99-work.conf << 'EOF'
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=lock
HandlePowerKey=suspend-then-hibernate
IdleAction=suspend-then-hibernate
IdleActionSec=20min
EOF

# Configure suspend-then-hibernate delay
sudo mkdir -p /etc/systemd/sleep.conf.d
sudo tee /etc/systemd/sleep.conf.d/99-work.conf << 'EOF'
[Sleep]
HibernateDelaySec=1800s
EOF

sudo systemctl restart systemd-logind
```

---

## 18. Udev Rules (Power Saving)

**What was removed:** `services.udev.extraRules` (USB/PCI/sound autosuspend,
WiFi power save on wireless interfaces).

**Why:** Udev rules require root.

```bash
sudo tee /etc/udev/rules.d/99-power-saving.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="auto"
ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
ACTION=="add", SUBSYSTEM=="sound", ATTR{power/control}="auto"
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wl*", RUN+="/usr/sbin/iw dev %k set power_save on"
EOF

sudo udevadm control --reload-rules
```

---

## 19. Polkit and Sudo

**What was removed:** `security.polkit.enable`, `security.sudo.extraRules`
(NOPASSWD for alnav).

**Why:** Security configuration is system-level.

```bash
# Polkit is already enabled on Fedora Workstation

# Passwordless sudo (if desired - OPTIONAL, security risk)
echo "alnav ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/99-alnav
sudo chmod 440 /etc/sudoers.d/99-alnav

# Verify
sudo -n true && echo "Passwordless sudo works" || echo "Requires password"
```

---

## 20. GNOME Keyring

**What was removed:** `services.gnome.gnome-keyring.enable`.

**Why:** System service.

```bash
# GNOME Keyring is already installed on Fedora Workstation (comes with GNOME)
# It should work automatically. If not:
sudo dnf install -y gnome-keyring seahorse
```

---

## 21. XDG Portal

**What was removed:** `xdg.portal` (enable, xdg-desktop-portal-gtk).

**Why:** XDG desktop portals are system-level D-Bus services.

```bash
# xdg-desktop-portal and xdg-desktop-portal-gtk are already on Fedora

# For Hyprland, you need the Hyprland portal.
# It's installed via Nix home.packages, but needs to be discoverable.
# Add to your Hyprland config (hyprland.conf) or environment:
# exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

# The Nix-installed portals may not be picked up by the system D-Bus.
# If screen sharing doesn't work, install the system package too:
sudo dnf install -y xdg-desktop-portal-hyprland
```

---

## 22. GVFS (for Pika Backup)

**What was removed:** `services.gvfs` (needed by Pika Backup for remote
backup locations).

**Why:** GVFS is a system service.

```bash
# GVFS is already installed on Fedora Workstation (comes with GNOME)
sudo dnf install -y gvfs gvfs-smb gvfs-fuse
```

---

## 23. Chromium System Policy

**What was removed:** `environment.etc."chromium/policies/managed/extensions.json"`
(system-wide Chromium extension policy allowing all extensions).

**Why:** System-wide policies go in `/etc/` which requires root. A user-level
version is set in the Home Manager config at
`~/.config/chromium/policies/managed/`, but some Chromium builds only read
system-level policies.

```bash
# If user-level policy doesn't work, create system-level:
sudo mkdir -p /etc/chromium/policies/managed
sudo tee /etc/chromium/policies/managed/extensions.json << 'EOF'
{
  "ExtensionSettings": {
    "*": {
      "allowed_types": ["extension", "theme", "user_script"],
      "blocked_install_message": "Extensions are allowed.",
      "install_sources": ["*"],
      "installation_mode": "allowed"
    }
  },
  "ExtensionInstallBlocklist": [],
  "ExtensionInstallAllowlist": ["*"]
}
EOF
```

---

## Notes

### GUI Apps and OpenGL

Some Nix-installed graphical applications may have issues with OpenGL/Vulkan on
non-NixOS systems because they link against Nix's Mesa instead of the system's
GPU drivers. If you encounter graphical glitches or apps failing to start:

```bash
# Install nixGL for wrapping GPU-accelerated Nix apps
nix profile install github:nix-community/nixGL

# Run problematic apps with:
nixGL <app-name>

# Or nixVulkan for Vulkan apps:
nixVulkanIntel <app-name>
```

### NetworkManager WiFi Power Saving

The original config set `networking.networkmanager.wifi.powersave = true`. To
replicate:

```bash
sudo tee /etc/NetworkManager/conf.d/99-wifi-powersave.conf << 'EOF'
[connection]
wifi.powersave=3
EOF
sudo systemctl restart NetworkManager
```

### Journal Size Limit

The original config limited systemd journal size to reduce disk writes:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/99-size.conf << 'EOF'
[Journal]
SystemMaxUse=50M
RuntimeMaxUse=50M
SystemMaxFileSize=10M
EOF
sudo systemctl restart systemd-journald
```

### NTP Polling Frequency

Reduce NTP polling to save power:

```bash
sudo mkdir -p /etc/systemd/timesyncd.conf.d
sudo tee /etc/systemd/timesyncd.conf.d/99-power.conf << 'EOF'
[Time]
PollIntervalMinSec=300
PollIntervalMaxSec=3600
EOF
sudo systemctl restart systemd-timesyncd
```

### Weekly TRIM

```bash
# Fedora should already have fstrim.timer enabled
sudo systemctl enable --now fstrim.timer
```
