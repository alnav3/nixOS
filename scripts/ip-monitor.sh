#!/usr/bin/env bash

# IP Monitor Script
# Checks if public IP matches expected IP and shows notifications when it doesn't

# Configuration
EXPECTED_IP="212.104.214.23"
NORMAL_INTERVAL=30  # seconds
UNSAFE_INTERVAL=10  # seconds
NOTIFICATION_ID=12345  # Persistent notification ID

# Notification management
SCRIPT_NOTIFICATION_IDS="/tmp/ip-monitor-notification-ids.tmp"  # Track all notification IDs used

# State tracking
LAST_STATE=""  # "safe", "unsafe", or ""
STATE_FILE="/tmp/ip-monitor-state.tmp"
NOTIFICATION_REFRESH_INTERVAL=10  # Refresh persistent notification every 8 seconds (before Hyprpanel timeout)
LAST_NOTIFICATION_TIME=0

# Hyprpanel specific settings
HYPRPANEL_NOTIFICATION_TIMEOUT=10  # Hyprpanel typically times out after 10 seconds

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log file for debugging
LOG_FILE="/tmp/ip-monitor.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to get current public IP
get_public_ip() {
    local ip=""

    # Try multiple services in case one is down
    for service in "curl -s https://ipinfo.io/ip" "curl -s https://icanhazip.com" "curl -s https://ipecho.net/plain" "dig +short myip.opendns.com @resolver1.opendns.com"; do
        ip=$(eval $service 2>/dev/null | tr -d '[:space:]')

        # Validate IP format
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
    done

    echo ""
    return 1
}

# Function to detect notification daemon
detect_notification_daemon() {
    # Check for Hyprpanel first
    if pgrep -f "hyprpanel" >/dev/null 2>&1 || pgrep -f "ags.*hyprpanel" >/dev/null 2>&1; then
        echo "hyprpanel"
    elif pgrep -x "dunst" >/dev/null 2>&1; then
        echo "dunst"
    elif pgrep -x "mako" >/dev/null 2>&1; then
        echo "mako"
    elif pgrep -x "swaync" >/dev/null 2>&1; then
        echo "swaync"
    else
        echo "generic"
    fi
}

# Function to show notification (only when state changes)
show_notification() {
    local title="$1"
    local message="$2"
    local urgency="$3"
    local persistent="$4"  # "true" for persistent notifications
    local daemon=$(detect_notification_daemon)

    # Don't clear automatically - only clear when explicitly requested
    
    # Build notify-send command based on notification daemon
    local notify_cmd=""
    if command -v notify-send >/dev/null 2>&1; then
        notify_cmd="notify-send -u \"$urgency\" -i dialog-warning -r \"$NOTIFICATION_ID\""

        # Make notification persistent if requested
        if [[ "$persistent" == "true" ]]; then
                case "$daemon" in
                    "hyprpanel")
                        notify_cmd="$notify_cmd -t 10000"  # 10 seconds for Hyprpanel
                        ;;
                    "dunst")
                        notify_cmd="$notify_cmd -t 0 --hint=int:transient:0"
                        ;;
                    "mako")
                        notify_cmd="$notify_cmd --expire-time 0"
                        ;;
                    "swaync")
                        notify_cmd="$notify_cmd -t 0"
                        ;;
                    *)
                        notify_cmd="$notify_cmd -t 0 --hint=int:resident:1"
                        ;;
                esac
        fi

        notify_cmd="$notify_cmd \"$title\" \"$message\""
        log_message "DEBUG: Sending notification: $notify_cmd"
        eval $notify_cmd
        
        # Track the notification ID
        track_notification_id "$NOTIFICATION_ID"
        
        # Store notification details for refreshing
        if [[ "$persistent" == "true" ]]; then
            echo "$title|$message|$urgency|$daemon" > "/tmp/ip-monitor-notification.tmp"
            LAST_NOTIFICATION_TIME=$(date +%s)
            
            # For Hyprpanel, don't start background maintenance since we refresh manually
            if [[ "$daemon" != "hyprpanel" ]]; then
                # Kill any existing maintenance process and start a new one
                pkill -f "maintain_notification" 2>/dev/null || true
                maintain_notification &
            fi
        fi
    fi

    # Also log to console
    case $urgency in
        "critical")
            echo -e "${RED}[CRITICAL] $title: $message${NC}"
            ;;
        "normal")
            echo -e "${GREEN}[INFO] $title: $message${NC}"
            ;;
        *)
            echo -e "${YELLOW}[WARNING] $title: $message${NC}"
            ;;
    esac
}

