#!/bin/bash
# =============================================================================
# ALIE Shared Functions Library - Core Utilities
# =============================================================================
# CENTRAL LIBRARY: Contains all reusable functions for ALIE installation scripts
#
# PURPOSE:
# - Provides consistent UI/UX across all installation scripts
# - Handles system detection, package management, and configuration
# - Implements robust error handling and retry logic
# - Manages installation progress tracking and data persistence
#
# USAGE:
#   source "$LIB_DIR/shared-functions.sh"
#
# KEY FEATURES:
# - Color-coded output functions (print_info, print_success, print_warning, print_error)
# - Automatic retry logic for network/package operations
# - System hardware detection (CPU, boot mode, filesystems)
# - Progress tracking between installation steps
# - Configuration persistence across script runs
# - Universal AUR helper support (yay, paru, pacman)
# - Privilege escalation abstraction (sudo, doas, run0)
#
# ARCHITECTURE:
# - Functions are grouped by purpose (printing, system detection, package management, etc.)
# - All functions use consistent error handling and return codes
# - Global variables are avoided; functions return values or use local variables
# - Shell-agnostic design (works with bash, zsh, fish, etc.)
#
# DEPENDENCIES:
# - Bash 4.0+ (for associative arrays and advanced parameter expansion)
# - Standard Linux tools (grep, sed, awk, findmnt, etc.)
# - Pacman package manager (Arch Linux specific)
#
# NOTE: This file is meant to be sourced, not executed directly.
# The calling script should use 'set -euo pipefail' for proper error handling.
# =============================================================================

# =============================================================================
# ANSI COLOR DEFINITIONS - Terminal Output Styling
# =============================================================================
# Provides consistent color coding for all script output
# Uses ANSI escape sequences for cross-terminal compatibility
# Colors follow common conventions: green=success, red=error, yellow=warning, cyan=info
RED=$'\033[0;31m'        # Error messages, critical issues
GREEN=$'\033[0;32m'      # Success confirmations, completed operations
YELLOW=$'\033[0;33m'     # Warnings, non-critical issues, user attention needed
# shellcheck disable=SC2034
BLUE=$'\033[0;34m'       # Reserved for future use (less common in terminals)
CYAN=$'\033[0;36m'       # Informational messages, progress updates
MAGENTA=$'\033[0;35m'    # Step headers, important section markers
NC=$'\033[0m'            # No Color - Reset to terminal default

# =============================================================================
# TTY COMPATIBILITY FUNCTIONS - Terminal Environment Handling
# =============================================================================
# Ensures scripts work correctly across different terminal environments
# Handles terminal size detection, user interaction, and display limitations
# Critical for providing consistent experience on various systems and terminals

# Get terminal dimensions safely
# Returns terminal width in characters
# Handles cases where tput is not available or fails
get_terminal_width() {
    tput cols 2>/dev/null || echo 80
}

# Get terminal height safely
# Returns terminal height in lines
# Used for determining if banners should be displayed in compact form
get_terminal_height() {
    tput lines 2>/dev/null || echo 24
}

# Check if terminal is too small for banners
# Returns 0 if terminal is small (<70 cols or <20 lines), 1 otherwise
# This affects banner display and some interactive elements
is_terminal_small() {
    local width
    local height
    width=$(get_terminal_width)
    height=$(get_terminal_height)

    # Consider small if less than 70 columns or 20 lines
    if [ "$width" -lt 70 ] || [ "$height" -lt 20 ]; then
        return 0
    else
        return 1
    fi
}

# Pause for user interaction in TTY
# Waits for user to press any key before continuing
# Useful for giving users time to read important information
press_any_key() {
    echo ""
    read -r -n1 -s -p "Press any key to continue..."
    echo ""
}

# Clear screen intelligently based on terminal capabilities
# Uses 'clear' command if available, falls back to ANSI escape sequences
# More reliable than just using ANSI codes in limited environments
smart_clear() {
    if command -v clear >/dev/null 2>&1; then
        clear
    else
        # Fallback for limited environments
        printf "\033[2J\033[H"
    fi
}

# Show progress indicator for slow operations
# Displays a message with animated dots to show activity
# Usage: show_progress "Installing packages"
# Useful for operations that take several seconds and need visual feedback
show_progress() {
    local message="$1"
    echo -n "${CYAN}${message}${NC}"
    for _ in {1..3}; do
        sleep 0.5
        echo -n "."
    done
    echo " ${GREEN}[OK]${NC}"
}

# =============================================================================
# PRINTING FUNCTIONS - User Interface Output
# =============================================================================
# Standardized output functions for consistent user experience
# All functions automatically handle color coding and formatting

# Print informational message in cyan
# Usage: print_info "Loading configuration files..."
print_info() {
    echo -e "${CYAN}[INFO] ${NC}$1"
}

# Print success message in green
# Usage: print_success "Package installed successfully"
print_success() {
    echo -e "${GREEN}[OK] ${NC}$1"
}

# Print warning message in yellow (to stderr)
# Usage: print_warning "This operation may take several minutes"
print_warning() {
    echo -e "${YELLOW}[WARNING] ${NC}$1"
}

# Print error message in red (to stderr)
# Usage: print_error "Failed to mount partition"
# DEPRECATED: Use print_error_detailed() instead for comprehensive error reporting
# TODO: Remove this function in future version - currently kept for legacy compatibility
print_error() {
    echo -e "${RED}[ERROR] ${NC}$1" >&2
}

# Print descriptive error with context and suggestions
# Usage: print_error_detailed "Failed to mount partition" "Check if partition exists" "Try: lsblk" "Or: fdisk -l"
# RECOMMENDED: Use this function for all new error reporting - provides context, suggestions, and commands
print_error_detailed() {
    local error_msg="$1"
    local context="${2:-}"
    local suggestion="${3:-}"
    local command_hint="${4:-}"

    echo -e "${RED}[ERROR] ${NC}$error_msg" >&2

    if [ -n "$context" ]; then
        echo -e "${YELLOW}[CONTEXT] ${NC}$context" >&2
    fi

    if [ -n "$suggestion" ]; then
        echo -e "${CYAN}[SUGGESTION] ${NC}$suggestion" >&2
    fi

    if [ -n "$command_hint" ]; then
        echo -e "${GREEN}[TRY] ${NC}$command_hint" >&2
    fi
}

# Print step header with decorative line
# Creates a full-width separator line with the step title
# Usage: print_step "STEP 1: Partitioning Disk"
print_step() {
    echo ""
    local width
    width=$(get_terminal_width)
    local line_char="#"

    # Create separator line based on terminal width
    printf '%b' "$MAGENTA"
    printf "%${width}s\n" | tr ' ' "$line_char"
    printf '  %s\n' "$1"
    printf "%${width}s\n" | tr ' ' "$line_char"
    printf '%b' "$NC"
    echo ""
}
# =============================================================================
# UTILITY FUNCTIONS - General Purpose Helpers
# =============================================================================

# Retry a command with exponential backoff
# CRITICAL for network operations and package downloads
# Implements intelligent retry logic to handle temporary failures
# Usage: retry_command <max_attempts> <command>
# Example: retry_command 3 "pacman -Sy"
# Returns: 0 on success, 1 on final failure
retry_command() {
    local max_attempts=$1
    shift
    local command_str
    command_str="$*"
    local attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
        if eval "$command_str"; then
            return 0
        else
            if [ "$attempt" -lt "$max_attempts" ]; then
                local wait_time=$((attempt * 3))  # Exponential backoff: 3s, 6s, 9s...
                print_warning "Command failed (attempt $attempt/$max_attempts)"
                print_info "Retrying in ${wait_time}s..."
                sleep "$wait_time"
                attempt=$((attempt + 1))
            else
                print_error_detailed "Command failed after $max_attempts attempts" \
                    "The command did not succeed despite multiple retry attempts" \
                    "Check system logs and network connectivity if applicable" \
                    "Verify command syntax and required dependencies are installed"
                return 1
            fi
        fi
    done
}

# Wait for an operation to complete by polling
# POLLS a condition until it becomes true or timeout expires
# Useful for waiting on asynchronous operations like network availability or service startup
# Usage: wait_for_operation <check_command> <timeout_seconds> <poll_interval>
# Example: wait_for_operation "mountpoint -q /mnt" 30 1
# Returns: 0 if condition met, 1 on timeout
wait_for_operation() {
    local check_command="$1"
    local timeout=${2:-30}      # Default 30 seconds timeout
    local interval=${3:-1}      # Default 1 second poll interval
    local elapsed=0

    print_info "Waiting for operation to complete (timeout: ${timeout}s)..."

    while [ "$elapsed" -lt "$timeout" ]; do
        if eval "$check_command" 2>/dev/null; then
            print_success "Operation completed successfully"
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    print_error_detailed "Operation timed out after ${timeout}s" \
        "The expected operation did not complete within the specified time limit" \
        "This may indicate network issues, service problems, or system overload" \
        "Check system logs and verify the operation can complete successfully"
    print_error_detailed "Check command was: $check_command" \
        "This was the command used to verify operation completion" \
        "Run this command manually to debug the issue" \
        "Ensure all required services and dependencies are running"
    return 1
}

# =============================================================================
# ENVIRONMENT VALIDATION - Safety Checks
# =============================================================================
# Critical functions to ensure scripts run in correct environment
# Prevents data loss and system corruption from running in wrong context

# Verify the script is running inside a chroot environment
# IMPORTANT: Many installation operations require chroot context
# Returns 0 if in chroot, 1 otherwise
# Uses multiple detection methods for reliability
verify_chroot() {
    print_info "Verifying chroot environment..."

    # Method 1: Check if root is mounted (most reliable)
    if ! grep -qs '/proc' /proc/mounts; then
        print_error_detailed "Not running in chroot environment!" \
            "This script requires chroot context to modify the installed system safely" \
            "Chroot provides isolation and prevents accidental changes to the host system" \
            "Run: arch-chroot /mnt /bin/bash, then execute this script from within chroot"
        print_info "This script must be run from within arch-chroot"
        return 1
    fi

    # Method 2: Compare device numbers of / and /proc/1/root/.
    # In chroot, these will be different
    local root_dev
    local init_dev
    root_dev=$(stat -c %d:%i /)
    init_dev=$(stat -c %d:%i /proc/1/root/. 2>/dev/null || echo "")

    if [ -n "$init_dev" ] && [ "$root_dev" != "$init_dev" ]; then
        print_success "Running in chroot environment"
        return 0
    fi

    # If we can't determine or it looks like we're not in chroot
    print_warning "Could not definitively verify chroot environment"
    read -r -p "Continue anyway? (y/N): " CONTINUE

    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        print_error_detailed "Aborted by user" \
            "User chose not to continue when chroot environment verification was uncertain" \
            "This prevents potential system corruption from running scripts in wrong context" \
            "Ensure you're running from within arch-chroot before proceeding"
        return 1
    fi

    return 0
}

# Check if running as root - CRITICAL for installation scripts
# Most partitioning and system installation operations require root
# Returns 0 if root, exits script with error if not root
require_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error_detailed "This script must be run as root!" \
            "System installation and partitioning require root privileges" \
            "These operations modify disk partitions and system files that need elevated access" \
            "Run: sudo bash $0"
        print_info "Please run with: sudo bash $0"
        exit 1
    fi
}

