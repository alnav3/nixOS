# Deploy-All Setup Guide

## Overview

The `deploy-all` command provides a comprehensive deployment solution for your NixOS framework that:

1. Updates flakes
2. Wakes up mjolnir if sleeping
3. Prevents mjolnir from sleeping during deployment
4. Rebuilds framework, node0, mjolnir, and optionally deck
5. Asks for confirmation to rebuild router (with 2-minute timeout)
6. Reboots mjolnir after completion

## Quick Setup

### 1. Generate Configuration File (Easiest Way!)

Run the setup helper to automatically detect MAC addresses and create the configuration:

```bash
# Rebuild your framework first to get the new commands
sudo nixos-rebuild switch --flake .#framework

# Run the setup helper - it will automatically detect MAC addresses
deploy-config-setup
```

This will create `.deploy/config` with your actual MAC addresses and optimal wake method.

### 2. Manual Configuration (Alternative)

If the automatic setup doesn't work, you can manually create/edit `.deploy/config`:

```bash
# Create the directory
mkdir -p /home/alnav/nixOS/.deploy

# Edit the config file (example provided in the repo)
nano /home/alnav/nixOS/.deploy/config
```

## Configuration File Format

The `.deploy/config` file uses a format similar to SSH config:

```bash
# Host-specific settings
Host mjolnir
    MACAddress aa:bb:cc:dd:ee:ff
    WakeMethod wakeonlan
    WakeTimeout 60
    BuildHost true

Host deck  
    MACAddress aa:bb:cc:dd:ee:gg
    WakeMethod wakeonlan
    WakeTimeout 30
    Optional true

# Global settings
Global
    LogDirectory /home/alnav/nixOS
    VerboseByDefault false
    DefaultWakeMethod wakeonlan
```

### Supported Wake Methods

- **wakeonlan**: Uses the `wakeonlan` command (recommended)
- **etherwake**: Uses the `etherwake` command
- **ssh**: Attempts SSH connection to wake the host
- **none**: Disables wake attempts for this host

## Additional Prerequisites

### 1. SSH Key Setup

Ensure you have passwordless SSH access to all hosts:
```bash
# Generate SSH key if not exists
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy to all hosts
ssh-copy-id mjolnir
ssh-copy-id node0
ssh-copy-id deck
ssh-copy-id router
```

### 2. Sudo Configuration

Ensure your user can run sudo commands on mjolnir without password:
```bash
# On mjolnir, add to /etc/sudoers (use 'sudo visudo'):
your_username ALL=(ALL) NOPASSWD: /bin/systemd-inhibit
your_username ALL=(ALL) NOPASSWD: /sbin/reboot
```

### 3. Wake-on-LAN Tool Installation

Install a wake-on-LAN tool (if `deploy-config-setup` recommends it):
```bash
# Option A: Install wakeonlan
nix-env -i wakeonlan

# Option B: Add to your system packages in configuration.nix
environment.systemPackages = [ pkgs.wakeonlan ];
```

### 4. Hardware Wake-on-LAN Setup

Ensure Wake-on-LAN is enabled in BIOS/UEFI and network interface:
```bash
# Check if interface supports WoL
sudo ethtool <interface_name>

# Enable WoL (if supported)
sudo ethtool -s <interface_name> wol g
```

## Usage

### Basic Usage
```bash
deploy-all
```

### Verbose Mode (shows all rebuild output)
```bash
deploy-all -v
```

### Help
```bash
deploy-all -h
```

## What the Script Does

1. **Flake Update**: Updates all flake inputs to latest versions
2. **Mjolnir Check**: Pings mjolnir and wakes it if unreachable
3. **Sleep Prevention**: Runs systemd-inhibit in a tmux session on mjolnir
4. **Sequential Rebuilds**: 
   - framework (local host)
   - node0 (remote via mjolnir build host)
   - mjolnir (self-rebuild)
   - deck (if reachable)
5. **Router Confirmation**: 2-minute timeout for router rebuild confirmation
6. **Cleanup**: Stops sleep inhibitor and reboots mjolnir

## Logs

All operations are logged to `deploy-YYYYMMDD_HHMMSS.log` in your nixOS directory.

- Without `-v`: Only shows progress and errors
- With `-v`: Shows full rebuild output
- Logs always contain full details regardless of verbosity

## Error Handling

- Script stops on any rebuild failure
- Automatic cleanup of sleep inhibitor on errors
- Detailed error messages with log file references
- Safe timeout handling for router confirmation

## Customization

Edit `/home/alnav/nixOS/pkgs/deploy-all.nix` to modify:
- Timeout values (WAKE_TIMEOUT, ROUTER_TIMEOUT)
- Host lists
- Wake-on-LAN commands
- Log format

## Troubleshooting

### Configuration Issues
```bash
# Regenerate configuration if MAC addresses are wrong
deploy-config-setup

# Check current configuration
cat /home/alnav/nixOS/.deploy/config

# Test configuration parsing
deploy-all --help  # Should show no config errors
```

### Wake-on-LAN Issues
```bash
# Check if MAC address is correct
ssh mjolnir "ip link show | grep -A1 'state UP'"

# Test wakeonlan manually
wakeonlan aa:bb:cc:dd:ee:ff

# Check if WoL is enabled in hardware
sudo ethtool <interface> | grep -i wake
```

### SSH Connection Issues
```bash
# Test manual SSH
ssh mjolnir

# Check SSH key permissions
ls -la ~/.ssh/

# Verify SSH agent
ssh-add -l
```

### Rebuild Failures
1. Check the detailed log file mentioned in error output
2. Test rebuild manually: `rebuild-remote <hostname>`
3. Verify build host (mjolnir) has sufficient resources

### Router Timeout
- Default timeout is configurable in `.deploy/config`
- Press 'y' quickly when prompted
- Increase `ConfirmationTimeout` value if needed

## Commands Summary

```bash
# Initial setup
sudo nixos-rebuild switch --flake .#framework
deploy-config-setup

# Daily usage
deploy-all                    # Standard deployment
deploy-all -v                 # Verbose deployment  
deploy-all -h                 # Help

# Configuration management
deploy-config-setup           # Regenerate config
nano .deploy/config           # Edit manually
```