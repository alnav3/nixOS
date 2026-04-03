{ pkgs, ... }:

pkgs.writeShellScriptBin "deploy-config-setup" ''
  # Deploy configuration setup helper
  # Generates .deploy/config with actual MAC addresses from remote hosts
  
  set -euo pipefail
  
  REPO_DIR="/home/alnav/nixOS"
  CONFIG_DIR="''${REPO_DIR}/.deploy"
  CONFIG_FILE="''${CONFIG_DIR}/config"
  
  # Create config directory if it doesn't exist
  mkdir -p "''${CONFIG_DIR}"
  
  log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  }
  
  get_mac_address() {
    local host="$1"
    log "Getting MAC address for ''${host}..."
    
    local mac_addr
    if mac_addr=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "''${host}" "ip link show | grep -A1 'state UP' | grep -o '[[:xdigit:]]\{2\}:[[:xdigit:]]\{2\}:[[:xdigit:]]\{2\}:[[:xdigit:]]\{2\}:[[:xdigit:]]\{2\}:[[:xdigit:]]\{2\}' | head -1" 2>/dev/null); then
      echo "''${mac_addr}"
      return 0
    else
      log "Warning: Could not connect to ''${host} or get MAC address"
      echo "00:00:00:00:00:00"
      return 1
    fi
  }
  
  check_wake_method() {
    if command -v wakeonlan >/dev/null 2>&1; then
      echo "wakeonlan"
    elif command -v etherwake >/dev/null 2>&1; then
      echo "etherwake"  
    else
      echo "ssh"
    fi
  }
  
  main() {
    log "Setting up deploy configuration..."
    log "Config file: ''${CONFIG_FILE}"
    
    # Get MAC addresses
    local mjolnir_mac deck_mac
    mjolnir_mac=$(get_mac_address "mjolnir")
    deck_mac=$(get_mac_address "deck")
    
    # Determine best wake method
    local wake_method
    wake_method=$(check_wake_method)
    log "Detected wake method: ''${wake_method}"
    
    # Generate config file
    cat > "''${CONFIG_FILE}" <<EOF
# Deploy-all configuration file
# Generated on $(date)
# Similar to ~/.ssh/config but for deployment settings
#
# This file contains MAC addresses for Wake-on-LAN and other deployment settings

Host mjolnir
    MACAddress ''${mjolnir_mac}
    WakeMethod ''${wake_method}
    WakeTimeout 60
    BuildHost true
    
Host deck
    MACAddress ''${deck_mac}
    WakeMethod ''${wake_method}
    WakeTimeout 30
    Optional true
    
Host node0
    # Node0 might not need wake-on-LAN if it's always on
    WakeMethod none
    
Host router
    WakeMethod none
    ConfirmationTimeout 120
    # Router rebuilds require confirmation due to network interruption
    
# Global settings
Global
    LogDirectory ''${REPO_DIR}
    VerboseByDefault false
    RepoDirectory ''${REPO_DIR}
    DefaultWakeMethod ''${wake_method}
    DefaultWakeTimeout 60
EOF
    
    log "✓ Configuration file generated: ''${CONFIG_FILE}"
    log ""
    log "Summary:"
    log "  mjolnir MAC: ''${mjolnir_mac}"
    log "  deck MAC: ''${deck_mac}"
    log "  Wake method: ''${wake_method}"
    log ""
    
    if [[ "''${mjolnir_mac}" == "00:00:00:00:00:00" ]] || [[ "''${deck_mac}" == "00:00:00:00:00:00" ]]; then
      log "⚠ Warning: Some MAC addresses could not be detected."
      log "   Please edit ''${CONFIG_FILE} manually and replace 00:00:00:00:00:00"
      log "   with the actual MAC addresses."
      log ""
      log "   To get MAC addresses manually:"
      log "     ssh mjolnir \"ip link show | grep -A1 'state UP'\""
      log "     ssh deck \"ip link show | grep -A1 'state UP'\""
    fi
    
    if [[ "''${wake_method}" == "ssh" ]]; then
      log "⚠ Warning: No wakeonlan or etherwake commands found."
      log "   Install wakeonlan for better Wake-on-LAN support:"
      log "     nix-env -i wakeonlan"
      log "   Or add wakeonlan to your system packages."
    fi
    
    log ""
    log "You can now run: deploy-all"
  }
  
  main "$@"
''