# Require non-root (regular user) - for post-install scripts
# Some configuration scripts should NOT run as root for security
# Returns 0 if non-root, exits script with error if root
require_non_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error_detailed "Do not run this script as root!" \
            "This script is designed for regular user configuration and should not run as root" \
            "Running as root could modify system files inappropriately or create security issues" \
            "Run: bash $0 (as your regular user, not with sudo)"
        print_info "Run as your regular user: bash $0"
        exit 1
    fi
}

# Verify system is Arch Linux - exits if not
verify_arch_linux() {
    if [ ! -f /etc/arch-release ]; then
        print_error_detailed "This doesn't appear to be an Arch Linux system" \
            "This script is specifically designed for Arch Linux and its derivatives" \
            "Running on other distributions may cause compatibility issues or system damage" \
            "Verify you're running on Arch Linux or a compatible derivative"
        print_info "This script is designed for Arch Linux only"
        exit 1
    fi
}

# Verify NOT in chroot (for post-install scripts) - exits if in chroot
verify_not_chroot() {
    # Compare device numbers of / and /proc/1/root/.
    if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ] 2>/dev/null; then
        print_error_detailed "This script should not be run in chroot" \
            "This script is for post-installation configuration on the running system" \
            "Running in chroot would configure the wrong system or cause conflicts" \
            "Exit chroot and boot into the installed system first"
        print_info "Exit chroot and boot into the installed system first"
        exit 1
    fi
}

# Verify internet connectivity - exits if no internet
verify_internet() {
    if ! check_internet; then
        print_error_detailed "No internet connection detected" \
            "Internet connection is required for package downloads and system updates" \
            "Installation cannot proceed without network access to Arch Linux repositories" \
            "Check network cables, WiFi connection, or run: ping -c 3 archlinux.org"
        print_info "Internet connection is required to continue"
        exit 1
    fi
}

# Require and validate DESKTOP_USER from install info
# Ensures the current user matches the desktop user
require_desktop_user() {
    # Load configuration if not already loaded
    if [ -z "${DESKTOP_USER:-}" ]; then
        load_install_info
    fi
    
    if [ -z "${DESKTOP_USER:-}" ]; then
        print_error_detailed "DESKTOP_USER not found in install info" \
            "This script requires the desktop installation to be completed first" \
            "Run the user setup scripts (201-user-setup.sh) before this script" \
            "Check: cat /root/.alie-install-info | grep DESKTOP_USER"
        exit 1
    fi
    
    # Verify user exists on system
    if ! id "$DESKTOP_USER" &>/dev/null; then
        print_error_detailed "User '$DESKTOP_USER' does not exist on this system" \
            "The specified desktop user was not found in the user database" \
            "Create the user first or check the DESKTOP_USER variable" \
            "Run: useradd -m -G wheel $DESKTOP_USER && passwd $DESKTOP_USER"
        exit 1
    fi
    
    # Verify we're running as the desktop user
    if [ "$USER" != "$DESKTOP_USER" ]; then
        print_error_detailed "This script must be run as user '$DESKTOP_USER'" \
            "Currently running as: $USER" \
            "Switch to the correct user before running this script" \
            "Run: su - $DESKTOP_USER -c 'bash $0'"
        exit 1
    fi
    
    print_success "Running as correct user: $DESKTOP_USER"
}

# =============================================================================
# BANNER FUNCTIONS
# =============================================================================

# Display section header with ALIE banner
print_section_header() {
    local section_name="$1"
    local section_desc="$2"
    
    show_alie_banner
    echo ""
    print_step "$section_name"
    if [ -n "$section_desc" ]; then
        print_info "$section_desc"
        echo ""
    fi
}

# Display ALIE banner
show_alie_banner() {
    smart_clear
    echo -e "${MAGENTA}"
    
    # Use compact banner for small terminals
    if is_terminal_small; then
        cat << "EOF"
#############################
#        A L I E            #  
#  Arch Linux Installation  #
#      Environment          #
#############################
EOF
    else
        cat << "EOF"
#########################################
#                                       #
#       AAA    L       I   EEEEEEE      #
#      A   A   L       I   E            #
#     A     A  L       I   E            #
#     AAAAAAA  L       I   EEEEE        #
#     A     A  L       I   E            #
#     A     A  LLLLLLL I   EEEEEEE      #
#                                       #
#  Arch Linux Installation Environment  #
#                                       #
#########################################
EOF
    fi
    
    echo -e "${NC}"
}

# Display warning banner
show_warning_banner() {
    echo -e "${YELLOW}"
    cat << "EOF"
#############################################################
#                    **  WARNING  **                        #
#############################################################
#  This is an EXPERIMENTAL script provided AS-IS            #
#  without warranties. Review the code before running       #
#  and use at your own risk.                                #
#                                                           #
#  This script will make PERMANENT changes to your system!  #
#############################################################
EOF
    echo -e "${NC}"
}

# =============================================================================
# PROGRESS TRACKING - Installation State Management
# =============================================================================
# Tracks installation progress across multiple script runs
# Prevents re-running completed steps and provides installation resume capability
# Uses simple marker files for reliability and cross-shell compatibility

# Save progress marker for completed installation step
# CRITICAL for multi-script installation flow
# Usage: save_progress <step_name>
# Example: save_progress "01-partitions-ready"
save_progress() {
    local step="$1"
    local progress_file="${ALIE_PROGRESS_FILE:-/tmp/.alie-progress}"

    # Store in live environment (/mnt/root) if available, otherwise in temp
    if [ -d /mnt/root ]; then
        progress_file="/mnt/root/.alie-progress"
    elif [ -f /root/.alie-install-info ]; then
        # In installed system
        progress_file="/root/.alie-progress"
    fi

    echo "$step" >> "$progress_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $step" >> "${progress_file}.log"
}

# Check if a specific installation step is completed
# Returns 0 if step completed, 1 if not found
# Usage: is_step_completed <step_name>
is_step_completed() {
    local step="$1"
    local progress_file="${ALIE_PROGRESS_FILE:-/tmp/.alie-progress}"

    # Check in appropriate location based on environment
    if [ -d /mnt/root ]; then
        progress_file="/mnt/root/.alie-progress"
    elif [ -f /root/.alie-install-info ]; then
        progress_file="/root/.alie-progress"
    fi

    if [ -f "$progress_file" ] && grep -q "^${step}$" "$progress_file" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get installation progress
# Returns: step number (0-5) or "unknown"
get_installation_step() {
    # Check for completed markers
    if is_step_completed "05-packages-installed"; then
        echo "5"
    elif is_step_completed "04-yay-installed"; then
        echo "4"
    elif is_step_completed "03-desktop-installed"; then
        echo "3"
    elif is_step_completed "02-system-configured"; then
        echo "2"
    elif is_step_completed "01-base-installed"; then
        echo "1"
    elif [ -f /mnt/root/.alie-install-info ] || [ -f /root/.alie-install-info ]; then
        # Base installation started but not completed
        echo "1"
    else
        echo "0"
    fi
}

# Get installation step name
# Returns: script name for the current step or "unknown"
get_installation_step_name() {
    local step
    step=$(get_installation_step)
    
    case "$step" in
        "1") echo "001-base-install.sh" ;;
        "2") echo "101-configure-system.sh" ;;
        "3") echo "201-user-setup.sh" ;;
        "4") echo "211-install-aur-helper.sh" ;;
        "5") echo "212-cli-tools.sh" ;;
        *) echo "unknown" ;;
    esac
}

# Get next installation step name
# Returns: script name for the next step or empty string if none
get_next_installation_step_name() {
    local step
    step=$(get_installation_step)
    
    case "$step" in
        "0") echo "001-base-install.sh" ;;
        "1") 
            # Check if shell/editor selection was completed
            if is_step_completed "01b-shell-editor-selected"; then
                echo "003-system-install.sh"
            else
                echo "002-shell-editor-select.sh"
            fi
            ;;
        "2") echo "201-user-setup.sh" ;;
        "3") echo "211-install-aur-helper.sh" ;;
        "4") echo "212-cli-tools.sh" ;;
        "5") echo "213-display-server.sh" ;;
        *) echo "" ;;
    esac
}

# Clear progress (for fresh start)
clear_progress() {
    local progress_file="${ALIE_PROGRESS_FILE:-/tmp/.alie-progress}"
    
    rm -f "$progress_file" 2>/dev/null || true
    rm -f "${progress_file}.log" 2>/dev/null || true
    rm -f "/mnt/root/.alie-progress" 2>/dev/null || true
    rm -f "/mnt/root/.alie-progress.log" 2>/dev/null || true
    rm -f "/root/.alie-progress" 2>/dev/null || true
    rm -f "/root/.alie-progress.log" 2>/dev/null || true
    
    # Also clear configuration files that might indicate previous installation state
    rm -f "/tmp/.alie-install-config" 2>/dev/null || true
    rm -f "/mnt/root/.alie-install-config" 2>/dev/null || true
    rm -f "/root/.alie-install-info" 2>/dev/null || true
    rm -f "/mnt/root/.alie-install-info" 2>/dev/null || true
    rm -f "/tmp/.alie-shell-editor-config" 2>/dev/null || true
    
    print_success "Progress and configuration files cleared"
}

# =============================================================================
# DATA PERSISTENCE FUNCTIONS - Configuration Storage
# =============================================================================
# Saves and loads installation configuration between scripts
# Uses simple key=value format for cross-shell compatibility
# Critical for maintaining state across installation phases

# Load installation info from previous script run
# Reads configuration saved by earlier installation scripts
# Expects file at /root/.alie-install-info (in installed system)
# Usage: load_install_info [config_file]
# Returns: 0 on success, 1 if file not found
load_install_info() {
    local info_file="${1:-/root/.alie-install-info}"

    if [ -f "$info_file" ]; then
        print_info "Loading installation configuration from $info_file..."
        # shellcheck source=/root/.alie-install-info
        # shellcheck disable=SC1091
        source "$info_file"
        print_success "Configuration loaded successfully"

        # Display loaded variables for debugging (optional)
        if [ "${DEBUG:-0}" = "1" ]; then
            print_info "Loaded variables:"
            while IFS= read -r line; do
                echo "  $line"
            done < "$info_file"
        fi

        return 0
    else
        print_warning "Installation info file not found: $info_file"
        print_warning "Some auto-detection features will be limited"
        return 1
    fi
}

# Save installation info for next script to read
# CRITICAL for passing configuration between installation phases
# Usage: save_install_info <output_file> <var1> <var2> ...
# Example: save_install_info "/mnt/root/.alie-install-info" BOOT_MODE ROOT_PARTITION
# Creates key=value file that can be sourced by other scripts
save_install_info() {
    local output_file="$1"
    shift
    local variables=("$@")

    print_info "Saving installation configuration to $output_file..."

    # Create or truncate file
    : > "$output_file"

    # Write each variable as key=value pair
    for var_name in "${variables[@]}"; do
        # Get the value of the variable using indirect expansion
        local var_value
        if [ -n "${!var_name:-}" ]; then
            # Variable exists, use its value
            var_value="${!var_name}"
        else
            # Variable doesn't exist, treat var_name as the value to save
            # This handles cases where the caller passes values instead of variable names
            var_value="$var_name"
            # Use a generic key name since we don't have a proper variable name
            var_name="value_${var_name//[^a-zA-Z0-9_]/_}"
        fi
        echo "${var_name}=${var_value}" >> "$output_file"
    done

    print_success "Configuration saved successfully"

    # Display saved variables for debugging (optional)
    if [ "${DEBUG:-0}" = "1" ]; then
        print_info "Saved configuration:"
        cat "$output_file"
    fi

    return 0
}

