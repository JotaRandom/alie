#!/bin/bash
# =============================================================================
# ALIE Shared Functions Library
# =============================================================================
# This file contains common functions used across all ALIE installation scripts
# Source this file at the beginning of each script:
#   source "$LIB_DIR/shared-functions.sh"
#
# NOTE: This file is meant to be sourced, not executed directly.
# The calling script should use 'set -euo pipefail' for proper error handling.
#
# Functions provided:
#   - Color definitions (RED, GREEN, YELLOW, BLUE, CYAN, MAGENTA, NC)
#   - print_info()     - Print informational message in cyan
#   - print_success()  - Print success message in green
#   - print_warning()  - Print warning message in yellow
#   - print_error()    - Print error message in red
#   - print_step()     - Print step header in magenta
#   - retry_command()  - Retry a command with exponential backoff
#   - wait_for_operation() - Poll until condition is met or timeout
#   - verify_chroot()  - Verify script is running in chroot environment
#   - require_root()   - Ensure script is running as root
#   - require_non_root() - Ensure script is NOT running as root
#   - show_alie_banner() - Display ALIE banner
#   - show_warning_banner() - Display warning about experimental nature
#   - And many more...
# =============================================================================

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# =============================================================================
# TTY COMPATIBILITY FUNCTIONS
# =============================================================================

# Get terminal dimensions safely
get_terminal_width() {
    tput cols 2>/dev/null || echo 80
}

get_terminal_height() {
    tput lines 2>/dev/null || echo 24
}

# Check if terminal is too small for banners
is_terminal_small() {
    local width=$(get_terminal_width)
    local height=$(get_terminal_height)
    
    # Consider small if less than 70 columns or 20 lines
    if [ "$width" -lt 70 ] || [ "$height" -lt 20 ]; then
        return 0
    else
        return 1
    fi
}

# Pause for user interaction in TTY
press_any_key() {
    echo ""
    read -p "Press any key to continue..." -n1 -s
    echo ""
}

# Clear screen intelligently based on terminal capabilities
smart_clear() {
    if command -v clear >/dev/null 2>&1; then
        clear
    else
        # Fallback for limited environments
        printf "\033[2J\033[H"
    fi
}

# Show progress indicator for slow operations
show_progress() {
    local message="$1"
    echo -n "${CYAN}${message}${NC}"
    for i in {1..3}; do
        sleep 0.5
        echo -n "."
    done
    echo " ${GREEN}✓${NC}"
}

# =============================================================================
# PRINTING FUNCTIONS
# =============================================================================

print_info() {
    echo -e "${CYAN}??? ${NC}$1"
}

print_success() {
    echo -e "${GREEN}??? ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}??? ${NC}$1"
}

print_error() {
    echo -e "${RED}??? ${NC}$1" >&2
}

print_step() {
    echo ""
    local width=$(get_terminal_width)
    local line_char="#"
    
    # Create separator line based on terminal width
    printf "${MAGENTA}"
    printf "%${width}s\n" | tr ' ' "$line_char"
    printf "  $1\n"
    printf "%${width}s\n" | tr ' ' "$line_char"
    printf "${NC}"
    echo ""
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Retry a command with exponential backoff
# Usage: retry_command <max_attempts> <command>
# Example: retry_command 3 "pacman -Sy"
retry_command() {
    local max_attempts=$1
    shift
    local command="$@"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$command"; then
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                local wait_time=$((attempt * 3))
                print_warning "Command failed (attempt $attempt/$max_attempts)"
                print_info "Retrying in ${wait_time}s..."
                sleep $wait_time
                attempt=$((attempt + 1))
            else
                print_error "Command failed after $max_attempts attempts"
                return 1
            fi
        fi
    done
}

# Wait for an operation to complete by polling
# Usage: wait_for_operation <check_command> <timeout_seconds> <poll_interval>
# Example: wait_for_operation "mountpoint -q /mnt" 30 1
wait_for_operation() {
    local check_command="$1"
    local timeout=${2:-30}
    local interval=${3:-1}
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$check_command" 2>/dev/null; then
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    print_error "Operation timed out after ${timeout}s"
    return 1
}

# =============================================================================
# ENVIRONMENT VALIDATION
# =============================================================================

# Verify the script is running inside a chroot environment
# Returns 0 if in chroot, 1 otherwise
verify_chroot() {
    print_info "Verifying chroot environment..."
    
    # Method 1: Check if root is mounted
    if ! grep -qs '/proc' /proc/mounts; then
        print_error "Not running in chroot environment!"
        print_info "This script must be run from within arch-chroot"
        return 1
    fi
    
    # Method 2: Compare device numbers of / and /proc/1/root/.
    local root_dev=$(stat -c %d:%i /)
    local init_dev=$(stat -c %d:%i /proc/1/root/. 2>/dev/null || echo "")
    
    if [ -n "$init_dev" ] && [ "$root_dev" != "$init_dev" ]; then
        print_success "Running in chroot environment"
        return 0
    fi
    
    # If we can't determine or it looks like we're not in chroot
    print_warning "Could not definitively verify chroot environment"
    read -p "Continue anyway? (y/N): " CONTINUE
    
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        print_error "Aborted by user"
        return 1
    fi
    
    return 0
}

# Check if running as root
# Returns 0 if root, 1 otherwise
# Require root privileges - exits if not root
require_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root!"
        print_info "Please run with: sudo bash $0"
        exit 1
    fi
}

