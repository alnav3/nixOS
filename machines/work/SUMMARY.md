# Work Laptop - Configuration Summary

## ✅ What's Configured

### Base System
- ✅ SSH server with public key authentication
- ✅ `alnav` user with standard groups + `docker`
- ✅ Mjolnir build cache configured (key needs manual setup)
- ✅ Nix with flakes enabled
- ✅ Latest Linux kernel

### Desktop Environment
- ✅ Hyprland window manager
- ✅ Stylix theming (Catppuccin Mocha)
- ✅ Auto-login to Hyprland
- ✅ Browser (Zen via desktop module)
- ✅ File manager, notifications, screenshots
- ✅ Kitty terminal
- ✅ Rofi launcher

### Development Tools
- ✅ **Languages**: Go, Node.js, Java, Python, Nix
- ✅ **Shell**: ZSH with plugins
- ✅ **Editor**: Neovim with Java support
- ✅ **Terminal**: tmux
- ✅ **Version Control**: Git with GitLab CLI
- ✅ **API Testing**: Bruno
- ✅ **Infrastructure**: 
  - Docker (enabled, user has permissions)
  - Kubernetes tools (kubectl, helm)
  - Docker Compose
  - Distrobox
- ✅ **Databases**: PostgreSQL, Turso CLI, DBeaver

### Work Applications
- ✅ Teams for Linux (unfree exception granted)
- ✅ Bruno (API testing)
- ✅ Thunderbird (email)
- ✅ Zathura (PDF viewer)
- ✅ OpenSnitch (application firewall)

### VPN & Networking
- ✅ NetworkManager enabled
- ✅ OpenConnect VPN client
- ✅ NetworkManager OpenConnect plugin
- ✅ WiFi and Bluetooth support
- ✅ DNS with systemd-resolved
- ✅ IPv6 disabled
- ✅ Firewall enabled (ports 80, 443, 8080)

### Hardware Optimization
- ✅ Battery management with TLP
- ✅ Charge thresholds (40-80%)
- ✅ CPU frequency scaling (conservative for battery)
- ✅ Bluetooth power management (disabled on battery)
- ✅ Suspend-then-hibernate on lid close
- ✅ AMD GPU support (configurable for Intel/NVIDIA)

### Backup & Sync
- ✅ Syncthing enabled
- ✅ Pika Backup

### Security
- ✅ Firewall enabled
- ✅ SSH key-only authentication
- ✅ OpenSnitch application firewall
- ✅ Disk encryption via LUKS (in disko config)

## ❌ What's NOT Included (Unlike Framework)

### Gaming (All Disabled)
- ❌ Steam
- ❌ Lutris, Heroic, Bottles
- ❌ Emulators (Switch, etc.)
- ❌ MangoHUD, ProtonGE
- ❌ 32-bit graphics support

### Entertainment
- ❌ MPV video player
- ❌ Jellyfin
- ❌ Music streaming (Finamp, Soulseek)
- ❌ YouTube downloaders (yt-dlp, Grayjay)
- ❌ Streaming rippers (Streamrip)
- ❌ Media casting (fcast)

### Social & Communication (Non-Work)
- ❌ Discord
- ❌ Signal
- ❌ Telegram
- ❌ TeamSpeak

### Other
- ❌ 3D printing tools
- ❌ Media conversion tools (thorium, kcc)
- ❌ ProtonVPN GUI (OpenConnect for corporate VPN instead)
- ❌ Transmission (torrent client)
- ❌ QEMU/libvirt (can enable if needed)

## 🔒 SOPS Secrets NOT Configured

The following secrets are used in Framework but **NOT** in Work laptop:

1. **WiFi passwords**: Configure via NetworkManager GUI
2. **VPN credentials**: Will be prompted by OpenConnect
3. **Email config**: Configure Thunderbird manually
4. **Mjolnir build key** (`/etc/nix/signing-key`): Add manually or enable SOPS

## 📝 Post-Installation Tasks

1. Generate actual hardware config:
   ```bash
   nixos-generate-config --root /mnt
   cp /mnt/etc/nixos/hardware-configuration.nix /home/alnav/nixOS/machines/work/
   ```

2. Verify/adjust hardware settings:
   - CPU type (AMD vs Intel)
   - GPU type (AMD vs Intel vs NVIDIA)
   - Disk device path
   - Swap size
   - Keyboard device for Kanata

3. Setup credentials:
   - Copy SSH private keys
   - Configure Git signing keys
   - Setup corporate VPN
   - Configure Thunderbird

4. Verify Docker:
   ```bash
   docker ps  # Should work without sudo
   ```

## 🔧 Key Configuration Files

- `configuration.nix`: Main system configuration
- `hardware-configuration.nix`: Auto-generated hardware settings
- `disko-config.nix`: Disk partitioning (LUKS + Btrfs)
- `README.md`: Detailed documentation
- `SUMMARY.md`: This file

## 🎯 Design Goals Achieved

✅ No non-free software (except Teams for work)
✅ No entertainment applications
✅ Corporate VPN support (OpenConnect)
✅ Docker with user permissions
✅ SSH, base user, build cache all configured
✅ Same desktop experience as Framework (Hyprland + tmux)
✅ Battery optimizations
✅ WiFi/Bluetooth support
✅ Professional work environment