# =============================================================================
# NETWORK FUNCTIONS - Connectivity and Network Operations
# =============================================================================
# Handles network connectivity checks and waiting for network availability
# Critical for installation scripts that require internet access for package downloads

# Check internet connectivity
# Tests connection to a reliable host (default: archlinux.org)
# Uses ping with timeout to avoid hanging on slow/unreliable connections
# Usage: check_internet [test_host] [timeout_seconds]
# Returns: 0 if connected, 1 if not connected
# shellcheck disable=SC2120
check_internet() {
    local test_host="${1:-archlinux.org}"
    local timeout="${2:-5}"

    print_info "Testing internet connectivity to $test_host..."

    if ping -c 1 -W "$timeout" "$test_host" &>/dev/null; then
        print_success "Internet connection verified"
        return 0
    else
        print_warning "No response from $test_host (timeout: ${timeout}s)"
        return 1
    fi
}

# Wait for internet connection with retries
# Keeps trying to establish internet connection until successful or max attempts reached
# Useful during installation when network might not be immediately available
# Usage: wait_for_internet [max_attempts] [test_host]
# Returns: 0 when connected, 1 on timeout
wait_for_internet() {
    local max_attempts="${1:-10}"
    local test_host="${2:-archlinux.org}"
    local attempt=1

    print_info "Checking internet connectivity..."

    while [ "$attempt" -le "$max_attempts" ]; do
        if check_internet "$test_host"; then
            print_success "Internet connection verified"
            return 0
        else
            if [ "$attempt" -lt "$max_attempts" ]; then
                print_warning "No internet connection (attempt $attempt/$max_attempts)"
                print_info "Waiting 3 seconds..."
                sleep 3
                attempt=$((attempt + 1))
            else
                print_error_detailed "Could not establish internet connection after $max_attempts attempts" \
                    "Network connectivity could not be established despite multiple attempts" \
                    "This prevents package installation and system updates from proceeding" \
                    "Check network configuration, cables, or WiFi settings"
                print_error_detailed "Please check your network configuration" \
                    "Verify network interface is up, IP address is assigned, and DNS is working" \
                    "Common solutions: check cables, restart network service, or configure WiFi" \
                    "Run: ip addr show, ping 8.8.8.8, or nmtui for network configuration"
                return 1
            fi
        fi
    done
}

# =============================================================================
# PARTITION HELPERS - Disk and Filesystem Operations
# =============================================================================
# Utilities for working with disk partitions and mount points
# Critical for installation scripts that manipulate disk partitions

# Check if a partition is mounted
# Verifies if a given partition device is currently mounted
# Usage: is_mounted <partition>
# Example: is_mounted "/dev/sda1"
# Returns: 0 if mounted, 1 if not mounted
is_mounted() {
    local partition="$1"

    if grep -qs "$partition" /proc/mounts; then
        return 0
    else
        return 1
    fi
}

# Safely unmount a partition
# Attempts graceful unmount first, then force unmount if needed
# Includes proper error handling and user feedback
# Usage: safe_unmount <mount_point>
# Example: safe_unmount "/mnt/boot"
# Returns: 0 on success, 1 on failure
safe_unmount() {
    local mount_point="$1"

    if is_mounted "$mount_point"; then
        print_info "Unmounting $mount_point..."
        if umount "$mount_point" 2>/dev/null; then
            print_success "Unmounted $mount_point"
            return 0
        else
            print_warning "Could not unmount $mount_point, trying force unmount..."
            if umount -f "$mount_point" 2>/dev/null; then
                print_success "Force unmounted $mount_point"
                return 0
            else
                print_error_detailed "Failed to unmount $mount_point" \
                    "The filesystem could not be unmounted gracefully or forcefully" \
                    "This may leave the system in an inconsistent state or prevent further operations" \
                    "Check if processes are using files on this mount point with: lsof $mount_point"
                return 1
            fi
        fi
    else
        print_info "$mount_point is not mounted"
        return 0
    fi
}

# =============================================================================
# PACKAGE MANAGER HELPERS - Pacman Operations
# =============================================================================
# Wrappers around pacman commands with retry logic and error handling
# Ensures reliable package operations during installation

# Install packages with retry logic
# Installs packages using pacman with automatic retry on failure
# Usage: install_packages <package1> <package2> ...
# Example: install_packages "base" "linux" "linux-firmware"
# Returns: 0 on success, 1 on failure
install_packages() {
    local packages=("$@")

    print_info "Installing packages: ${packages[*]}"

    if retry_command 3 "pacman -S --needed --noconfirm ${packages[*]}"; then
        print_success "Packages installed successfully"
        return 0
    else
        print_error_detailed \
            "Failed to install packages: ${packages[*]}" \
            "Package installation failed after multiple retry attempts, preventing system setup completion." \
            "Check network connectivity, package repository status, and disk space." \
            "run_privileged 'pacman -Syu --needed ${packages[*]}' or check: run_privileged 'pacman -Ss ${packages[*]}'"
        return 1
    fi
}

# Update package database with retry
# Refreshes pacman's package database from mirrors
# Critical before installing packages to ensure latest information
# Usage: update_package_db
# Returns: 0 on success, 1 on failure
update_package_db() {
    print_info "Updating package database..."

    if retry_command 3 "pacman -Syy"; then
        print_success "Package database updated"
        return 0
    else
        print_error_detailed \
            "Failed to update package database" \
            "Package database update failed, preventing access to latest package information and security updates." \
            "Check internet connection and mirror status." \
            "run_privileged 'pacman -Syy' or check mirrors: run_privileged 'pacman-mirrors --fasttrack'"
        return 1
    fi
}

# Execute command with retry logic (alias for retry_command for backward compatibility)
# Usage: run_with_retry <max_attempts> <command>
run_with_retry() {
    retry_command "$@"
}

# =============================================================================
# SHELL CONFIGURATION FUNCTIONS - User Environment Setup
# =============================================================================
# Configures shell environments for users after installation
# Supports multiple shells with appropriate configuration files and settings
# Ensures consistent user experience across different shell choices

# Detect available shells on the system
# Scans for installed shell executables and returns available options
# Used to present shell choices to users during installation
# Returns: space-separated list of available shell names
detect_available_shells() {
    local shells=()

    if command -v bash >/dev/null 2>&1; then
        shells+=("bash")
    fi

    if command -v zsh >/dev/null 2>&1; then
        shells+=("zsh")
    fi

    if command -v fish >/dev/null 2>&1; then
        shells+=("fish")
    fi

    if command -v dash >/dev/null 2>&1; then
        shells+=("dash")
    fi

    if command -v tcsh >/dev/null 2>&1; then
        shells+=("tcsh")
    fi

    if command -v ksh >/dev/null 2>&1; then
        shells+=("ksh")
    fi

    if command -v nu >/dev/null 2>&1; then
        shells+=("nushell")
    fi

    echo "${shells[*]}"
}

# Get shell path for a given shell name
# Maps shell names to their executable paths
# Used by chsh command to change user shell
# Usage: get_shell_path <shell_name>
# Returns: full path to shell executable
get_shell_path() {
    local shell_name="$1"

    case "$shell_name" in
        "bash") echo "/bin/bash" ;;
        "zsh") echo "/bin/zsh" ;;
        "fish") echo "/usr/bin/fish" ;;
        "dash") echo "/bin/dash" ;;
        "tcsh") echo "/bin/tcsh" ;;
        "ksh") echo "/bin/ksh" ;;
        "nushell") echo "/usr/bin/nu" ;;
        *) echo "" ;;
    esac
}

# Configure shell environment for a user
# Main entry point for shell configuration
# Dispatches to specific shell configuration functions
# Usage: configure_shell_for_user <username> <shell_name>
configure_shell_for_user() {
    local username="$1"
    local shell_name="$2"
    local user_home="/home/$username"

    print_info "Configuring $shell_name environment for $username..."

    # Get configs directory
    local configs_dir
    configs_dir="$(dirname "$(dirname "$SCRIPT_DIR")")/configs/shell"

    case "$shell_name" in
        "zsh")
            configure_zsh_environment "$username" "$configs_dir"
            ;;
        "fish")
            configure_fish_environment "$username" "$configs_dir"
            ;;
        "bash")
            configure_bash_environment "$username" "$configs_dir"
            ;;
        "tcsh")
            configure_tcsh_environment "$username" "$configs_dir"
            ;;
        "ksh")
            configure_ksh_environment "$username" "$configs_dir"
            ;;
        "nushell")
            configure_nushell_environment "$username" "$configs_dir"
            ;;
        *)
            print_warning "No specific configuration available for shell: $shell_name"
            ;;
    esac

    print_success "$shell_name environment configured for $username"
}

# Configure Zsh environment
configure_zsh_environment() {
    local username="$1"
    local configs_dir="$2"
    local user_home="/home/$username"
    local zshrc="$user_home/.zshrc"
    
    if [ ! -f "$zshrc" ]; then
        if [ -f "$configs_dir/zshrc" ]; then
            cp "$configs_dir/zshrc" "$zshrc"
            print_success "Deployed zsh configuration from: configs/shell/zshrc"
        else
            # Fallback to inline config
            cat > "$zshrc" << 'EOF'
# ALIE Basic Zsh Configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory sharehistory incappendhistory
autoload -Uz compinit && compinit
autoload -U colors && colors
PS1="%{$fg[green]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}%# "
alias ls='ls --color=auto'
export PATH="$HOME/.local/bin:$PATH"
EOF
            print_warning "Using inline zsh configuration (config file not found)"
        fi
        chown "$username:$username" "$zshrc"
    fi
}

# Configure Fish environment
configure_fish_environment() {
    local username="$1"
    local configs_dir="$2"
    local user_home="/home/$username"
    local fish_config="$user_home/.config/fish"
    
    mkdir -p "$fish_config"
    
    if [ ! -f "$fish_config/config.fish" ]; then
        if [ -f "$configs_dir/config.fish" ]; then
            cp "$configs_dir/config.fish" "$fish_config/config.fish"
            print_success "Deployed fish configuration from: configs/shell/config.fish"
        else
            # Fallback to inline config
            cat > "$fish_config/config.fish" << 'EOF'
# ALIE Basic Fish Configuration
set fish_greeting ""
alias ll='ls -alF'
set -gx PATH $HOME/.local/bin $PATH
EOF
            print_warning "Using inline fish configuration (config file not found)"
        fi
        chown -R "$username:$username" "$fish_config"
    fi
}

# Configure Bash environment
configure_bash_environment() {
    local username="$1"
    local configs_dir="$2"
    local user_home="/home/$username"
    local bashrc="$user_home/.bashrc"
    
    # For bash, we can optionally deploy enhanced config
    if [ -f "$configs_dir/bashrc" ] && [ ! -s "$bashrc" ]; then
        cp "$configs_dir/bashrc" "$bashrc"
        chown "$username:$username" "$bashrc"
        print_success "Deployed bash configuration from: configs/shell/bashrc"
    fi
}

# Configure Tcsh environment
configure_tcsh_environment() {
    local username="$1"
    local configs_dir="$2"
    local user_home="/home/$username"
    local tcshrc="$user_home/.tcshrc"
    
    if [ ! -f "$tcshrc" ]; then
        if [ -f "$configs_dir/tcshrc" ]; then
            cp "$configs_dir/tcshrc" "$tcshrc"
            print_success "Deployed tcsh configuration from: configs/shell/tcshrc"
        else
            # Fallback to inline config
            cat > "$tcshrc" << 'EOF'
# ALIE Basic Tcsh Configuration
set prompt = "%{\033[1;32m%}%n@%m%{\033[0m%}:%{\033[1;34m%}%~%{\033[0m%}%# "
set history = 1000
set savehist = (1000 merge)
alias ls 'ls --color=auto'
alias ll 'ls -lh'
setenv EDITOR nano
EOF
            print_warning "Using inline tcsh configuration (config file not found)"
        fi
        chown "$username:$username" "$tcshrc"
    fi
}