# Require non-root (regular user) - exits if root
require_non_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Do not run this script as root!"
        print_info "Run as your regular user: bash $0"
        exit 1
    fi
}

# Verify system is Arch Linux - exits if not
verify_arch_linux() {
    if [ ! -f /etc/arch-release ]; then
        print_error "This doesn't appear to be an Arch Linux system"
        print_info "This script is designed for Arch Linux only"
        exit 1
    fi
}

# Verify NOT in chroot (for post-install scripts) - exits if in chroot
verify_not_chroot() {
    # Compare device numbers of / and /proc/1/root/.
    if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ] 2>/dev/null; then
        print_error "This script should not be run in chroot"
        print_info "Exit chroot and boot into the installed system first"
        exit 1
    fi
}

# Verify internet connectivity - exits if no internet
verify_internet() {
    if ! check_internet; then
        print_error "No internet connection detected"
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
    
    # Validate DESKTOP_USER exists in config
    if [ -z "${DESKTOP_USER:-}" ]; then
        print_error "DESKTOP_USER not found in install info"
        print_info "This script requires the desktop installation to be completed first"
        exit 1
    fi
    
    # Verify user exists on system
    if ! id "$DESKTOP_USER" &>/dev/null; then
        print_error "User '$DESKTOP_USER' does not exist on this system"
        exit 1
    fi
    
    # Verify we're running as the desktop user
    if [ "$USER" != "$DESKTOP_USER" ]; then
        print_error "This script must be run as user '$DESKTOP_USER'"
        print_info "Please run: su - $DESKTOP_USER -c 'bash $0'"
        exit 1
    fi
    
    print_success "Running as correct user: $DESKTOP_USER"
}

# =============================================================================
# BANNER FUNCTIONS
# =============================================================================

# Display ALIE main banner
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
#############################################
#                                           #
#       AAA    L       I   EEEEEEE          #
#      A   A   L       I   E                #
#     A     A  L       I   E                #
#     AAAAAAA  L       I   EEEEE            #
#     A     A  L       I   E                #
#     A     A  LLLLLLL I   EEEEEEE          #
#                                           #
#  Arch Linux Installation Environment      #
#                                           #
#############################################
EOF
    fi
    
    echo -e "${NC}"
}

# Display warning banner
show_warning_banner() {
    echo -e "${YELLOW}"
    cat << "EOF"
################################################################
#                    **  WARNING  **                        #
################################################################
#  This is an EXPERIMENTAL script provided AS-IS            #
#  without warranties. Review the code before running       #
#  and use at your own risk.                                #
#                                                            #
#  This script will make PERMANENT changes to your system!  #
################################################################
EOF
    echo -e "${NC}"
}

# =============================================================================
# PROGRESS TRACKING FUNCTIONS
# =============================================================================

# Save progress marker
# Usage: save_progress <step_name>
save_progress() {
    local step="$1"
    local progress_file="${ALIE_PROGRESS_FILE:-/tmp/.alie-progress}"
    
    # In live environment
    if [ -d /mnt/root ]; then
        progress_file="/mnt/root/.alie-progress"
    elif [ -f /root/.alie-install-info ]; then
        # In installed system
        progress_file="/root/.alie-progress"
    fi
    
    echo "$step" >> "$progress_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $step" >> "${progress_file}.log"
}

