{ pkgs, ... }:

pkgs.writeShellScriptBin "deploy-all" ''
  # Comprehensive deployment script for NixOS framework
  # Usage: deploy-all [-v|--verbose]
  # 
  # This script:
  # 1. Updates flakes
  # 2. Wakes up mjolnir if sleeping
  # 3. Prevents mjolnir from sleeping during deployment
  # 4. Rebuilds framework, node0, mjolnir, and optionally deck
  # 5. Asks for confirmation to rebuild router (with 2-min timeout)
  # 6. Reboots mjolnir after completion

  set -euo pipefail

  # Configuration
  SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
  REPO_DIR="/home/alnav/nixOS"
  CONFIG_DIR="''${REPO_DIR}/.deploy"
  CONFIG_FILE="''${CONFIG_DIR}/config"
  LOG_FILE="''${REPO_DIR}/deploy-$(date +%Y%m%d_%H%M%S).log"
  VERBOSE=false
  MJOLNIR_HOST="mjolnir"
  WAKE_TIMEOUT=60
  ROUTER_TIMEOUT=120
  
  # Host configuration arrays (will be populated from config file)
  declare -A HOST_MAC_ADDRESS
  declare -A HOST_WAKE_METHOD
  declare -A HOST_WAKE_TIMEOUT
  declare -A HOST_OPTIONAL

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      -h|--help)
        echo "Usage: $0 [-v|--verbose] [-h|--help]"
        echo ""
        echo "Options:"
        echo "  -v, --verbose    Show verbose output including rebuild logs"
        echo "  -h, --help       Show this help message"
        echo ""
        echo "This script performs a complete deployment of all NixOS hosts:"
        echo "  1. Updates flakes"
        echo "  2. Wakes up mjolnir if needed"
        echo "  3. Rebuilds framework, node0, mjolnir, and deck (if available)"
        echo "  4. Optionally rebuilds router (with confirmation)"
        echo ""
        echo "All logs are saved to deploy-YYYYMMDD_HHMMSS.log"
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        echo "Use -h or --help for usage information"
        exit 1
        ;;
    esac
  done

  # Configuration parsing
  parse_config() {
    if [[ ! -f "''${CONFIG_FILE}" ]]; then
      log "ERROR: Configuration file not found: ''${CONFIG_FILE}"
      log "Run 'deploy-config-setup' first to generate the configuration"
      exit 1
    fi
    
    local current_host=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip empty lines and comments
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      
      # Remove leading/trailing whitespace
      line=$(echo "$line" | xargs)
      
      # Parse Host sections
      if [[ "$line" =~ ^Host[[:space:]]+([^[:space:]]+) ]]; then
        current_host="''${BASH_REMATCH[1]}"
        continue
      fi
      
      # Parse Global section
      if [[ "$line" =~ ^Global ]]; then
        current_host="Global"
        continue
      fi
      
      # Parse configuration options
      if [[ -n "$current_host" && "$line" =~ ^([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
        local key="''${BASH_REMATCH[1]}"
        local value="''${BASH_REMATCH[2]}"
        
        case "$current_host" in
          Global)
            case "$key" in
              LogDirectory) REPO_DIR="$value" ;;
              VerboseByDefault) [[ "$value" =~ ^(true|yes|1)$ ]] && VERBOSE=true ;;
              DefaultWakeTimeout) WAKE_TIMEOUT="$value" ;;
              ConfirmationTimeout) ROUTER_TIMEOUT="$value" ;;
            esac
            ;;
          *)
            case "$key" in
              MACAddress) HOST_MAC_ADDRESS["$current_host"]="$value" ;;
              WakeMethod) HOST_WAKE_METHOD["$current_host"]="$value" ;;
              WakeTimeout) HOST_WAKE_TIMEOUT["$current_host"]="$value" ;;
              Optional) [[ "$value" =~ ^(true|yes|1)$ ]] && HOST_OPTIONAL["$current_host"]=true ;;
              ConfirmationTimeout) [[ "$current_host" == "router" ]] && ROUTER_TIMEOUT="$value" ;;
            esac
            ;;
        esac
      fi
    done < "''${CONFIG_FILE}"
    
    # Update log file path based on config
    LOG_FILE="''${REPO_DIR}/deploy-$(date +%Y%m%d_%H%M%S).log"
  }

  # Logging functions
  log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" | tee -a "''${LOG_FILE}"
  }

  log_verbose() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" >> "''${LOG_FILE}"
    if [[ "''${VERBOSE}" == "true" ]]; then
      echo "[$timestamp] $*"
    fi
  }

  execute_command() {
    local cmd="$1"
    local description="$2"
    local show_output="''${3:-false}"
    
    log "''${description}..."
    log_verbose "Executing: ''${cmd}"
    
    if [[ "''${show_output}" == "true" ]] || [[ "''${VERBOSE}" == "true" ]]; then
      if ! eval "''${cmd}" 2>&1 | tee -a "''${LOG_FILE}"; then
        log "ERROR: ''${description} failed!"
        log "Check ''${LOG_FILE} for details"
        exit 1
      fi
    else
      if ! eval "''${cmd}" >> "''${LOG_FILE}" 2>&1; then
        log "ERROR: ''${description} failed!"
        log "Command output:"
        tail -20 "''${LOG_FILE}"
        log "Full log available at: ''${LOG_FILE}"
        exit 1
      fi
    fi
    
    log "✓ ''${description} completed successfully"
  }

  # Check if host is reachable
  check_host_reachable() {
    local host="$1"
    local timeout="''${2:-5}"
    
    if ping -c 1 -W "''${timeout}" "''${host}" >/dev/null 2>&1; then
      return 0
    else
      return 1
    fi
  }

  # Wake up a host using configured method
  wake_host() {
    local host="$1"
    local mac_addr="''${HOST_MAC_ADDRESS[$host]:-}"
    local wake_method="''${HOST_WAKE_METHOD[$host]:-wakeonlan}"
    
    log "Attempting to wake up ''${host}..."
    
    case "$wake_method" in
      wakeonlan)
        if command -v wakeonlan >/dev/null 2>&1; then
          if [[ -n "$mac_addr" && "$mac_addr" != "00:00:00:00:00:00" ]]; then
            log_verbose "Using wakeonlan with MAC: ''${mac_addr}"
            wakeonlan "''${mac_addr}" >> "''${LOG_FILE}" 2>&1 || true
          else
            log "ERROR: wakeonlan method specified but no valid MAC address configured for ''${host}"
            log "Please run 'deploy-config-setup' or edit ''${CONFIG_FILE}"
            return 1
          fi
        else
          log "ERROR: wakeonlan command not found. Install with: nix-env -i wakeonlan"
          return 1
        fi
        ;;
      etherwake)
        if command -v etherwake >/dev/null 2>&1; then
          if [[ -n "$mac_addr" && "$mac_addr" != "00:00:00:00:00:00" ]]; then
            log_verbose "Using etherwake with MAC: ''${mac_addr}"
            etherwake "''${mac_addr}" >> "''${LOG_FILE}" 2>&1 || true
          else
            log "ERROR: etherwake method specified but no valid MAC address configured for ''${host}"
            log "Please run 'deploy-config-setup' or edit ''${CONFIG_FILE}"
            return 1
          fi
        else
          log "ERROR: etherwake command not found"
          return 1
        fi
        ;;
      ssh)
        log_verbose "Using SSH wake method"
        ssh -o ConnectTimeout=5 -o BatchMode=yes "''${host}" "echo wake" >> "''${LOG_FILE}" 2>&1 || true
        ;;
      none)
        log_verbose "Wake method disabled for ''${host}"
        return 0
        ;;
      *)
        log "ERROR: Unknown wake method ''${wake_method} for ''${host}"
        return 1
        ;;
    esac
    
    log "Wake signal sent to ''${host}. Waiting for response..."
  }

  # Wait for a host to be reachable
  wait_for_host() {
    local host="$1"
    local timeout="''${HOST_WAKE_TIMEOUT[$host]:-$WAKE_TIMEOUT}"
    local start_time=$(date +%s)
    
    while ! check_host_reachable "''${host}"; do
      local current_time=$(date +%s)
      local elapsed=$((current_time - start_time))
      
      if [[ ''${elapsed} -gt ''${timeout} ]]; then
        log "ERROR: ''${host} did not respond within ''${timeout} seconds"
        log "Please check if ''${host} is available and try again"
        exit 1
      fi
      
      log_verbose "Waiting for ''${host}... (''${elapsed}/''${timeout}s)"
      sleep 2
    done
    
    log "✓ ''${host} is now reachable"
  }

  # Setup sleep inhibitor on mjolnir
  setup_sleep_inhibitor() {
    log "Setting up sleep inhibitor on ''${MJOLNIR_HOST}..."
    
    # Create a new tmux session and run the sleep inhibitor
    local inhibit_cmd='sudo systemd-inhibit --what=idle:sleep --why="Manual SSH inhibit" sleep infinity'
    local tmux_cmd="tmux new-session -d -s deploy_inhibitor \"''${inhibit_cmd}\""
    
    if ssh "''${MJOLNIR_HOST}" "''${tmux_cmd}" >> "''${LOG_FILE}" 2>&1; then
      log "✓ Sleep inhibitor started in tmux session 'deploy_inhibitor' on ''${MJOLNIR_HOST}"
    else
      log "WARNING: Failed to start sleep inhibitor. Continuing anyway..."
      log_verbose "This may cause ''${MJOLNIR_HOST} to sleep during deployment"
    fi
  }

  # Cleanup sleep inhibitor
  cleanup_sleep_inhibitor() {
    log "Cleaning up sleep inhibitor on ''${MJOLNIR_HOST}..."
    ssh "''${MJOLNIR_HOST}" "tmux kill-session -t deploy_inhibitor" >> "''${LOG_FILE}" 2>&1 || true
    log "✓ Sleep inhibitor cleanup completed"
  }

  # Rebuild a specific host
  rebuild_host() {
    local host="$1"
    local description="Rebuilding ''${host}"
    
    local rebuild_cmd="''${REPO_DIR}/result/bin/rebuild-remote ''${host}"
    execute_command "''${rebuild_cmd}" "''${description}"
  }

  # Get user confirmation with timeout
  get_confirmation_with_timeout() {
    local prompt="$1"
    local timeout="''${2:-120}"
    
    log "''${prompt}"
    log "You have ''${timeout} seconds to respond (y/N):"
    
    local start_time=$(date +%s)
    while true; do
      local current_time=$(date +%s)
      local elapsed=$((current_time - start_time))
      
      if [[ ''${elapsed} -gt ''${timeout} ]]; then
        log "Timeout reached. Skipping router rebuild."
        return 1
      fi
      
      if read -t 1 -n 1 response 2>/dev/null; then
        echo  # New line after character input
        case ''${response} in
          [Yy])
            log "Confirmation received: Yes"
            return 0
            ;;
          [Nn]|*)
            log "Confirmation received: No"
            return 1
            ;;
        esac
      fi
    done
  }

  # Cleanup function for error handling
  cleanup_on_error() {
    log "Deployment failed. Performing cleanup..."
    cleanup_sleep_inhibitor
    log "Cleanup completed. Check ''${LOG_FILE} for details."
  }

  # Main execution starts here
  main() {
    # Parse configuration first
    parse_config
    
    log "Starting deployment process..."
    log "Log file: ''${LOG_FILE}"
    log "Verbose mode: ''${VERBOSE}"
    log "Configuration file: ''${CONFIG_FILE}"
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    cd "''${REPO_DIR}"
    
    # Step 1: Update flakes
    execute_command "nix flake update" "Updating flakes"
    
    # Step 2: Check if mjolnir is awake
    log "Checking if ''${MJOLNIR_HOST} is reachable..."
    if ! check_host_reachable "''${MJOLNIR_HOST}"; then
      local wake_method="''${HOST_WAKE_METHOD[mjolnir]:-wakeonlan}"
      if [[ "$wake_method" != "none" ]]; then
        log "''${MJOLNIR_HOST} is not reachable. Attempting to wake it up..."
        wake_host "''${MJOLNIR_HOST}"
        wait_for_host "''${MJOLNIR_HOST}"
      else
        log "ERROR: ''${MJOLNIR_HOST} is not reachable and wake method is disabled"
        exit 1
      fi
    else
      log "✓ ''${MJOLNIR_HOST} is already reachable"
    fi
    
    # Step 3: Setup sleep inhibitor
    setup_sleep_inhibitor
    
    # Step 4: Build the deployment tools first
    log "Building deployment tools..."
    execute_command "nix build .#nixosConfigurations.framework.config.environment.systemPackages --no-link" "Building system packages"
    
    # Create a temporary result for rebuild-remote
    execute_command "nix build --out-link result" "Building framework configuration"
    
    # Step 5: Rebuild hosts in sequence
    local hosts=("framework" "node0" "mjolnir")
    
    for host in "''${hosts[@]}"; do
      rebuild_host "''${host}"
    done
    
    # Step 6: Check deck availability and rebuild if online
    log "Checking deck availability..."
    if check_host_reachable "deck"; then
      log "✓ deck is reachable"
      rebuild_host "deck"
    else
      local wake_method="''${HOST_WAKE_METHOD[deck]:-wakeonlan}"
      if [[ "$wake_method" != "none" && "''${HOST_OPTIONAL[deck]:-false}" != "true" ]]; then
        log "deck is not reachable. Attempting to wake it up..."
        wake_host "deck"
        wait_for_host "deck"
        rebuild_host "deck"
      else
        log "⚠ deck is not reachable, skipping rebuild (marked as optional or wake disabled)"
      fi
    fi
    
    # Step 7: Router confirmation
    if get_confirmation_with_timeout "Do you want to rebuild the router? This will cause a brief network interruption." "''${ROUTER_TIMEOUT}"; then
      rebuild_host "router"
      log "✓ Router rebuild completed"
    else
      log "Skipping router rebuild"
    fi
    
    # Step 8: Cleanup and reboot mjolnir
    cleanup_sleep_inhibitor
    
    log "Rebooting ''${MJOLNIR_HOST}..."
    ssh "''${MJOLNIR_HOST}" "sudo reboot" >> "''${LOG_FILE}" 2>&1 || true
    
    log ""
    log "🎉 Deployment completed successfully!"
    log "Summary:"
    log "  - Flakes updated"
    log "  - Rebuilt: framework, node0, mjolnir" 
    if check_host_reachable "deck" >/dev/null 2>&1; then
      log "  - Rebuilt: deck"
    else
      log "  - Skipped: deck (not reachable)"
    fi
    log "  - Router: $(if get_confirmation_with_timeout "" 0 2>/dev/null; then echo "rebuilt"; else echo "skipped"; fi)"
    log "  - ''${MJOLNIR_HOST} rebooted"
    log ""
    log "Full deployment log: ''${LOG_FILE}"
  }

  # Run main function
  main "$@"
''