# Configure Ksh environment
configure_ksh_environment() {
    local username="$1"
    local configs_dir="$2"
    local user_home="/home/$username"
    local kshrc="$user_home/.kshrc"
    
    if [ ! -f "$kshrc" ]; then
        if [ -f "$configs_dir/kshrc" ]; then
            cp "$configs_dir/kshrc" "$kshrc"
            print_success "Deployed ksh configuration from: configs/shell/kshrc"
        else
            # Fallback to inline config
            cat > "$kshrc" << 'EOF'
# ALIE Basic Ksh Configuration
PS1='\u@\h:\w\$ '
HISTFILE=~/.ksh_history
HISTSIZE=1000
set -o vi
alias ls='ls --color=auto'
alias ll='ls -lh'
export EDITOR=nano
EOF
            print_warning "Using inline ksh configuration (config file not found)"
        fi
        chown "$username:$username" "$kshrc"
    fi
}

# Configure Nushell environment
configure_nushell_environment() {
    local username="$1"
    local configs_dir="$2"
    local user_home="/home/$username"
    local nu_config_dir="$user_home/.config/nushell"
    
    mkdir -p "$nu_config_dir"
    
    if [ ! -f "$nu_config_dir/config.nu" ]; then
        if [ -f "$configs_dir/config.nu" ]; then
            cp "$configs_dir/config.nu" "$nu_config_dir/config.nu"
            print_success "Deployed nushell configuration from: configs/shell/config.nu"
        else
            # Fallback to inline config
            cat > "$nu_config_dir/config.nu" << 'EOF'
# ALIE Basic Nushell Configuration
$env.config = {
  show_banner: false
  edit_mode: emacs
  shell_integration: true
  history: {
    max_size: 10000
    sync_on_enter: true
    file_format: "plaintext"
  }
  completions: {
    algorithm: "fuzzy"
    case_sensitive: false
    quick: true
    partial: true
    external: {
      enable: true
      max_results: 100
      completer: null
    }
  }
  filesize: {
    metric: true
    format: "auto"
  }
  table: {
    mode: rounded
    index_mode: always
    show_empty: true
    padding: { left: 1, right: 1 }
    trim: {
      methodology: wrapping
      wrapping_try_keep_words: true
      truncating_suffix: "..."
    }
    header_on_separator: false
  }
  prompt: "# "
  menus: []
}

# Useful aliases
alias ll = ls -l
alias la = ls -a
alias lla = ls -la
alias .. = cd ..
alias ... = cd ../..
alias grep = grep --color=auto
alias df = df -h
alias free = free -h

# Add local bin to PATH
$env.PATH = ($env.PATH | split row (char esep) | prepend $"($env.HOME)/.local/bin")
EOF
            print_warning "Using inline nushell configuration (config file not found)"
        fi
        chown -R "$username:$username" "$nu_config_dir"
    fi
}

# Change user shell safely
# Usage: change_user_shell <username> <shell_name>
change_user_shell() {
    local username="$1"
    local shell_name="$2"
    local shell_path
    
    shell_path=$(get_shell_path "$shell_name")
    
    if [ -z "$shell_path" ]; then
        print_error_detailed \
            "Unknown shell: $shell_name" \
            "The specified shell is not supported by the system." \
            "Choose from supported shells (bash, zsh, fish, dash, tcsh, ksh, nushell)." \
            "echo 'Supported shells: bash zsh fish dash tcsh ksh nushell'"
        return 1
    fi
    
    print_info "Changing shell for $username to $shell_name..."
    
    if chsh -s "$shell_path" "$username"; then
        print_success "Shell changed to: $shell_path"
        return 0
    else
        print_error_detailed \
            "Failed to change shell for $username" \
            "Could not set the user's default shell, affecting login environment." \
            "Check user exists and shell is installed." \
            "id $username && which $shell_path && chsh -s $shell_path $username"
        return 1
    fi
}

# =============================================================================
# PACKAGE MANAGEMENT FUNCTIONS - Installation State Checks
# =============================================================================
# Functions to check package installation status and manage dependencies
# Critical for ensuring required packages are available before proceeding

# Check if a package is installed
# Queries pacman database to verify package installation status
# Usage: is_package_installed <package_name>
# Example: is_package_installed "linux"
# Returns: 0 if installed, 1 if not installed
is_package_installed() {
    local package="$1"
    pacman -Qq "$package" &>/dev/null
}

# Check if multiple packages are installed
# Verifies installation status of multiple packages at once
# Useful for dependency checking before complex operations
# Usage: are_packages_installed <package1> <package2> ...
# Returns: 0 if all installed, 1 if any missing
are_packages_installed() {
    local packages=("$@")
    local missing_packages=()

    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            missing_packages+=("$package")
        fi
    done

    if [ ${#missing_packages[@]} -eq 0 ]; then
        return 0
    else
        print_warning "Missing packages: ${missing_packages[*]}"
        return 1
    fi
}

# Install packages only if not already installed
# Smart installation that skips already installed packages
# Saves time and bandwidth during installation process
# Usage: ensure_packages_installed <package1> <package2> ...
# Returns: 0 on success, 1 on failure
ensure_packages_installed() {
    local packages=("$@")
    local packages_to_install=()

    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            packages_to_install+=("$package")
        fi
    done

    if [ ${#packages_to_install[@]} -eq 0 ]; then
        print_info "All packages already installed"
        return 0
    fi

    print_info "Installing packages: ${packages_to_install[*]}"

    if install_packages "${packages_to_install[@]}"; then
        print_success "Packages installed successfully"
        return 0
    else
        print_error_detailed \
            "Failed to install packages: ${packages_to_install[*]}" \
            "Required packages could not be installed, preventing system functionality." \
            "Check package names and repository availability." \
            "run_privileged 'pacman -Ss ${packages_to_install[*]}' or run_privileged 'pacman -Syu'"
        return 1
    fi
}

# Check if Xorg server is installed
# Convenience function for X11/Wayland display server detection
# Returns: 0 if installed, 1 if not installed
is_xorg_installed() {
    is_package_installed "xorg-server"
}

# Check if Wayland is installed
# Convenience function for Wayland display server detection
# Returns: 0 if installed, 1 if not installed
is_wayland_installed() {
    is_package_installed "wayland"
}

# Check if display manager is installed
# Verifies installation of common display managers
# Usage: is_display_manager_installed <dm_name>
# Supported: sddm, gdm, lightdm
# Returns: 0 if installed, 1 if not installed or unsupported
is_display_manager_installed() {
    local dm_name="$1"

    case "$dm_name" in
        "sddm") is_package_installed "sddm" ;;
        "gdm") is_package_installed "gdm" ;;
        "lightdm") is_package_installed "lightdm" ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# AUR HELPER UNIVERSAL FUNCTIONS - Arch User Repository Support
# =============================================================================
# Provides unified interface to different AUR helpers (yay, paru, pacman)
# Handles AUR package installation with fallback and error recovery
# Critical for installing packages not available in official repositories

# Get the preferred AUR helper (saved from installation or auto-detect)
# Checks saved preference first, then auto-detects available helpers
# Preference order: paru > yay > pacman (fallback)
# Returns: name of detected AUR helper
get_aur_helper() {
    # First try to load saved preference
    local saved_helper
    saved_helper=$(load_install_info "aur_helper" 2>/dev/null || echo "")

    if [ -n "$saved_helper" ] && command -v "$saved_helper" &>/dev/null; then
        echo "$saved_helper"
        return 0
    fi

    # Auto-detect if no preference saved
    if command -v paru &>/dev/null; then
        echo "paru"
        return 0
    fi

    if command -v yay &>/dev/null; then
        echo "yay"
        return 0
    fi

    if command -v pacman &>/dev/null; then
        echo "pacman"
        return 0
    fi

    print_error "No package manager found (yay, paru, or pacman)"
    return 1
}

# Universal AUR package installation
# Installs packages using the detected AUR helper
# Handles different command-line interfaces transparently
# Usage: aur_install <package1> <package2> ...
# Returns: 0 on success, 1 on failure
aur_install() {
    local packages=("$@")
    local helper
    helper=$(get_aur_helper)

    if [ -z "$helper" ]; then
        print_error_detailed \
            "No AUR helper available" \
            "Cannot install AUR packages without a package manager (yay, paru, or pacman)." \
            "Install an AUR helper first or use pacman for official repositories only." \
            "run_privileged 'pacman -S yay' or run_privileged 'pacman -S paru'"
        return 1
    fi

    print_info "Installing packages using $helper: ${packages[*]}"

    case "$helper" in
        "paru")
            paru -S --needed --noconfirm "${packages[@]}"
            ;;
        "yay")
            yay -S --needed --noconfirm "${packages[@]}"
            ;;
        "pacman")
            sudo pacman -S --needed --noconfirm "${packages[@]}"
            ;;
        *)
            print_error_detailed \
                "Unknown package manager: $helper" \
                "The detected AUR helper is not supported by this system." \
                "Install a supported AUR helper (yay, paru) or use pacman." \
                "run_privileged 'pacman -S yay' or run_privileged 'pacman -S paru'"
            return 1
            ;;
    esac
}

# Universal AUR system update
# Updates all packages using the detected AUR helper
# Includes both official repos and AUR packages
# Usage: aur_update
# Returns: 0 on success, 1 on failure
aur_update() {
    local helper
    helper=$(get_aur_helper)

    if [ -z "$helper" ]; then
        print_error_detailed \
            "No AUR helper available" \
            "Cannot update system without a package manager (yay, paru, or pacman)." \
            "Install an AUR helper first or use pacman for official repositories only." \
            "run_privileged 'pacman -S yay' or run_privileged 'pacman -S paru'"
        return 1
    fi

    print_info "Updating system using $helper..."

    case "$helper" in
        "paru")
            paru -Syu --noconfirm
            ;;
        "yay")
            yay -Syu --noconfirm
            ;;
        "pacman")
            sudo pacman -Syu --noconfirm
            ;;
        *)
            print_error_detailed \
                "Unknown package manager: $helper" \
                "The detected AUR helper is not supported by this system." \
                "Install a supported AUR helper (yay, paru) or use pacman." \
                "run_privileged 'pacman -S yay' or run_privileged 'pacman -S paru'"
            return 1
            ;;
    esac
}

# Universal AUR package search
# Searches for packages using the detected AUR helper
# Useful for finding available packages before installation
# Usage: aur_search <search_term>
# Returns: 0 on success, 1 on failure
aur_search() {
    local search_term="$1"
    local helper
    helper=$(get_aur_helper)

    if [ -z "$helper" ]; then
        print_error_detailed \
            "No AUR helper available" \
            "Cannot search packages without a package manager (yay, paru, or pacman)." \
            "Install an AUR helper first or use pacman for official repositories only." \
            "run_privileged 'pacman -S yay' or run_privileged 'pacman -S paru'"
        return 1
    fi

    print_info "Searching packages using $helper: $search_term"

    case "$helper" in
        "paru")
            paru -Ss "$search_term"
            ;;
        "yay")
            yay -Ss "$search_term"
            ;;
        "pacman") 
        # NOTE: pacman does not search AUR, only official repos
            pacman -Ss "$search_term"
            ;;
        *)
            print_error_detailed \
                "Unknown package manager: $helper" \
                "The detected AUR helper is not supported by this system." \
                "Install a supported AUR helper (yay, paru) or use pacman." \
                "run_privileged 'pacman -S yay' or run_privileged 'pacman -S paru'"
            return 1
            ;;
    esac
}