# Check if step is completed
# Usage: is_step_completed <step_name>
is_step_completed() {
    local step="$1"
    local progress_file="${ALIE_PROGRESS_FILE:-/tmp/.alie-progress}"
    
    # In live environment
    if [ -d /mnt/root ]; then
        progress_file="/mnt/root/.alie-progress"
    elif [ -f /root/.alie-install-info ]; then
        # In installed system
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

# Clear progress (for fresh start)
clear_progress() {
    local progress_file="${ALIE_PROGRESS_FILE:-/tmp/.alie-progress}"
    
    rm -f "$progress_file" 2>/dev/null || true
    rm -f "${progress_file}.log" 2>/dev/null || true
    rm -f "/mnt/root/.alie-progress" 2>/dev/null || true
    rm -f "/mnt/root/.alie-progress.log" 2>/dev/null || true
    rm -f "/root/.alie-progress" 2>/dev/null || true
    rm -f "/root/.alie-progress.log" 2>/dev/null || true
    
    print_success "Progress cleared"
}

# =============================================================================
# DATA PERSISTENCE FUNCTIONS
# =============================================================================

# Load installation info from previous script
# Expects file at /root/.alie-install-info
load_install_info() {
    local info_file="${1:-/root/.alie-install-info}"
    
    if [ -f "$info_file" ]; then
        print_info "Loading installation configuration from $info_file..."
        source "$info_file"
        print_success "Configuration loaded successfully"
        
        # Display loaded variables for debugging (optional)
        if [ "${DEBUG:-0}" = "1" ]; then
            print_info "Loaded variables:"
            cat "$info_file" | while read line; do
                echo "  $line"
            done
        fi
        
        return 0
    else
        print_warning "Installation info file not found: $info_file"
        print_warning "Some auto-detection features will be limited"
        return 1
    fi
}

# Save installation info for next script
# Usage: save_install_info <output_file> <var1> <var2> ...
# Example: save_install_info "/mnt/root/.alie-install-info" BOOT_MODE ROOT_PARTITION
save_install_info() {
    local output_file="$1"
    shift
    local variables=("$@")
    
    print_info "Saving installation configuration to $output_file..."
    
    # Create or truncate file
    > "$output_file"
    
    # Write each variable
    for var_name in "${variables[@]}"; do
        # Get the value of the variable
        local var_value="${!var_name}"
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
# NETWORK FUNCTIONS
# =============================================================================

# Check internet connectivity
# Returns 0 if connected, 1 otherwise
check_internet() {
    local test_host="${1:-archlinux.org}"
    local timeout="${2:-5}"
    
    if ping -c 1 -W "$timeout" "$test_host" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Wait for internet connection with retries
# Returns 0 when connected, 1 on timeout
wait_for_internet() {
    local max_attempts="${1:-10}"
    local attempt=1
    
    print_info "Checking internet connectivity..."
    
    while [ $attempt -le $max_attempts ]; do
        if check_internet; then
            print_success "Internet connection verified"
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                print_warning "No internet connection (attempt $attempt/$max_attempts)"
                print_info "Waiting 3 seconds..."
                sleep 3
                attempt=$((attempt + 1))
            else
                print_error "Could not establish internet connection after $max_attempts attempts"
                return 1
            fi
        fi
    done
}

# =============================================================================
# PARTITION HELPERS
# =============================================================================

# Check if a partition is mounted
# Usage: is_mounted <partition>
# Returns 0 if mounted, 1 otherwise
is_mounted() {
    local partition="$1"
    
    if grep -qs "$partition" /proc/mounts; then
        return 0
    else
        return 1
    fi
}

# Safely unmount a partition
# Usage: safe_unmount <mount_point>
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
                print_error "Failed to unmount $mount_point"
                return 1
            fi
        fi
    else
        print_info "$mount_point is not mounted"
        return 0
    fi
}

# =============================================================================
# PACKAGE MANAGER HELPERS
# =============================================================================

# Install packages with retry logic
# Usage: install_packages <package1> <package2> ...
install_packages() {
    local packages=("$@")
    
    print_info "Installing packages: ${packages[*]}"
    
    if retry_command 3 "pacman -S --needed --noconfirm ${packages[*]}"; then
        print_success "Packages installed successfully"
        return 0
    else
        print_error "Failed to install packages: ${packages[*]}"
        return 1
    fi
}

# Update package database with retry
update_package_db() {
    print_info "Updating package database..."
    
    if retry_command 3 "pacman -Syy"; then
        print_success "Package database updated"
        return 0
    else
        print_error "Failed to update package database"
        return 1
    fi
}

# =============================================================================
# END OF SHARED FUNCTIONS
# =============================================================================

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
    echo "  ??? Color definitions: RED, GREEN, YELLOW, BLUE, CYAN, MAGENTA, NC"
    echo "  ??? print_info, print_success, print_warning, print_error, print_step"
    echo "  ??? retry_command, wait_for_operation"
    echo "  ??? verify_chroot, require_root, require_non_root"
    echo "  ??? show_alie_banner, show_warning_banner"
    echo "  ??? load_install_info, save_install_info"
    echo "  ??? check_internet, wait_for_internet"
    echo "  ??? is_mounted, safe_unmount"
    echo "  ??? install_packages, update_package_db"
    echo ""
fi