# Function to refresh persistent notification
refresh_notification() {
    local notification_file="/tmp/ip-monitor-notification.tmp"
    local current_time=$(date +%s)

    # Only refresh if we have a persistent notification and enough time has passed
    if [[ -f "$notification_file" ]] && [[ $((current_time - LAST_NOTIFICATION_TIME)) -gt $NOTIFICATION_REFRESH_INTERVAL ]]; then
        local notification_data
        notification_data=$(cat "$notification_file")

        if [[ -n "$notification_data" ]]; then
            # Parse notification data
            IFS='|' read -r title message urgency daemon <<< "$notification_data"

            # Refresh the notification without logging to console - be more aggressive
            if command -v notify-send >/dev/null 2>&1; then
                # Force refresh by sending the notification again with same ID to replace it
                notify-send -u "$urgency" -i dialog-warning -r "$NOTIFICATION_ID" "$title" "$message" >/dev/null 2>&1
                LAST_NOTIFICATION_TIME=$current_time
            fi
        fi
    fi
}

# Function to continuously maintain persistent notification (background process)
maintain_notification() {
    local notification_file="/tmp/ip-monitor-notification.tmp"
    local daemon=$(detect_notification_daemon)
    
    # For Hyprpanel, don't refresh notifications to prevent stacking
    if [[ "$daemon" == "hyprpanel" ]]; then
        # Just keep the process alive but don't refresh
        while [[ -f "$notification_file" ]]; do
            sleep 15
        done
        return
    fi
    
    # For other notification daemons, refresh as normal
    while [[ -f "$notification_file" ]]; do
        if [[ -f "$notification_file" ]]; then
            local notification_data
            notification_data=$(cat "$notification_file" 2>/dev/null)
            
            if [[ -n "$notification_data" ]]; then
                # Parse notification data
                IFS='|' read -r title message urgency daemon <<< "$notification_data"
                
                # Continuously refresh notification to keep it visible
                if command -v notify-send >/dev/null 2>&1; then
                    notify-send -u "$urgency" -i dialog-warning -r "$NOTIFICATION_ID" "$title" "$message" >/dev/null 2>&1
                fi
            fi
        fi
        sleep 15  # Refresh every 15 seconds
    done
}

# Function to clear all script notifications
clear_all_script_notifications() {
    # Stop maintenance process first
    pkill -f "maintain_notification" 2>/dev/null || true
    
    local daemon=$(detect_notification_daemon)
    
    # For Hyprpanel, don't send empty notifications as they create unwanted entries
    # Just rely on the -r (replace) flag when sending the new notification
    if [[ "$daemon" != "hyprpanel" ]]; then
        if command -v notify-send >/dev/null 2>&1; then
            # Clear the main notification ID
            notify-send -r "$NOTIFICATION_ID" "" "" 2>/dev/null || true
            
            # Clear all tracked notifications
            if [[ -f "$SCRIPT_NOTIFICATION_IDS" ]]; then
                while IFS= read -r notification_id; do
                    [[ -n "$notification_id" ]] && notify-send -r "$notification_id" "" "" 2>/dev/null || true
                done < "$SCRIPT_NOTIFICATION_IDS"
            fi
        fi
    fi
    
    # Remove tracking files - but DON'T remove the state file
    [[ -f "$SCRIPT_NOTIFICATION_IDS" ]] && rm -f "$SCRIPT_NOTIFICATION_IDS"
    local notification_file="/tmp/ip-monitor-notification.tmp"
    [[ -f "$notification_file" ]] && rm -f "$notification_file"
    
    log_message "DEBUG: Cleared notifications and tracking files (daemon: $daemon)"
}

# Function to clear notification (alias for backward compatibility)
clear_notification() {
    clear_all_script_notifications
}

# Function to track notification ID
track_notification_id() {
    local id="$1"
    echo "$id" >> "$SCRIPT_NOTIFICATION_IDS"
}

# Function to get last state
get_last_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo ""
    fi
}

# Function to save current state
save_state() {
    echo "$1" > "$STATE_FILE"
}