# Install packages with retry logic and fallback
aur_install_with_retry() {
    local packages=("$@")
    local failed_packages=()
    
    # Try to install all packages at once first
    print_info "Installing packages: ${packages[*]}"
    
    if aur_install "${packages[@]}"; then
        print_success "All packages installed successfully"
        return 0
    fi
    
    # If batch installation fails, try one by one
    print_warning "Batch installation failed, trying individual packages"
    local failed_count=0
    
    for package in "${packages[@]}"; do
        print_info "Installing: $package"
        
        if ! aur_install "$package"; then
            print_error_detailed \
                "Failed to install: $package" \
                "Individual package installation failed during retry attempt." \
                "Check package availability and dependencies." \
                "run_privileged 'pacman -Ss $package' or run_privileged 'pacman -Si $package'"
            failed_packages+=("$package")
            ((failed_count++))
        else
            print_success "Installed: $package"
        fi
    done
    
    if [ $failed_count -eq 0 ]; then
        print_success "All packages installed individually"
        return 0
    elif [ $failed_count -lt ${#packages[@]} ]; then
        print_warning "Partial installation completed ($failed_count failures)"
        print_warning "Failed packages: ${failed_packages[*]}"
        return 2  # Partial success
    else
        print_error_detailed \
            "All packages failed to install" \
            "No packages could be installed despite retry attempts." \
            "Check network, repositories, and package availability." \
            "run_privileged 'pacman -Syu' or check: run_privileged 'pacman -Ss ${packages[*]}'"
        print_error_detailed \
            "Failed packages: ${failed_packages[*]}" \
            "These packages could not be installed from any source." \
            "Verify package names and check AUR repository status." \
            "run_privileged 'pacman -Ss ${failed_packages[*]}' or visit: https://aur.archlinux.org/"
        return 1
    fi
}

# Check if AUR helper supports AUR packages
aur_helper_supports_aur() {
    local helper
    helper=$(get_aur_helper)
    
    case "$helper" in
        "paru"|"yay")
            return 0  # Supports AUR
            ;;
        "pacman")
            return 1  # Only official repos
            ;;
        *)
            return 1  # Unknown, assume no AUR support
            ;;
    esac
}

# Check if debug packages are enabled
aur_debug_enabled() {
    local debug_setting
    debug_setting=$(load_install_info "aur_helper_debug" 2>/dev/null || echo "n")
    [[ "$debug_setting" == "y" ]]
}

# Show current AUR helper configuration
show_aur_config() {
    local helper
    helper=$(get_aur_helper)
    local debug_enabled
    debug_enabled=$(aur_debug_enabled && echo "enabled" || echo "disabled")
    
    print_info "AUR Helper Configuration:"
    echo "  - Helper: $helper"
    echo "  - Debug packages: $debug_enabled"
    
    case "$helper" in
        "yay")
            if [ -f "$HOME/.config/yay/config.json" ]; then
                echo "  - Config file: ~/.config/yay/config.json [OK]"
            else
                echo "  - Config file: ~/.config/yay/config.json [--]"
            fi
            ;;
        "paru")
            if [ -f "$HOME/.config/paru/paru.conf" ]; then
                echo "  - Config file: ~/.config/paru/paru.conf [OK]"
            else
                echo "  - Config file: ~/.config/paru/paru.conf [--]"
            fi
            ;;
    esac
    
    if aur_debug_enabled && [ -f "$HOME/.makepkg.conf" ]; then
        echo "  - Makepkg config: ~/.makepkg.conf [OK]"
    elif aur_debug_enabled; then
        echo "  - Makepkg config: ~/.makepkg.conf [--]"
    fi
}

# =============================================================================
# SYSTEM DETECTION FUNCTIONS - Hardware and Environment Analysis
# =============================================================================
# Detects system characteristics needed for proper configuration
# Critical for bootloader setup, initramfs configuration, and hardware-specific packages

# Detect boot mode (UEFI vs BIOS)
# Determines firmware type by checking for EFI variables directory
# Critical for bootloader selection and partition scheme validation
# Returns: "UEFI" or "BIOS"
detect_boot_mode() {
    if [ -d /sys/firmware/efi/efivars ]; then
        echo "UEFI"
    elif [ -d /sys/firmware/efi ]; then
        echo "UEFI"
    else
        echo "BIOS"
    fi
}

# Detect x86-64 microarchitecture level
# Determines the x86-64 level (v1-v4) based on CPU flags
# Returns: x86-64 level (1-4) or "unknown"
detect_x86_64_level() {
    if ! command -v awk &>/dev/null; then
        echo "unknown"
        return 1
    fi

    # Use awk to check CPU flags from /proc/cpuinfo
    awk '
    BEGIN {
        level = 0
        while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
        if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
        if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
        if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
        if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
        if (level > 0) { print "x86-64-v" level; exit level + 1 }
        exit 1
    }' 2>/dev/null || echo "unknown"
}

# Detect CPU vendor and microcode package
# Analyzes /proc/cpuinfo to determine CPU manufacturer
# Used to install appropriate microcode updates for security
# Returns: "intel", "amd", or "unknown"
detect_cpu_vendor() {
    if grep -q "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
        echo "intel"
    elif grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then
        echo "amd"
    else
        echo "unknown"
    fi
}

# Get microcode package for detected CPU
# Maps CPU vendor to appropriate microcode package name
# Returns: "intel-ucode", "amd-ucode", or empty string
get_microcode_package() {
    local cpu_vendor
    cpu_vendor=$(detect_cpu_vendor)
    case "$cpu_vendor" in
        intel) echo "intel-ucode" ;;
        amd) echo "amd-ucode" ;;
        *) echo "" ;;
    esac
}

# Detect if system has separate home partition
# Checks if /home is mounted separately from root
# Affects partition layout and backup strategies
# Returns: "yes" or "no"
detect_separate_home() {
    if mountpoint -q /mnt/home 2>/dev/null; then
        echo "yes"
    elif findmnt /home 2>/dev/null | grep -q /dev; then
        echo "yes"
    else
        echo "no"
    fi
}

# Detect partition table type for a disk
# Uses parted to determine if disk uses GPT or MBR partition table
# Critical for bootloader configuration (BIOS-GPT needs bios_grub partition)
# Usage: detect_partition_table <disk_device>
# Returns: "GPT", "MBR", or "unknown"
detect_partition_table() {
    local disk="${1:-}"
    if [ -z "$disk" ]; then
        echo "unknown"
        return 1
    fi

    if ! [ -b "$disk" ]; then
        echo "unknown"
        return 1
    fi

    # Use parted to detect partition table type
    local pt_type
    pt_type=$(parted -s "$disk" print 2>/dev/null | grep "Partition Table:" | awk '{print $3}')
    case "$pt_type" in
        gpt) echo "GPT" ;;
        msdos) echo "MBR" ;;
        *) echo "unknown" ;;
    esac
}

# Detect root filesystem type
# Determines filesystem type of root partition
# Critical for initramfs configuration and bootloader parameters
# Usage: detect_root_filesystem [mount_point]
# Returns: filesystem type (ext4, btrfs, xfs, etc.) or "unknown"
detect_root_filesystem() {
    local root_mount="${1:-/}"
    local fs_type
    fs_type=$(findmnt -n -o FSTYPE "$root_mount" 2>/dev/null)
    echo "${fs_type:-unknown}"
}

# Get partition that contains a mount point
# Finds the device partition backing a mount point
# Used for UUID detection and partition identification
# Usage: get_partition_from_mount <mount_point>
# Returns: partition device path or empty string
get_partition_from_mount() {
    local mount_point="${1:-}"
    if [ -z "$mount_point" ]; then
        echo ""
        return 1
    fi

    local device
    device=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null)
    echo "$device"
}

# Comprehensive system detection - populates global variables
detect_system_info() {
    # Basic detection
    BOOT_MODE=$(detect_boot_mode)
    CPU_VENDOR=$(detect_cpu_vendor)
    CPU_X86_64_LEVEL=$(detect_x86_64_level)
    MICROCODE_PKG=$(get_microcode_package)
    ROOT_FS=$(detect_root_filesystem "/mnt")
    
    # Display CPU information
    print_info "Detected CPU vendor: $CPU_VENDOR"
    if [ "$CPU_X86_64_LEVEL" != "unknown" ]; then
        print_info "Detected x86-64 level: $CPU_X86_64_LEVEL"
    else
        print_warning "Could not detect x86-64 microarchitecture level"
    fi
    
    # Partition detection
    ROOT_PARTITION=$(get_partition_from_mount "/mnt")
    EFI_PARTITION=""
    BIOS_BOOT_PARTITION=""
    HOME_PARTITION=""
    SWAP_PARTITION=""
    
    # EFI partition detection
    if [ "$BOOT_MODE" = "UEFI" ]; then
        EFI_PARTITION=$(get_partition_from_mount "/mnt/boot")
        if [ -z "$EFI_PARTITION" ]; then
            EFI_PARTITION=$(get_partition_from_mount "/boot")
        fi
    fi
    
    # Home partition detection  
    if [ "$(detect_separate_home)" = "yes" ]; then
        HOME_PARTITION=$(get_partition_from_mount "/mnt/home")
        if [ -z "$HOME_PARTITION" ]; then
            HOME_PARTITION=$(get_partition_from_mount "/home")
        fi
    fi
    
    # Swap partition detection
    local swap_dev
    swap_dev=$(swapon --show --noheadings 2>/dev/null | head -n1 | awk '{print $1}')
    if [ -n "$swap_dev" ]; then
        SWAP_PARTITION="$swap_dev"
    fi
    
    # Partition table detection
    PARTITION_TABLE="unknown"  # Default value
    if [ -n "$ROOT_PARTITION" ] && [ -b "$ROOT_PARTITION" ]; then
        local root_disk
        root_disk=$(echo "$ROOT_PARTITION" | sed 's/[0-9]*$//' | sed 's/p$//')
        
        # Verify disk exists and is accessible
        if [ -b "$root_disk" ]; then
            # Try multiple methods to detect partition table
            if command -v parted &>/dev/null; then
                local detected_table
                detected_table=$(parted -s "$root_disk" print 2>/dev/null | grep "Partition Table:" | awk '{print $3}' | tr '[:upper:]' '[:lower:]')
                case "$detected_table" in
                    gpt|msdos)
                        PARTITION_TABLE="$detected_table"
                        ;;
                    *)
                        PARTITION_TABLE="unknown"
                        ;;
                esac
            else
                # Fallback: try to detect from partition naming
                if [[ "$ROOT_PARTITION" =~ nvme[0-9]+n[0-9]+p[0-9]+ ]] || [[ "$ROOT_PARTITION" =~ sd[a-z][0-9]+ ]] || [[ "$ROOT_PARTITION" =~ hd[a-z][0-9]+ ]]; then
                    # Check if it's likely GPT (partition number > 4 often indicates GPT)
                    local part_num
                    part_num=$(echo "$ROOT_PARTITION" | grep -o '[0-9]*$')
                    if [ "$part_num" -gt 4 ] 2>/dev/null; then
                        PARTITION_TABLE="gpt"
                    else
                        PARTITION_TABLE="msdos"
                    fi
                else
                    PARTITION_TABLE="unknown"
                fi
            fi
            
            if [ "$PARTITION_TABLE" != "unknown" ]; then
                print_info "Detected partition table: $PARTITION_TABLE on disk $root_disk"
            else
                print_warning "Could not detect partition table type on $root_disk"
            fi
        else
            print_warning "Root disk $root_disk not accessible"
        fi
    else
        print_warning "Root partition not detected or not accessible, cannot determine partition table"
    fi
    
    # Set defaults for missing values
    MICROCODE_INSTALLED="${MICROCODE_PKG:+yes}"
    MICROCODE_INSTALLED="${MICROCODE_INSTALLED:-no}"
}

