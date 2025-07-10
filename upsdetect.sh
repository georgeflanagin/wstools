#!/bin/bash

# UPS Auto-Detection and Management Script
# Detects CyberPower or APC UPS and starts appropriate daemon

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/ups-autodetect.log"
LOCK_FILE="/var/run/ups-autodetect.lock"

# Configuration
CYBERPOWER_DAEMON="pwrstatd"
APC_DAEMON="apcupsd"
DETECTION_TIMEOUT=10
VERBOSE=false

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [options]

Options:
    -v, --verbose       Enable verbose logging
    -t, --timeout SEC   Detection timeout (default: $DETECTION_TIMEOUT)
    -l, --log FILE      Log file path (default: $LOG_FILE)
    -h, --help          Show this help

This script attempts to detect which UPS is connected and starts the
appropriate daemon. It tries CyberPower first, then falls back to APC.
EOF
}

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] $1"
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "$message"
    fi
    
    echo "$message" >> "$LOG_FILE"
}

error() {
    log "ERROR: $1"
    echo "ERROR: $1" >&2
    exit 1
}

# Check if we're running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

# Create lock file to prevent multiple instances
create_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            error "Another instance is already running (PID: $pid)"
        else
            log "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    trap "rm -f '$LOCK_FILE'; exit" EXIT INT TERM
}

# Stop all UPS daemons
stop_all_ups_daemons() {
    log "Stopping all UPS daemons..."
    
    for daemon in "$CYBERPOWER_DAEMON" "$APC_DAEMON"; do
        if systemctl is-active "$daemon" >/dev/null 2>&1; then
            log "Stopping $daemon"
            systemctl stop "$daemon"
            sleep 2
        fi
    done
}

# Test if CyberPower UPS is connected and working
test_cyberpower() {
    log "Testing CyberPower UPS connection..."
    
    # Start pwrstatd
    log "Starting $CYBERPOWER_DAEMON"
    if ! systemctl start "$CYBERPOWER_DAEMON"; then
        log "Failed to start $CYBERPOWER_DAEMON"
        return 1
    fi
    
    # Wait for daemon to initialize
    sleep 3
    
    # Test if pwrstat can communicate with UPS
    local test_count=0
    local max_tests=3
    
    while [[ $test_count -lt $max_tests ]]; do
        log "Testing pwrstat communication (attempt $((test_count + 1))/$max_tests)"
        
        # Try to get UPS status
        local status_output
        if status_output=$(timeout $DETECTION_TIMEOUT pwrstat -status 2>&1); then
            # Check if output contains actual UPS data (not just "No UPS found")
            if echo "$status_output" | grep -q "Model Name\|Battery Capacity\|Load" && \
               ! echo "$status_output" | grep -q "No UPS found\|Communication failed"; then
                log "CyberPower UPS detected and responding"
                log "UPS Status: $(echo "$status_output" | head -3 | tr '\n' ' ')"
                return 0
            fi
        fi
        
        ((test_count++))
        sleep 2
    done
    
    log "CyberPower UPS not detected or not responding"
    systemctl stop "$CYBERPOWER_DAEMON"
    return 1
}

# Test if APC UPS is connected and working
test_apc() {
    log "Testing APC UPS connection..."
    
    # Start apcupsd
    log "Starting $APC_DAEMON"
    if ! systemctl start "$APC_DAEMON"; then
        log "Failed to start $APC_DAEMON"
        return 1
    fi
    
    # Wait for daemon to initialize
    sleep 3
    
    # Test if apcaccess can communicate with UPS
    local test_count=0
    local max_tests=3
    
    while [[ $test_count -lt $max_tests ]]; do
        log "Testing apcaccess communication (attempt $((test_count + 1))/$max_tests)"
        
        # Try to get UPS status
        local status_output
        if status_output=$(timeout $DETECTION_TIMEOUT apcaccess status 2>&1); then
            # Check if output contains actual UPS data
            if echo "$status_output" | grep -q "MODEL\|BCHARGE\|LOADPCT" && \
               ! echo "$status_output" | grep -q "COMMLOST\|No UPS found"; then
                log "APC UPS detected and responding"
                log "UPS Status: $(echo "$status_output" | grep -E "MODEL|BCHARGE|LOADPCT" | head -3 | tr '\n' ' ')"
                return 0
            fi
        fi
        
        ((test_count++))
        sleep 2
    done
    
    log "APC UPS not detected or not responding"
    systemctl stop "$APC_DAEMON"
    return 1
}

# Main detection logic
detect_and_start_ups() {
    log "=== Starting UPS auto-detection ==="
    
    # Stop any running UPS daemons first
    stop_all_ups_daemons
    
    # Try CyberPower first (since APC daemon can false-positive)
    if test_cyberpower; then
        log "SUCCESS: CyberPower UPS detected and $CYBERPOWER_DAEMON started"
        systemctl enable "$CYBERPOWER_DAEMON"
        return 0
    fi
    
    # If CyberPower fails, try APC
    if test_apc; then
        log "SUCCESS: APC UPS detected and $APC_DAEMON started"
        systemctl enable "$APC_DAEMON"
        return 0
    fi
    
    # If both fail
    log "FAILURE: No UPS detected or both daemons failed"
    return 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -t|--timeout)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                DETECTION_TIMEOUT="$2"
                shift 2
            else
                error "Invalid timeout value: $2"
            fi
            ;;
        -l|--log)
            if [[ -n "$2" ]]; then
                LOG_FILE="$2"
                shift 2
            else
                error "Log file path required"
            fi
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Main execution
main() {
    check_root
    create_lock
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "UPS Auto-Detection Script starting (PID: $$)"
    
    if detect_and_start_ups; then
        log "UPS auto-detection completed successfully"
        exit 0
    else
        log "UPS auto-detection failed"
        exit 1
    fi
}

# Run main function
main "$@"