# Function to check IP and handle notifications
check_ip() {
    local current_ip
    local current_state
    local last_state

    current_ip=$(get_public_ip)
    last_state=$(get_last_state)
    
    log_message "DEBUG: Current IP: $current_ip, Last state: '$last_state'"
    
    if [[ -z "$current_ip" ]]; then
        log_message "ERROR: Could not retrieve public IP address"
        # Only show error notification if we weren't already in error state
        if [[ "$last_state" != "error" ]]; then
            show_notification "IP Monitor Error" "Unable to retrieve public IP address" "critical" "true"
        fi
        save_state "error"
        return 2
    fi

    log_message "Current IP: $current_ip | Expected IP: $EXPECTED_IP"

    if [[ "$current_ip" == "$EXPECTED_IP" ]]; then
        current_state="safe"

        # IP is safe
        if [[ "$last_state" != "safe" ]]; then
            # State changed from unsafe/error to safe - clear notifications and show recovery message
            log_message "DEBUG: State change to safe from '$last_state'"
            clear_notification
            if [[ "$last_state" == "unsafe" || "$last_state" == "error" ]]; then
                show_notification "IP Monitor" "IP is now safe: $current_ip" "normal"
                log_message "INFO: IP is now safe - $current_ip"
            fi
        fi
        # If already safe, don't show any notification - just log quietly

        save_state "$current_state"
        return 0
    else
        current_state="unsafe"

        # IP is unsafe - show notification (rely on -r flag to replace previous one)
        log_message "DEBUG: IP is unsafe, showing notification"
        # Show persistent warning every time - the -r flag should replace the previous notification
        show_notification "IP UNSAFE!" "Current IP: $current_ip (Expected: $EXPECTED_IP)" "critical" "true"
        log_message "WARNING: IP mismatch detected - Current: $current_ip, Expected: $EXPECTED_IP"
        # If already unsafe, don't send new notification - the persistent one should still be there

        save_state "$current_state"
        return 1
    fi
}

# Function to handle script termination
cleanup() {
    log_message "IP monitor stopped"

    # Stop any background maintenance processes
    pkill -f "maintain_notification" 2>/dev/null || true

    clear_all_script_notifications
    # Clean up state and notification files
    [[ -f "$STATE_FILE" ]] && rm -f "$STATE_FILE"
    [[ -f "/tmp/ip-monitor-notification.tmp" ]] && rm -f "/tmp/ip-monitor-notification.tmp"
    [[ -f "$SCRIPT_NOTIFICATION_IDS" ]] && rm -f "$SCRIPT_NOTIFICATION_IDS"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Main monitoring loop
main() {
    log_message "Starting IP monitor - Expected IP: $EXPECTED_IP"

    # Check if required commands are available
    if ! command -v curl >/dev/null 2>&1 && ! command -v dig >/dev/null 2>&1; then
        echo "ERROR: Neither curl nor dig is available. Please install at least one of them."
        exit 1
    fi

    while true; do
        check_ip
        exit_code=$?

        case $exit_code in
            0)
                # IP is safe - check again in 30 seconds
                sleep "$NORMAL_INTERVAL"
                ;;
            1)
                # IP is unsafe - check again in 10 seconds
                # Don't refresh notification for Hyprpanel to prevent stacking
                local daemon=$(detect_notification_daemon)
                if [[ "$daemon" != "hyprpanel" ]]; then
                    refresh_notification
                fi
                sleep "$UNSAFE_INTERVAL"
                ;;
            2)
                # Error retrieving IP - check again in 10 seconds
                # Don't refresh notification for Hyprpanel to prevent stacking
                local daemon=$(detect_notification_daemon)
                if [[ "$daemon" != "hyprpanel" ]]; then
                    refresh_notification
                fi
                sleep "$UNSAFE_INTERVAL"
                ;;
        esac
    done
}

# Help function
show_help() {
    cat << EOF
IP Monitor Script

Usage: $0 [OPTIONS]

This script monitors your public IP address and shows notifications when it doesn't match the expected IP.

Options:
    -h, --help          Show this help message
    -e, --expected-ip   Set the expected IP address (default: $EXPECTED_IP)
    -n, --normal        Set normal check interval in seconds (default: $NORMAL_INTERVAL)
    -u, --unsafe        Set unsafe check interval in seconds (default: $UNSAFE_INTERVAL)
    -l, --log           Show log file location and exit

Examples:
    $0                                    # Run with default settings
    $0 -e 192.168.1.100                 # Set different expected IP
    $0 -n 60 -u 5                       # Check every 60s normally, every 5s when unsafe

The script will:
- Check your public IP every 30 seconds when it matches the expected IP
- Check every 10 seconds when the IP doesn't match
- Show notifications only when IP status changes
- Unsafe notifications persist until manually dismissed
- Log all activities to $LOG_FILE

To stop the script, press Ctrl+C
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--expected-ip)
            EXPECTED_IP="$2"
            shift 2
            ;;
        -n|--normal)
            NORMAL_INTERVAL="$2"
            shift 2
            ;;
        -u|--unsafe)
            UNSAFE_INTERVAL="$2"
            shift 2
            ;;
        -l|--log)
            echo "Log file location: $LOG_FILE"
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Start the main monitoring loop
main