# Get UUID of a partition
# Usage: get_partition_uuid "/dev/sda1"
get_partition_uuid() {
    local partition="$1"
    if [ -z "$partition" ]; then
        return 1
    fi
    
    # Try blkid first (most reliable)
    local uuid
    uuid=$(blkid -s UUID -o value "$partition" 2>/dev/null)
    if [ -n "$uuid" ]; then
        echo "$uuid"
        return 0
    fi
    
    # Fallback to lsblk
    uuid=$(lsblk -no UUID "$partition" 2>/dev/null | head -n1)
    if [ -n "$uuid" ]; then
        echo "$uuid"
        return 0
    fi
    
    return 1
}

# Get filesystem modules needed for mkinitcpio based on root filesystem
# Usage: get_fs_modules "btrfs"
get_fs_modules() {
    local root_fs="$1"
    
    case "$root_fs" in
        "btrfs")
            echo "btrfs"
            ;;
        "ext4")
            echo "ext4"
            ;;
        "xfs")
            echo "xfs"
            ;;
        "zfs")
            echo "zfs"
            ;;
        "f2fs")
            echo "f2fs"
            ;;
        "nilfs2")
            echo "nilfs2"
            ;;
        "jfs")
            echo "jfs"
            ;;
        *)
            echo "ext4"  # fallback
            ;;
    esac
}

# Configure dracut.conf with appropriate modules
# Usage: configure_dracut "btrfs"
configure_dracut() {
    local root_fs="$1"
    local dracut_conf="/etc/dracut.conf"
    
    if [ ! -f "$dracut_conf" ]; then
        print_error_detailed \
            "dracut.conf not found at $dracut_conf" \
            "Cannot configure initramfs without dracut configuration file." \
            "Ensure dracut is installed and configuration file exists." \
            "run_privileged 'pacman -S dracut' or check: ls -la $dracut_conf"
        return 1
    fi
    
    print_info "Configuring dracut.conf for $root_fs filesystem..."
    
    # Get required modules for the filesystem
    local fs_modules
    fs_modules=$(get_fs_modules "$root_fs")
    
    # Backup original file
    cp "$dracut_conf" "${dracut_conf}.backup"
    
    # Add filesystem modules to dracut configuration
    # Check if add_drivers is already configured
    if grep -q "^add_drivers+=" "$dracut_conf"; then
        # Check if module is already in add_drivers
        if grep -q "^add_drivers+=\"$fs_modules" "$dracut_conf"; then
            print_info "Module $fs_modules already configured in dracut.conf"
        else
            # Add module to existing add_drivers line
            sed -i "s|^add_drivers+=\"|add_drivers+=\"$fs_modules |" "$dracut_conf"
            print_success "Added $fs_modules module to dracut.conf"
        fi
    else
        # Add new add_drivers line
        echo "add_drivers+=\"$fs_modules\"" >> "$dracut_conf"
        print_success "Added $fs_modules module to dracut.conf"
    fi
    
    # Regenerate initramfs with dracut
    print_info "Regenerating initramfs with dracut..."
    if dracut --regenerate-all --force; then
        print_success "Initramfs regenerated successfully with dracut"
    else
        print_error_detailed \
            "Failed to regenerate initramfs with dracut" \
            "Initramfs regeneration failed, preventing proper system boot." \
            "Check dracut configuration and filesystem modules." \
            "run_privileged 'dracut --regenerate-all --force' or check: run_privileged 'journalctl -xe' for details"
        return 1
    fi
}

# Configure mkinitcpio.conf with appropriate modules
# Usage: configure_mkinitcpio "btrfs"
configure_mkinitcpio() {
    local root_fs="$1"
    local mkinitcpio_conf="/etc/mkinitcpio.conf"
    
    if [ ! -f "$mkinitcpio_conf" ]; then
        print_error_detailed \
            "mkinitcpio.conf not found at $mkinitcpio_conf" \
            "Cannot configure initramfs without mkinitcpio configuration file." \
            "Ensure mkinitcpio is installed and configuration file exists." \
            "run_privileged 'pacman -S mkinitcpio' or check: ls -la $mkinitcpio_conf"
        return 1
    fi
    
    print_info "Configuring mkinitcpio.conf for $root_fs filesystem..."
    
    # Get required modules for the filesystem
    local fs_modules
    fs_modules=$(get_fs_modules "$root_fs")
    
    # Backup original file
    cp "$mkinitcpio_conf" "${mkinitcpio_conf}.backup"
    
    # Add filesystem modules to MODULES array if not already present
    if ! grep -q "^MODULES=" "$mkinitcpio_conf"; then
        print_error_detailed \
            "MODULES line not found in mkinitcpio.conf" \
            "Cannot configure initramfs modules without proper configuration file structure." \
            "Ensure mkinitcpio.conf is valid or reinstall mkinitcpio package." \
            "run_privileged 'pacman -S mkinitcpio' or check: grep -n 'MODULES' $mkinitcpio_conf"
        return 1
    fi
    
    # Check if module is already in MODULES
    if grep -q "^MODULES=.*$fs_modules" "$mkinitcpio_conf"; then
        print_info "Module $fs_modules already configured in mkinitcpio.conf"
    else
        # Add module to MODULES array
        sed -i "s/^MODULES=(/MODULES=($fs_modules /" "$mkinitcpio_conf"
        print_success "Added $fs_modules module to mkinitcpio.conf"
    fi
    
    # Regenerate initramfs
    print_info "Regenerating initramfs..."
    if mkinitcpio -P; then
        print_success "Initramfs regenerated successfully"
    else
        print_error_detailed \
            "Failed to regenerate initramfs" \
            "Initramfs regeneration failed, preventing proper system boot." \
            "Check filesystem modules and mkinitcpio configuration." \
            "run_privileged 'mkinitcpio -P' or check: run_privileged 'journalctl -xe' for details"
        return 1
    fi
}

# Configure GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub
# Usage: configure_grub_defaults "resume=UUID=xxx" "rootflags=subvol=@"
configure_grub_defaults() {
    local grub_default="/etc/default/grub"

    if [ ! -f "$grub_default" ]; then
        print_error_detailed \
            "GRUB default config not found at $grub_default" \
            "Cannot configure bootloader without GRUB configuration file." \
            "Ensure GRUB is installed and configuration file exists." \
            "run_privileged 'pacman -S grub' or check: ls -la $grub_default"
        return 1
    fi

    print_info "Configuring GRUB default parameters..."

    # Backup original file
    cp "$grub_default" "${grub_default}.backup"

    # Build the parameter string for GRUB_CMDLINE_LINUX_DEFAULT
    local current_params=""
    if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_default"; then
        current_params=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_default" | sed 's/GRUB_CMDLINE_LINUX_DEFAULT="//;s/"$//')
    fi

    # Combine existing and new parameters
    local new_params="$current_params"
    for param in "$@"; do
        if [ -n "$param" ]; then
            # Check if parameter is already present
            if [[ "$new_params" != *"$param"* ]]; then
                if [ -n "$new_params" ]; then
                    new_params="$new_params $param"
                else
                    new_params="$param"
                fi
            fi
        fi
    done

    # Add recommended default parameters if not already present
    local recommended_params=("quiet" "udev.log_priority=3" "vt.global_cursor_default=0" "loglevel=3")
    for param in "${recommended_params[@]}"; do
        if [[ "$new_params" != *"$param"* ]]; then
            if [ -n "$new_params" ]; then
                new_params="$new_params $param"
            else
                new_params="$param"
            fi
        fi
    done

    # Update GRUB_CMDLINE_LINUX_DEFAULT
    if [ -n "$new_params" ]; then
        sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$new_params\"|" "$grub_default"
        print_success "Updated GRUB_CMDLINE_LINUX_DEFAULT: $new_params"
    else
        print_info "No GRUB parameters to update"
    fi

    # Configure other GRUB settings according to Arch Wiki best practices
    print_info "Configuring additional GRUB settings..."

    # Set GRUB_DEFAULT to saved (remember last boot entry)
    if ! grep -q "^GRUB_DEFAULT=" "$grub_default" || grep -q "^GRUB_DEFAULT=0$" "$grub_default"; then
        sed -i 's|^GRUB_DEFAULT=.*|GRUB_DEFAULT=saved|' "$grub_default"
        print_info "Set GRUB_DEFAULT=saved"
    fi

    # Set GRUB_TIMEOUT to 5 seconds (reasonable default)
    if ! grep -q "^GRUB_TIMEOUT=" "$grub_default" || grep -q "^GRUB_TIMEOUT=0$" "$grub_default"; then
        sed -i 's|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=5|' "$grub_default"
        print_info "Set GRUB_TIMEOUT=5"
    fi

    # Disable OS prober to avoid detecting other OS unnecessarily
    if ! grep -q "^GRUB_DISABLE_OS_PROBER=" "$grub_default"; then
        echo "GRUB_DISABLE_OS_PROBER=false" >> "$grub_default"
        print_info "Added GRUB_DISABLE_OS_PROBER=false"
    fi

    # Set GRUB_TIMEOUT_STYLE to menu for better UX
    if ! grep -q "^GRUB_TIMEOUT_STYLE=" "$grub_default"; then
        echo "GRUB_TIMEOUT_STYLE=menu" >> "$grub_default"
        print_info "Added GRUB_TIMEOUT_STYLE=menu"
    fi

    # Set GRUB_CMDLINE_LINUX for parameters that apply to all kernels
    if ! grep -q "^GRUB_CMDLINE_LINUX=" "$grub_default"; then
        echo "GRUB_CMDLINE_LINUX=\"\"" >> "$grub_default"
        print_info "Added GRUB_CMDLINE_LINUX (empty by default)"
    fi

    # Always regenerate GRUB configuration after installation or parameter changes
    print_info "Regenerating GRUB configuration..."
    if grub-mkconfig -o /boot/grub/grub.cfg; then
        print_success "GRUB configuration regenerated successfully"
    else
        print_error_detailed \
            "Failed to regenerate GRUB configuration" \
            "GRUB configuration update failed, may cause boot issues." \
            "Check GRUB installation and configuration syntax." \
            "run_privileged 'grub-mkconfig -o /boot/grub/grub.cfg' or check: run_privileged 'grub-install --target=i386-pc /dev/sdX'"
        return 1
    fi
}

