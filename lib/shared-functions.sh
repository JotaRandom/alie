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
# shellcheck disable=SC2034
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
press_any_key() {
    echo ""
    read -r -n1 -s -p "Press any key to continue..."
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
    for _ in {1..3}; do
        sleep 0.5
        echo -n "."
    done
    echo " ${GREEN}[OK]${NC}"
}

# =============================================================================
# PRINTING FUNCTIONS
# =============================================================================

print_info() {
    echo -e "${CYAN}[INFO] ${NC}$1"
}

print_success() {
    echo -e "${GREEN}[OK] ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] ${NC}$1"
}

print_error() {
    echo -e "${RED}[ERROR] ${NC}$1" >&2
}

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
# UTILITY FUNCTIONS
# =============================================================================

# Retry a command with exponential backoff
# Usage: retry_command <max_attempts> <command>
# Example: retry_command 3 "pacman -Sy"
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
                local wait_time=$((attempt * 3))
                print_warning "Command failed (attempt $attempt/$max_attempts)"
                print_info "Retrying in ${wait_time}s..."
                sleep "$wait_time"
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
    
    while [ "$elapsed" -lt "$timeout" ]; do
        if eval "$check_command" 2>/dev/null; then
            return 0
        fi
        sleep "$interval"
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

# Save installation info for next script
# Usage: save_install_info <output_file> <var1> <var2> ...
# Example: save_install_info "/mnt/root/.alie-install-info" BOOT_MODE ROOT_PARTITION
save_install_info() {
    local output_file="$1"
    shift
    local variables=("$@")
    
    print_info "Saving installation configuration to $output_file..."
    
    # Create or truncate file
    : > "$output_file"
    
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
    
    while [ "$attempt" -le "$max_attempts" ]; do
        if check_internet; then
            print_success "Internet connection verified"
            return 0
        else
            if [ "$attempt" -lt "$max_attempts" ]; then
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
    echo "  [+] Color definitions: RED, GREEN, YELLOW, BLUE, CYAN, MAGENTA, NC"
    echo "  [+] print_info, print_success, print_warning, print_error, print_step"
    echo "  [+] retry_command, wait_for_operation"
    echo "  [+] verify_chroot, require_root, require_non_root"
    echo "  [+] show_alie_banner, show_warning_banner"
    echo "  [+] load_install_info, save_install_info"
    echo "  [+] check_internet, wait_for_internet"
    echo "  [+] is_mounted, safe_unmount"
    echo "  [+] install_packages, update_package_db"
    echo "  [+] get_aur_helper, aur_install, aur_update, aur_search"
    echo "  [+] aur_debug_enabled, show_aur_config"
    echo "  [+] detect_boot_mode, detect_cpu_vendor, get_microcode_package"
    echo "  [+] detect_system_info, save_system_config, load_system_config"
    echo ""
fi

# =============================================================================
# AUR HELPER UNIVERSAL FUNCTIONS
# =============================================================================

# Get the preferred AUR helper (saved from installation or auto-detect)
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
aur_install() {
    local packages=("$@")
    local helper
    helper=$(get_aur_helper)
    
    if [ -z "$helper" ]; then
        print_error "No AUR helper available"
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
            print_error "Unknown package manager: $helper"
            return 1
            ;;
    esac
}

# Universal AUR system update
aur_update() {
    local helper
    helper=$(get_aur_helper)
    
    if [ -z "$helper" ]; then
        print_error "No AUR helper available"
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
            print_error "Unknown package manager: $helper"
            return 1
            ;;
    esac
}

# Universal AUR package search
aur_search() {
    local search_term="$1"
    local helper
    helper=$(get_aur_helper)
    
    if [ -z "$helper" ]; then
        print_error "No AUR helper available"
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
            pacman -Ss "$search_term"
            ;;
        *)
            print_error "Unknown package manager: $helper"
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
            print_error "Failed to install: $package"
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
        print_error "All packages failed to install"
        print_error "Failed packages: ${failed_packages[*]}"
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
# SYSTEM DETECTION FUNCTIONS
# =============================================================================

# Detect boot mode (UEFI vs BIOS)
detect_boot_mode() {
    if [ -d /sys/firmware/efi/efivars ]; then
        echo "UEFI"
    elif [ -d /sys/firmware/efi ]; then
        echo "UEFI"  
    else
        echo "BIOS"
    fi
}

# Detect CPU vendor and microcode package
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
detect_root_filesystem() {
    local root_mount="${1:-/}"
    local fs_type
    fs_type=$(findmnt -n -o FSTYPE "$root_mount" 2>/dev/null)
    echo "${fs_type:-unknown}"
}

# Get partition that contains a mount point
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
    MICROCODE_PKG=$(get_microcode_package)
    ROOT_FS=$(detect_root_filesystem "/mnt")
    
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
    if [ -n "$ROOT_PARTITION" ]; then
        local root_disk
        root_disk=$(echo "$ROOT_PARTITION" | sed 's/[0-9]*$//' | sed 's/p$//')
        PARTITION_TABLE=$(detect_partition_table "$root_disk")
        
        # BIOS boot partition detection for GPT
        if [ "$BOOT_MODE" = "BIOS" ] && [ "$PARTITION_TABLE" = "GPT" ]; then
            # Try to find BIOS boot partition
            local bios_part
            bios_part=$(parted -s "$root_disk" print 2>/dev/null | grep "bios_grub" | awk '{print $1}')
            if [ -n "$bios_part" ]; then
                BIOS_BOOT_PARTITION="${root_disk}${bios_part}"
            fi
        fi
    fi
    
    # Set defaults for missing values
    MICROCODE_INSTALLED="${MICROCODE_PKG:+yes}"
    MICROCODE_INSTALLED="${MICROCODE_INSTALLED:-no}"
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

# Partitions
ROOT_PARTITION="$ROOT_PARTITION"
SWAP_PARTITION="$SWAP_PARTITION"
EFI_PARTITION="$EFI_PARTITION"
BIOS_BOOT_PARTITION="$BIOS_BOOT_PARTITION"
HOME_PARTITION="$HOME_PARTITION"

# Filesystems
ROOT_FS="$ROOT_FS"

# Hardware
CPU_VENDOR="$CPU_VENDOR"
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
# PRIVILEGE ESCALATION UNIVERSAL FUNCTIONS
# =============================================================================

# Get the configured privilege escalation tool
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
# Usage: run_privileged "command with args"
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
# Usage: run_privileged_retry "command with args"
run_privileged_retry() {
    run_with_retry "run_privileged $*"
}

# Check if user has privilege escalation configured
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
            ;&
        "doas")
            if command -v doas &>/dev/null && [ -f /etc/doas.conf ]; then
                # Test doas access without actually running a command
                if doas -n true 2>/dev/null; then
                    return 0
                fi
            fi
            # Fallback to sudo test
            ;&
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