# Configure boot system for the installed filesystem and partitions
# This should be called from within chroot (script 101)
configure_boot_system() {
    local root_fs="$ROOT_FS"
    local partition_scheme="${PARTITION_SCHEME:-unknown}"
    local bootloader="${BOOTLOADER:-grub}"
    
    print_info "Configuring boot system for $root_fs filesystem with $bootloader..."
    
    # Check if using dracut or mkinitcpio
    local initramfs_generator="mkinitcpio"
    if command -v dracut &>/dev/null && [ -f /etc/dracut.conf ]; then
        initramfs_generator="dracut"
        print_info "Detected dracut as initramfs generator"
    else
        print_info "Using mkinitcpio as initramfs generator"
    fi
    
    # Configure initramfs with filesystem modules
    if [ "$initramfs_generator" = "dracut" ]; then
        if ! configure_dracut "$root_fs"; then
            print_error_detailed \
                "Failed to configure dracut" \
                "Initramfs configuration failed, preventing proper system boot." \
                "Check dracut installation and filesystem support." \
                "run_privileged 'pacman -S dracut' or run_privileged 'dracut --regenerate-all --force'"
            return 1
        fi
    else
        if ! configure_mkinitcpio "$root_fs"; then
            print_error_detailed \
                "Failed to configure mkinitcpio" \
                "Initramfs configuration failed, preventing proper system boot." \
                "Check mkinitcpio installation and filesystem support." \
                "run_privileged 'pacman -S mkinitcpio' or run_privileged 'mkinitcpio -P'"
            return 1
        fi
    fi
    
    # Configure bootloader-specific parameters
    case "$bootloader" in
        "grub")
            # Prepare GRUB parameters
            local grub_params=()
            
            # Add root UUID parameter for explicit root specification
            if [ -n "$ROOT_UUID" ]; then
                grub_params+=("root=UUID=$ROOT_UUID")
                print_info "Added explicit root parameter: root=UUID=$ROOT_UUID"
            fi
            
            # Add rootfstype parameter for filesystem type
            if [ -n "$root_fs" ]; then
                grub_params+=("rootfstype=$root_fs")
                print_info "Added rootfstype parameter: rootfstype=$root_fs"
            fi
            
            # Add resume parameter for swap
            if [ -n "$SWAP_PARTITION" ]; then
                local swap_uuid
                swap_uuid=$(get_partition_uuid "$SWAP_PARTITION")
                if [ -n "$swap_uuid" ]; then
                    grub_params+=("resume=UUID=$swap_uuid")
                    print_info "Added resume parameter for swap: UUID=$swap_uuid"
                else
                    print_warning "Could not get UUID for swap partition $SWAP_PARTITION"
                fi
            fi
            
            # Add subvolume parameters for Btrfs
            if [ "$root_fs" = "btrfs" ] && [ "$partition_scheme" = "btrfs-subvolumes" ]; then
                grub_params+=("rootflags=subvol=@")
                print_info "Added rootflags=subvol=@ for Btrfs root subvolume"
            fi
            
            # Configure GRUB with the parameters
            # Always call configure_grub_defaults to ensure grub-mkconfig runs
            configure_grub_defaults "${grub_params[@]}"
            ;;
            
        "systemd-boot"|"limine")
            # For systemd-boot and Limine, kernel parameters are configured
            # directly in their configuration files during installation
            print_info "Bootloader $bootloader configured with kernel parameters during installation"
            ;;
            
        *)
            print_warning "Unknown bootloader $bootloader, using default GRUB configuration"
            # Fallback to GRUB configuration
            local grub_params=()
            
            # Add rootfstype parameter for filesystem type
            if [ -n "$root_fs" ]; then
                grub_params+=("rootfstype=$root_fs")
            fi
            
            if [ -n "$SWAP_PARTITION" ]; then
                local swap_uuid
                swap_uuid=$(get_partition_uuid "$SWAP_PARTITION")
                if [ -n "$swap_uuid" ]; then
                    grub_params+=("resume=UUID=$swap_uuid")
                fi
            fi
            
            if [ "$root_fs" = "btrfs" ] && [ "$partition_scheme" = "btrfs-subvolumes" ]; then
                grub_params+=("rootflags=subvol=@")
            fi
            
            if [ ${#grub_params[@]} -gt 0 ]; then
                configure_grub_defaults "${grub_params[@]}"
            else
                # Always ensure grub-mkconfig runs even with no additional parameters
                configure_grub_defaults
            fi
            ;;
    esac
    
    print_success "Boot system configuration completed"
}

# Save comprehensive system configuration
save_system_config() {
    local config_file="${1:-/tmp/.alie-install-config}"
    
    print_info "Saving system configuration to $config_file..."
    
    cat > "$config_file" << EOF
# ALIE Installation Configuration
# Generated on $(date)
# Hostname: $(hostname 2>/dev/null || echo "unknown")

# Boot Configuration
BOOT_MODE="$BOOT_MODE"
PARTITION_TABLE="$PARTITION_TABLE"
BOOTLOADER="${BOOTLOADER:-grub}"

# Partitions
ROOT_PARTITION="$ROOT_PARTITION"
SWAP_PARTITION="$SWAP_PARTITION"
EFI_PARTITION="$EFI_PARTITION"
BIOS_BOOT_PARTITION="$BIOS_BOOT_PARTITION"
HOME_PARTITION="$HOME_PARTITION"

# Filesystems
ROOT_FS="$ROOT_FS"
PARTITION_SCHEME="$PARTITION_SCHEME"
ROOT_UUID="$ROOT_UUID"
ROOT_SUBVOL="$ROOT_SUBVOL"

# Hardware
CPU_VENDOR="$CPU_VENDOR"
CPU_X86_64_LEVEL="$CPU_X86_64_LEVEL"
MICROCODE_PKG="$MICROCODE_PKG"
MICROCODE_INSTALLED="$MICROCODE_INSTALLED"

# Additional flags
SEPARATE_HOME="$([ -n "$HOME_PARTITION" ] && echo "yes" || echo "no")"
AUTO_PARTITIONED="${AUTO_PARTITIONED:-no}"
EOF
    
    print_success "Configuration saved successfully"
}

# Load system configuration
load_system_config() {
    local config_file="${1:-/tmp/.alie-install-config}"
    
    if [ -f "$config_file" ]; then
        print_info "Loading system configuration from $config_file..."
        # shellcheck source=/tmp/.alie-install-config
        # shellcheck disable=SC1091
        source "$config_file"
        print_success "Configuration loaded successfully"
        return 0
    else
        print_warning "Configuration file not found: $config_file"
        return 1
    fi
}

# =============================================================================
# PRIVILEGE ESCALATION UNIVERSAL FUNCTIONS - Secure Command Execution
# =============================================================================
# Provides unified interface to different privilege escalation tools
# Ensures consistent behavior across different privilege escalation methods
# Critical for security and proper permission handling

# Get the configured privilege escalation tool
# Detects and returns the preferred privilege escalation method
# Preference order: run0 > doas > sudo-rs > sudo
# Returns: name of privilege tool or "sudo" as fallback
get_privilege_tool() {
    local priv_tool
    priv_tool=$(get_install_info "privilege_tool" 2>/dev/null || echo "")

    if [ -n "$priv_tool" ]; then
        echo "$priv_tool"
        return 0
    fi

    # Auto-detect if not configured (order by preference: run0 > doas > sudo-rs > sudo)
    if command -v run0 &>/dev/null; then
        echo "run0"
    elif command -v doas &>/dev/null && [ -f /etc/doas.conf ]; then
        echo "doas"
    elif command -v sudo-rs &>/dev/null; then
        echo "sudo-rs"
    elif command -v sudo &>/dev/null; then
        echo "sudo"
    else
        echo "sudo"  # fallback default
    fi
}

# Execute command with appropriate privilege escalation
# Runs command with detected privilege tool, handling different interfaces
# Usage: run_privileged "command with args"
# Example: run_privileged "pacman -S package"
run_privileged() {
    local -a priv_cmd
    priv_cmd=("$@")
    local priv_tool
    priv_tool=$(get_privilege_tool)

    case "$priv_tool" in
        "run0")
            if command -v run0 &>/dev/null; then
                run0 "${priv_cmd[@]}"
            else
                # Fallback to sudo if run0 not available
                sudo "${priv_cmd[@]}"
            fi
            ;;
        "doas")
            if command -v doas &>/dev/null; then
                doas "${priv_cmd[@]}"
            else
                # Fallback to sudo if doas not available
                sudo "${priv_cmd[@]}"
            fi
            ;;
        "sudo-rs")
            if command -v sudo-rs &>/dev/null; then
                sudo-rs "${priv_cmd[@]}"
            else
                # Fallback to regular sudo
                sudo "${priv_cmd[@]}"
            fi
            ;;
        *)
            sudo "${priv_cmd[@]}"
            ;;
    esac
}

# Execute command with privilege escalation and retry logic
# Combines privilege escalation with retry functionality
# Usage: run_privileged_retry "command with args"
run_privileged_retry() {
    run_with_retry "run_privileged $*"
}

# Check if user has privilege escalation configured
# Tests if current user can escalate privileges with configured tool
# Returns: 0 if privilege access available, 1 if not
has_privilege_access() {
    local priv_tool
    priv_tool=$(get_privilege_tool)

    case "$priv_tool" in
        "run0")
            if command -v run0 &>/dev/null; then
                # run0 uses systemd, test with --dry-run if available
                if run0 --help 2>/dev/null | grep -q "\-\-dry-run" ; then
                    if run0 --dry-run true 2>/dev/null; then
                        return 0
                    fi
                else
                    # If no dry-run, assume it works if command exists
                    # run0 typically doesn't require pre-configuration
                    return 0
                fi
            fi
            # Fallback to sudo test
            ;;
        "doas")
            if command -v doas &>/dev/null && [ -f /etc/doas.conf ]; then
                # Test doas access without actually running a command
                if doas -n true 2>/dev/null; then
                    return 0
                fi
            fi
            # Fallback to sudo test
            ;;
        *)
            if command -v sudo &>/dev/null; then
                # Test sudo access
                if sudo -n true 2>/dev/null; then
                    return 0
                fi
            fi
            ;;
    esac

    return 1
}

# Print information about configured privilege escalation
# Displays current privilege tool configuration and status
# Useful for debugging privilege escalation issues
print_privilege_info() {
    local priv_tool
    priv_tool=$(get_privilege_tool)

    print_info "Privilege escalation tool: $priv_tool"

    case "$priv_tool" in
        "run0")
            print_info "run0: Modern systemd privilege escalation"
            if systemctl is-system-running &>/dev/null; then
                print_info "systemd: Active (run0 available)"
            else
                print_warning "systemd: Not active (run0 may not work)"
            fi
            ;;
        "doas")
            if [ -f /etc/doas.conf ]; then
                print_info "doas configuration: /etc/doas.conf (present)"
            else
                print_warning "doas configuration: /etc/doas.conf (missing)"
            fi
            ;;
        "sudo-rs")
            print_info "sudo-rs: Modern Rust implementation"
            ;;
        *)
            print_info "sudo: Traditional implementation"
            ;;
    esac

    # Check for sudo compatibility wrappers
    if [ -f /usr/local/bin/sudo ] && [ "$priv_tool" = "doas" ]; then
        print_info "sudo compatibility wrapper: present"
    fi
}

# =============================================================================
# CLEANUP AND TRAP FUNCTIONS - Error Handling & Recovery
# =============================================================================
# Provides robust error handling and cleanup on script failures
# Ensures system remains in consistent state even when scripts fail
# Critical for preventing partial installations and data corruption

# Setup cleanup trap for error handling
# CRITICAL: Must be called early in scripts to ensure proper cleanup
# Usage: setup_cleanup_trap
# This function sets up traps for proper cleanup on script exit/error
# Handles: EXIT, TERM, INT signals with appropriate cleanup actions
setup_cleanup_trap() {
    # Function to handle cleanup on exit/error
    # shellcheck disable=SC2329  # Function is invoked indirectly via trap
    cleanup() {
        local exit_code=$?
        local line_number=${BASH_LINENO[1]:-${BASH_LINENO[0]}}  # Use caller line number
        local error_timestamp
        error_timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        # Only show cleanup message if there was an error
        if [ "$exit_code" -ne 0 ]; then
            echo "" >&2
            echo "===============================================================================" >&2
            echo "                           *** SCRIPT ERROR ***" >&2
            echo "===============================================================================" >&2
            echo "" >&2

            print_error "Script failed with exit code: $exit_code"
            print_error "Error timestamp: $error_timestamp"
            print_error "Error occurred at line: $line_number"
            print_error "Function: ${FUNCNAME[1]:-main}"
            print_error "File: ${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
            echo "" >&2

            # Show system information
            print_error "System info:"
            echo "  - Hostname: $(hostname 2>/dev/null || echo 'unknown')" >&2
            echo "  - User: $(whoami 2>/dev/null || echo 'unknown')" >&2
            echo "  - PID: $$" >&2
            echo "  - Shell: $SHELL" >&2
            echo "  - Working directory: $(pwd 2>/dev/null || echo 'unknown')" >&2
            echo "" >&2

            # Show last few commands if available
            if [ -n "${BASH_COMMAND:-}" ]; then
                print_error "Last command executed: $BASH_COMMAND"
                echo "" >&2
            fi

            # Show error context based on exit code
            case "$exit_code" in
                1) print_error "Error type: General error (exit code 1)" ;;
                2) print_error "Error type: Misuse of shell builtins (exit code 2)" ;;
                126) print_error "Error type: Command cannot execute (exit code 126)" ;;
                127) print_error "Error type: Command not found (exit code 127)" ;;
                128) print_error "Error type: Invalid argument to exit (exit code 128)" ;;
                130) print_error "Error type: Script terminated by Ctrl+C (exit code 130)" ;;
                139) print_error "Error type: Segmentation fault (exit code 139)" ;;
                *) print_error "Error type: Unknown exit code $exit_code" ;;
            esac
            echo "" >&2

            # Troubleshooting suggestions
            print_error "Troubleshooting suggestions:"
            echo "  - Check system logs: journalctl -xe" >&2
            echo "  - Verify disk space: df -h" >&2
            echo "  - Check network: ping -c 3 8.8.8.8" >&2
            echo "  - Review error messages above for specific issues" >&2
            echo "" >&2

            # Cleanup mounted partitions
            if [ -n "${MOUNTED_PARTITIONS:-}" ]; then
                print_info "Cleaning up mounted partitions..."
                # Unmount in reverse order (last mounted first)
                for ((i=${#MOUNTED_PARTITIONS[@]}-1; i>=0; i--)); do
                    mount_point="${MOUNTED_PARTITIONS[$i]}"
                    if mountpoint -q "$mount_point" 2>/dev/null; then
                        print_info "Unmounting $mount_point..."
                        umount "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null || true
                    fi
                done
            fi

            # Cleanup active swap
            if [ -n "${SWAP_ACTIVE:-}" ]; then
                print_info "Deactivating swap..."
                swapoff "$SWAP_ACTIVE" 2>/dev/null || true
            fi

            # Cleanup AUR build directory if set
            if [ -n "${AUR_BUILD_DIR:-}" ] && [ -d "$AUR_BUILD_DIR" ]; then
                print_info "Cleaning up AUR build directory..."
                rm -rf "$AUR_BUILD_DIR" 2>/dev/null || true
            fi

            echo "" >&2
            echo "===============================================================================" >&2
            print_warning "Cleanup complete - check error details above"
            print_warning "For help, visit: https://github.com/JotaRandom/ALIE/issues"
            echo "===============================================================================" >&2
        fi
    }

    # Set trap for cleanup - separate INT from EXIT/TERM for better responsiveness
    trap cleanup EXIT TERM
    trap 'cleanup; exit 1' INT
}

# Keyboard layout selection function
# Provides interactive keyboard layout selection with common layouts and manual entry
# Sets global KEYMAP variable and loads the selected keymap
# Usage: select_keymap
select_keymap() {
    print_info "The KEYMAP variable defines the console keyboard layout."
    print_info "Keymaps are located in /usr/share/kbd/keymaps/"
    echo ""

    # Common keymaps with layout variants
    local common_keymaps=(
        "us:English (US) - QWERTY"
        "es:Spanish (Spain) - QWERTY"
        "fr:French - AZERTY"
        "de:German - QWERTZ"
        "it:Italian - QWERTY"
        "pt:Portuguese - QWERTY"
        "ru:Russian - JCUKEN"
        "br:Portuguese (Brazil) - QWERTY"
        "la-latin1:Latin American - QWERTY"
        "uk:United Kingdom - QWERTY"
        "be:Belgian - AZERTY"
        "dk:Danish - QWERTY"
        "no:Norwegian - QWERTY"
        "se:Swedish - QWERTY"
        "fi:Finnish - QWERTY"
        "pl:Polish - QWERTY"
        "cz:Czech - QWERTZ"
        "hu:Hungarian - QWERTZ"
        "tr:Turkish - QWERTY"
        "gr:Greek - QWERTY"
        "il:Hebrew - QWERTY"
        "jp:Japanese - QWERTY"
        "kr:Korean - QWERTY"
    )

    echo "==============================================================================="
    echo "                           KEYBOARD LAYOUTS"
    echo "==============================================================================="
    echo ""
    echo "Common keyboard layouts (with layout variants):"
    echo ""

    local i=1
    for keymap_info in "${common_keymaps[@]}"; do
        local keymap_code="${keymap_info%%:*}"
        local keymap_desc="${keymap_info#*:}"
        printf "  %s%2d)%s %-6s - %s\n" "$CYAN" "$i" "$NC" "$keymap_code" "$keymap_desc"
        ((i++))
    done

    echo ""
    echo "==============================================================================="
    printf "  %s99)%s Other (enter manually)\n" "$CYAN" "$NC"
    echo ""
    echo "Variants:"
    echo "  - QWERTY: Standard US/UK layout"
    echo "  - AZERTY: French/Belgian layout"
    echo "  - QWERTZ: German/Czech layout"
    echo "  - JCUKEN: Russian layout"
    echo "  - Bopomofo: Chinese phonetic"
    echo ""

    local choice
    read -r -p "Choose keyboard layout [1-$((${#common_keymaps[@]}+1))] (default: 1): " choice

    if [ -z "$choice" ]; then
        choice=1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#common_keymaps[@]}" ]; then
        KEYMAP="${common_keymaps[$((choice-1))]}"
        KEYMAP="${KEYMAP%%:*}"
    elif [ "$choice" = "99" ]; then
        # Manual entry
        echo ""
        echo "==============================================================================="
        echo "                           MANUAL ENTRY"
        echo "==============================================================================="
        echo ""
        print_info "Available keymaps (showing first 20):"
        echo ""

        local available_keymaps
        mapfile -t available_keymaps < <(find /usr/share/kbd/keymaps/ -type f -name "*.map.gz" -printf "%P\n" | sed 's|.map.gz$||' | sort | head -20)

        for i in "${!available_keymaps[@]}"; do
            printf "  %s\n" "${available_keymaps[$i]}"
        done
        echo ""
        echo "  ... (and more / y mas / 等等)"
        echo ""

        while true; do
            echo "==============================================================================="
            read -r -p "Enter keymap name / Ingrese nombre del mapa (e.g., us, es, fr): " KEYMAP
            if [ -n "$KEYMAP" ] && [ -f "/usr/share/kbd/keymaps/${KEYMAP}.map.gz" ]; then
                break
            else
                print_error_detailed \
                    "Keymap '$KEYMAP' not found. Please try again." \
                    "The specified keyboard layout is not available in the system." \
                    "Choose from available keymaps or check spelling." \
                    "find /usr/share/kbd/keymaps/ -name '*.map.gz' | head -10"
            fi
        done
    else
        print_error "Invalid choice. Using default (us)"
        KEYMAP="us"
    fi
    
    # Load the keymap
    print_info "Loading keymap: $KEYMAP"
    if loadkeys "$KEYMAP" 2>/dev/null; then
        print_success "Keyboard layout set to: $KEYMAP"
    else
        print_error_detailed \
            "Failed to load keymap '$KEYMAP'" \
            "The keyboard layout could not be loaded, affecting console input." \
            "Try a different keymap or continue with default." \
            "loadkeys us (to test default) or check available: localectl list-keymaps"
        echo ""
        echo "Options:"
        echo "  1) Try a different keymap"
        echo "  2) Continue with default (us) keymap"
        echo "  3) Cancel installation"
        echo ""
        read -r -p "Choose option [1-3]: " KEYMAP_CHOICE
        
        case "$KEYMAP_CHOICE" in
            1)
                print_info "Returning to keymap selection..."
                select_keymap
                return  # Exit this call since select_keymap will call itself again
                ;;
            2)
                print_warning "Using default keymap 'us'"
                KEYMAP="us"
                if loadkeys "$KEYMAP" 2>/dev/null; then
                    print_success "Keyboard layout set to: $KEYMAP"
                else
                    print_error_detailed \
                        "Even default keymap 'us' failed to load!" \
                        "System keyboard configuration is broken, preventing proper console input." \
                        "This indicates deeper system issues that need investigation." \
                        "Check kbd package: run_privileged 'pacman -S kbd' or verify system integrity"
                    print_info "This is unusual and may indicate system issues"
                    read -r -p "Continue anyway? (y/N): " CONTINUE_ANYWAY
                    if [[ ! $CONTINUE_ANYWAY =~ ^[Yy]$ ]]; then
                        print_info "Installation cancelled"
                        exit 1
                    fi
                fi
                ;;
            3)
                print_info "Installation cancelled by user"
                exit 1
                ;;
            *)
                print_error "Invalid choice. Using default (us)"
                KEYMAP="us"
                ;;
        esac
    fi
}

# If sourced, don't execute anything
# If run directly, show info
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    show_alie_banner
    echo -e "${CYAN}This is a library file meant to be sourced by other scripts.${NC}"
    echo ""
    echo -e "${YELLOW}Usage in your script:${NC}"
    echo -e "  ${GREEN}source \"\$(dirname \"\$0\")/shared-functions.sh\"${NC}"
    echo ""
    echo -e "${YELLOW}Available functions:${NC}"
    echo "  [+] Color definitions: RED, GREEN, YELLOW, BLUE, CYAN, MAGENTA, NC"
    echo "  [+] print_info, print_success, print_warning, print_error [DEPRECATED], print_step"
    echo "  [+] print_error_detailed (recommended for comprehensive error reporting)"
    echo "  [+] retry_command, wait_for_operation"
    echo "  [+] verify_chroot, require_root, require_non_root"
    echo "  [+] show_alie_banner, show_warning_banner"
    echo "  [+] load_install_info, save_install_info"
    echo "  [+] check_internet, wait_for_internet"
    echo "  [+] is_mounted, safe_unmount"
    echo "  [+] install_packages, update_package_db"
    echo "  [+] get_aur_helper, aur_install, aur_update, aur_search"
    echo "  [+] aur_debug_enabled, show_aur_config"
    echo "  [+] detect_boot_mode, detect_cpu_vendor, detect_x86_64_level, get_microcode_package"
    echo "  [+] detect_system_info, save_system_config, load_system_config"
    echo "  [+] get_privilege_tool, run_privileged, run_privileged_retry, has_privilege_access, print_privilege_info"
    echo "  [+] setup_cleanup_trap"
    echo ""
fi
