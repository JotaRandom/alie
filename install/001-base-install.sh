#!/bin/bash
# ALIE Base System Installation Script
# This script should be run from the Arch Linux installation media
#
# [WARNING] WARNING: EXPERIMENTAL SCRIPT
# This script is provided AS-IS without warranties.
# Review the code before running and use at your own risk.
# Make sure you have backups of any important data.

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Determine script directory (works regardless of how script is called)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Validate and load shared functions
if [ ! -f "$LIB_DIR/shared-functions.sh" ]; then
    echo "ERROR: shared-functions.sh not found at $LIB_DIR/shared-functions.sh"
    echo "Cannot continue without shared functions library."
    exit 1
fi

# shellcheck source=../lib/shared-functions.sh
# shellcheck disable=SC1091
source "$LIB_DIR/shared-functions.sh"

# Global variables for cleanup
MOUNTED_PARTITIONS=()
SWAP_ACTIVE=""

# Cleanup function for Ctrl+C or errors
cleanup() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo ""
        print_error "Installation failed with exit code: $exit_code"
        print_error "Error occurred at line: ${BASH_LINENO[1]} in function: ${FUNCNAME[1]}"
        print_info "Cleaning up..."
        
        # Unmount partitions in reverse order
        for ((i=${#MOUNTED_PARTITIONS[@]}-1; i>=0; i--)); do
            local mount_point="${MOUNTED_PARTITIONS[i]}"
            if mountpoint -q "$mount_point" 2>/dev/null; then
                print_info "Unmounting $mount_point..."
                umount "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null || true
            fi
        done
        
        # Deactivate swap
        if [ -n "$SWAP_ACTIVE" ] && swapon --show | grep -q "$SWAP_ACTIVE" 2>/dev/null; then
            print_info "Deactivating swap..."
            swapoff "$SWAP_ACTIVE" 2>/dev/null || true
        fi
        
        print_info "Cleanup complete"
        print_warning "Check the error messages above for details"
    fi
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Verify running as root
require_root

# Welcome banner
show_alie_banner
show_warning_banner

print_info "This installer will guide you through:"
echo "  - Network connectivity verification"
echo "  - Disk partitioning and formatting"
echo "  - Base system installation"
echo "  - Bootloader configuration"
echo ""
read -r -p "Press Enter to continue or Ctrl+C to exit..."

# ===================================
# STEP 1: NETWORK CONNECTIVITY
# ===================================
print_step "STEP 1: Network Connectivity"

# Check current connectivity
print_info "Checking network connectivity..."
if check_internet; then
    print_success "Internet connection detected!"
    NETWORK_OK=true
else
    print_warning "No internet connection detected"
    NETWORK_OK=false
fi

if [ "$NETWORK_OK" = false ]; then
    echo ""
    echo "Network configuration options:"
    echo "  1) Ethernet (cable) - automatic DHCP"
    echo "  2) WiFi - configure wireless"
    echo "  3) Skip - I'll configure manually"
    echo "  4) Exit installer"
    read -r -p "Choose option [1-4]: " NET_CHOICE
    
    case "$NET_CHOICE" in
        1)
            print_info "Attempting to obtain IP via DHCP..."
            dhcpcd &> /dev/null || true
            
            # Wait for network with timeout instead of fixed sleep
            print_info "Waiting for network interface to come up..."
            if wait_for_operation "ip addr show | grep -q 'inet '" 10 1; then
                print_info "Network interface configured, testing connectivity..."
                if wait_for_internet 3; then
                    print_success "Ethernet connection established!"
                    NETWORK_OK=true
                else
                    print_error "Failed to establish connection. Check cable connection."
                fi
            else
                print_error "Network interface did not come up. Check cable connection."
            fi
            ;;
        2)
            print_info "Available wireless interfaces:"
            ip link show | grep -E "^[0-9]+: (wlan|wlp)" | cut -d: -f2 | sed 's/^ /  - /'
            echo ""
            read -r -p "Enter wireless interface name (e.g., wlan0): " WIFI_IFACE
            
            if [ -z "$WIFI_IFACE" ]; then
                print_error "No interface specified"
            else
                print_info "Scanning networks on $WIFI_IFACE..."
                ip link set "$WIFI_IFACE" up 2>/dev/null || true
                sleep 2
                
                print_info "Starting iwctl interactive mode..."
                echo ""
                echo "Quick guide:"
                echo "  1. Type: station $WIFI_IFACE scan"
                echo "  2. Type: station $WIFI_IFACE get-networks"
                echo "  3. Type: station $WIFI_IFACE connect \"NETWORK_NAME\""
                echo "  4. Enter password when prompted"
                echo "  5. Type: exit"
                echo ""
                read -r -p "Press Enter to launch iwctl..."
                iwctl
                
                # Wait for WiFi connection with timeout
                print_info "Waiting for WiFi connection..."
                if wait_for_operation "ip addr show | grep -q 'inet '" 15 2; then
                    if wait_for_internet 3; then
                        print_success "WiFi connection established!"
                        NETWORK_OK=true
                    else
                        print_warning "WiFi configured but internet not reachable"
                    fi
                else
                    print_warning "Could not verify connection. Continuing anyway..."
                fi
            fi
            ;;
        3)
            print_warning "Skipping network configuration"
            print_info "Remember: Internet is required for package installation!"
            ;;
        4)
            print_info "Exiting installer..."
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
fi

# Final connectivity check
echo ""
if [ "$NETWORK_OK" = true ]; then
    print_success "Network is ready"
else
    print_warning "Network may not be configured"
    read -r -p "Continue anyway? (y/N): " CONTINUE_NO_NET
    if [[ ! $CONTINUE_NO_NET =~ ^[Yy]$ ]]; then
        print_info "Exiting. Configure network and run installer again."
        exit 1
    fi
fi

# ===================================
# STEP 2: SYSTEM INFORMATION
# ===================================
smart_clear
show_alie_banner
print_step "STEP 2: System Information"

# Detect boot mode (following wiki recommendation)
if [ -d /sys/firmware/efi/efivars ]; then
    BOOT_MODE="UEFI"
    
    # Check UEFI bitness as per wiki
    if [ -f /sys/firmware/efi/fw_platform_size ]; then
        UEFI_BITS=$(cat /sys/firmware/efi/fw_platform_size)
        print_success "Boot mode: UEFI ${UEFI_BITS}-bit"
        
        if [ "$UEFI_BITS" = "32" ]; then
            print_warning "32-bit UEFI detected - limited bootloader options"
        fi
    else
        print_success "Boot mode: UEFI"
    fi
    
    echo "  [INFO] Requires: EFI partition (512MB-1GB, FAT32)"
else
    BOOT_MODE="BIOS"
    print_success "Boot mode: BIOS (Legacy)"
    echo "  [INFO] Can use: MBR or GPT partition table"
fi

# Show system info
echo ""
print_info "System Information:"
echo "  - CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
echo "  - RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "  - Architecture: $(uname -m)"
sleep 2

# ===================================
# STEP 3: DISK PARTITIONING
# ===================================
smart_clear
show_alie_banner
print_step "STEP 3: Disk Partitioning & Formatting"

# Function to run critical commands with detailed error reporting
run_critical_command() {
    local command="$1"
    local description="$2"
    
    print_info "Executing: $description"
    print_info "Command: $command"
    
    # Run the command and capture both stdout and stderr
    if eval "$command" 2>&1; then
        print_success "$description completed successfully"
        return 0
    else
        local exit_code=$?
        print_error "$description failed with exit code: $exit_code"
        print_error "Command that failed: $command"
        print_error "This usually indicates a problem with disk access or parted"
        return $exit_code
    fi
}

# Function to validate parted availability and basic functionality
validate_parted() {
    print_info "Validating parted installation and functionality..."
    
    # Check if parted is installed
    if ! command -v parted &>/dev/null; then
        print_error "parted is not installed"
        print_info "Install parted with: pacman -S parted"
        exit 1
    fi
    
    # Check parted version
    local parted_version
    parted_version=$(parted --version 2>/dev/null | head -n1)
    print_info "Parted version: $parted_version"
    
    # Test basic parted functionality with help command (safe, doesn't require device)
    if ! parted --help >/dev/null 2>&1; then
        print_error "parted basic functionality test failed"
        print_info "There may be an issue with parted installation"
        exit 1
    fi
    
    print_success "Parted validation passed"
}

configure_home_partitioning() {
    CREATE_HOME=y
    # Calculate available space after EFI/swap
    EFI_SIZE=1  # 1GB for EFI
    RESERVED_SPACE=$((EFI_SIZE + SWAP_SIZE + 5))  # +5GB buffer
    AVAILABLE_FOR_ROOT=$((DISK_SIZE_GB - RESERVED_SPACE))
    
    echo ""
    print_info "Root partition sizing for separate /home:"
    echo "  - Disk size: ${DISK_SIZE_GB}GB"
    echo "  - Reserved for EFI/swap: ${RESERVED_SPACE}GB"
    echo "  - Available for root: ${AVAILABLE_FOR_ROOT}GB"
    
    # Calculate suggested root size based on disk size (128GB for 512GB disk ratio)
    SUGGESTED_ROOT=$((DISK_SIZE_GB * 128 / 512))
    if [ "$SUGGESTED_ROOT" -lt 64 ]; then
        SUGGESTED_ROOT=64
    fi
    if [ "$SUGGESTED_ROOT" -gt "$AVAILABLE_FOR_ROOT" ]; then
        SUGGESTED_ROOT="$AVAILABLE_FOR_ROOT"
    fi
    
    echo "  - Recommended root size: ${SUGGESTED_ROOT}GB (proportional to ${DISK_SIZE_GB}GB disk)"
    echo "  - Minimum: 64GB for reliable system operation"
    echo ""
    
    read -r -p "Size for / (root) in GB (recommended: ${SUGGESTED_ROOT}GB): " ROOT_SIZE
    
    # Handle invalid inputs with retry limit
    retry_count=0
    while [ "$retry_count" -lt 3 ]; do
        if [ -z "$ROOT_SIZE" ]; then
            ROOT_SIZE="$SUGGESTED_ROOT"
            print_info "Using recommended size: ${ROOT_SIZE}GB"
            break
        elif ! [[ "$ROOT_SIZE" =~ ^[0-9]+$ ]] || [ "$ROOT_SIZE" -eq 0 ]; then
            if [ "$ROOT_SIZE" -eq 0 ]; then
                print_warning "Size cannot be 0. Did you change your mind?"
            else
                print_error "Invalid size: $ROOT_SIZE. Must be a positive integer."
            fi
            retry_count=$((retry_count + 1))
            if [ "$retry_count" -lt 3 ]; then
                read -r -p "Size for / (root) in GB (recommended: ${SUGGESTED_ROOT}GB): " ROOT_SIZE
            else
                print_error "Too many invalid attempts. Installation cancelled."
                exit 1
            fi
        else
            break
        fi
    done
    
    # Validate root size
    if ! [[ "$ROOT_SIZE" =~ ^[0-9]+$ ]] || [ "$ROOT_SIZE" -lt 1 ]; then
        print_error "Invalid root size: $ROOT_SIZE"
        print_info "Root size must be a positive integer (GB)"
        exit 1
    fi
    
    # Check minimum size
    if [ "$ROOT_SIZE" -lt 64 ]; then
        print_warning "Root partition size ${ROOT_SIZE}GB is below the recommended minimum of 64GB"
        print_info "This may cause issues during system installation and updates"
        read -r -p "Do you still want to proceed with this small root partition? (y/N): " CONFIRM_SMALL_ROOT_MIN
        if [[ ! $CONFIRM_SMALL_ROOT_MIN =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled due to small root partition"
            exit 1
        fi
    fi
    
    # Check available space
    if [ "$ROOT_SIZE" -gt "$AVAILABLE_FOR_ROOT" ]; then
        print_error "Root size ${ROOT_SIZE}GB exceeds available space ${AVAILABLE_FOR_ROOT}GB"
        exit 1
    fi
    
    # Warn about small root
    if [ "$ROOT_SIZE" -lt "$SUGGESTED_ROOT" ]; then
        print_warning "Root size ${ROOT_SIZE}GB is below recommended ${SUGGESTED_ROOT}GB for ${DISK_SIZE_GB}GB disk"
        print_info "You may run out of space during package installation or system updates"
        read -r -p "Continue anyway? (y/N): " CONFIRM_SMALL_ROOT
        if [[ ! $CONFIRM_SMALL_ROOT =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check remaining space for /home
    HOME_SIZE=$((DISK_SIZE_GB - RESERVED_SPACE - ROOT_SIZE))
    if (( $(echo "$HOME_SIZE < 8.5" | bc -l) )); then
        print_warning "Home partition size ${HOME_SIZE}GB is smaller than a dual-layer DVD (8.5GB)"
        print_info "This may be insufficient for user data, applications, and backups"
        read -r -p "Do you REALLY want such a small /home partition? (y/N): " CONFIRM_TINY_HOME
        if [[ ! $CONFIRM_TINY_HOME =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    if [ "$HOME_SIZE" -lt 10 ]; then
        print_warning "Only ${HOME_SIZE}GB left for /home after root partition"
        print_info "Consider smaller root partition or single partition layout"
        read -r -p "Continue anyway? (y/N): " CONFIRM_SMALL_HOME
        if [[ ! $CONFIRM_SMALL_HOME =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check for unused disk space
    USED_SPACE=$((EFI_SIZE + SWAP_SIZE + ROOT_SIZE + HOME_SIZE))
    REMAINING_SPACE=$((DISK_SIZE_GB - USED_SPACE))
    if [ "$REMAINING_SPACE" -gt 0 ]; then
        print_info "After partitioning, ${REMAINING_SPACE}GB will remain unallocated on the disk"
        print_info "This space can be used later for additional partitions or left as free space"
        read -r -p "Continue with unallocated space remaining? (y/N): " CONFIRM_UNUSED_SPACE
        if [[ ! $CONFIRM_UNUSED_SPACE =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

print_info "Available disks:"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
echo ""
echo "Partitioning options:"
echo "  1) Automatic partitioning (DESTRUCTIVE - erases entire disk)"
echo "  2) Manual partitioning (I'll use cfdisk/fdisk/parted)"
echo "  3) Use existing partitions (already partitioned)"
echo "  4) Cancel and exit"
read -r -p "Choose option [1-4]: " PART_CHOICE

case "$PART_CHOICE" in
    1)
        # Automatic partitioning - ENHANCED SAFETY VERSION
        print_warning "[WARNING] AUTOMATIC PARTITIONING - THIS WILL ERASE THE ENTIRE DISK!"
        print_warning "This operation is IRREVERSIBLE and will destroy ALL data on the selected disk!"
        echo ""
        
        # Validate parted before proceeding
        validate_parted
        
        # Show available disks with more details
        echo "Available disks:"
        lsblk -d -o NAME,SIZE,TYPE,MODEL,ROTA | grep disk
        echo ""
        echo "[WARNING] Make sure you select the CORRECT disk!"
        echo "   - Check SIZE and MODEL to identify your target disk"
        echo "   - ROTA=1 means HDD (rotational), ROTA=0 means SSD"
        echo ""
        read -r -p "Enter disk to use (e.g., sda or /dev/sda, nvme0n1 or /dev/nvme0n1, vda or /dev/vda): " DISK_NAME
        
        # Enhanced disk name sanitization and validation
        DISK_NAME="${DISK_NAME#/dev/}"  # Remove /dev/ prefix if present
        DISK_NAME="$(echo "$DISK_NAME" | tr -d '[:space:]')"  # Remove whitespace
        
        print_info "Selected disk: $DISK_NAME"
        
        if [ -z "$DISK_NAME" ]; then
            print_error "No disk specified"
            exit 1
        fi
        
        # Validate disk name format (more restrictive)
        if ! [[ "$DISK_NAME" =~ ^(sd[a-z]|nvme[0-9]+n[0-9]+|vd[a-z]|hd[a-z]|mmcblk[0-9]+)$ ]]; then
            print_error "Invalid disk name format: $DISK_NAME"
            print_info "Accepted formats: sda, /dev/sda, nvme0n1, /dev/nvme0n1, vda, hda, mmcblk0, etc."
            print_info "You can include /dev/ prefix or not - both formats work"
            print_info "Available disks:"
            lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
            exit 1
        fi
        
        DISK_PATH="/dev/$DISK_NAME"
        print_info "Full disk path: $DISK_PATH"
        
        # CRITICAL: Validate disk exists and is not system disk
        if [ ! -b "$DISK_PATH" ]; then
            print_error "$DISK_PATH is not a valid block device"
            print_info "Available disks:"
            lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
            exit 1
        fi
        
        # Check if disk is readable
        if ! dd if="$DISK_PATH" of=/dev/null bs=512 count=1 2>/dev/null; then
            print_error "Cannot read from disk $DISK_PATH"
            print_info "The disk may be faulty or not properly connected"
            exit 1
        fi
        
        print_success "Disk $DISK_PATH exists and is accessible"
        
        # Check if disk is currently mounted or in use
        if mount | grep -q "^$DISK_PATH" || swapon --show | grep -q "^$DISK_PATH"; then
            print_error "Disk $DISK_PATH is currently in use (mounted or swap active)"
            print_info "Please unmount all partitions on this disk first"
            mount | grep "^$DISK_PATH"
            swapon --show | grep "^$DISK_PATH"
            exit 1
        fi
        
        # Check if this is the system disk (where we're running from)
        # More robust detection for various scenarios
        ROOT_DISK=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//' | sed 's/p*$//')
        
        # Also check /boot if it's a separate mount
        BOOT_DISK=""
        if mountpoint -q /boot && [ "$(findmnt -n -o SOURCE /boot)" != "$(findmnt -n -o SOURCE /)" ]; then
            BOOT_DISK=$(findmnt -n -o SOURCE /boot | sed 's/[0-9]*$//' | sed 's/p*$//')
        fi
        
        # Check if we're running from a live USB (common in Arch Linux install)
        LIVE_DISK=""
        if [ -d /run/archiso ] || grep -q "archiso" /proc/cmdline 2>/dev/null; then
            # Try to detect the live USB disk
            for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9] /dev/vd[a-z] /dev/hd[a-z] /dev/mmcblk[0-9]; do
                if [ -b "$disk" ] && blkid "$disk" | grep -q "archiso"; then
                    LIVE_DISK="$disk"
                    break
                fi
            done
        fi
        
        if [ "$DISK_PATH" = "$ROOT_DISK" ]; then
            print_error "Cannot partition the disk where the current system is running!"
            print_info "This would destroy the running system. Choose a different disk."
            print_info "System is running from: $ROOT_DISK"
            exit 1
        fi
        
        if [ -n "$BOOT_DISK" ] && [ "$DISK_PATH" = "$BOOT_DISK" ]; then
            print_error "Cannot partition the disk containing /boot!"
            print_info "Boot partition is on: $BOOT_DISK"
            exit 1
        fi
        
        if [ -n "$LIVE_DISK" ] && [ "$DISK_PATH" = "$LIVE_DISK" ]; then
            print_error "Cannot partition the live USB disk!"
            print_info "Arch Linux live system is running from: $LIVE_DISK"
            exit 1
        fi
        
        # Get disk size in GB for validation
        print_info "Getting disk size information..."
        DISK_SIZE_GB=$(lsblk -b -d -o SIZE "$DISK_PATH" | tail -1 | awk '{print int($1/1024/1024/1024)}')
        print_info "Disk size: ${DISK_SIZE_GB}GB"
        
        if [ "$DISK_SIZE_GB" -lt 20 ]; then
            print_error "Disk too small: ${DISK_SIZE_GB}GB"
            print_info "Minimum recommended size is 20GB for a basic Arch Linux installation"
            exit 1
        fi
        print_success "Disk size validation passed"
        
        # Show current layout and data warning
        echo ""
        print_info "Current disk layout:"
        lsblk "$DISK_PATH"
        echo ""
        
        # Check for existing partitions and warn about data
        EXISTING_PARTITIONS=$(lsblk -n -o NAME "$DISK_PATH" | grep -c "^${DISK_NAME}[0-9]")
        if [ "$EXISTING_PARTITIONS" -gt 0 ]; then
            print_warning "[WARNING] This disk has $EXISTING_PARTITIONS existing partition(s)!"
            print_warning "All data on these partitions will be PERMANENTLY LOST!"
            echo ""
            lsblk "$DISK_PATH" | grep "^${DISK_NAME}[0-9]"
            echo ""
        fi
        
        print_warning "[DANGER] FINAL WARNING: This will DESTROY ALL DATA on $DISK_PATH!"
        print_info "Disk: $DISK_PATH (${DISK_SIZE_GB}GB)"
        read -r -p "Type 'DESTROY-ALL-DATA' to confirm: " CONFIRM_WIPE
        
        if [ "$CONFIRM_WIPE" != "DESTROY-ALL-DATA" ]; then
            print_error "Partitioning cancelled - confirmation failed"
            exit 1
        fi
        
        # Ask for swap size FIRST (needed for space calculations)
        RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
        SUGGESTED_SWAP=$((RAM_GB + 2))
        
        # For systems with >64GB RAM, cap swap at 5GB (as requested)
        if [ "$RAM_GB" -gt 64 ]; then
            SUGGESTED_SWAP=5
        fi
        
        echo ""
        print_info "Swap partition sizing:"
        echo "  - RAM detected: ${RAM_GB}GB"
        echo "  - Suggested swap: ${SUGGESTED_SWAP}GB"
        echo "  - For hibernation: Add RAM size to swap"
        echo "  - Minimum: 128MB, Maximum: 5.125GB (for modern systems)"
        echo ""
        smart_clear
        read -r -p "Swap size in GB (suggested: ${SUGGESTED_SWAP}GB): " SWAP_SIZE
        SWAP_SIZE=${SWAP_SIZE:-$SUGGESTED_SWAP}
        
        # Enhanced swap validation
        if ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]] || [ "$SWAP_SIZE" -lt 1 ]; then
            print_error "Invalid swap size: $SWAP_SIZE"
            print_info "Swap size must be a positive integer (GB)"
            exit 1
        fi
        
        if [ "$SWAP_SIZE" -lt 1 ]; then
            print_warning "Swap size ${SWAP_SIZE}GB is below recommended minimum of 128MB"
            read -r -p "Continue anyway? (y/N): " CONFIRM_SMALL_SWAP
            if [[ ! $CONFIRM_SMALL_SWAP =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        
        if (( $(echo "$SWAP_SIZE > 5.125" | bc -l) )); then
            print_warning "Swap size of ${SWAP_SIZE}GB exceeds recommended maximum of 5.125GB"
            print_info "Modern systems rarely need more than 5.125GB swap"
            read -r -p "Continue anyway? (y/N): " CONFIRM_LARGE_SWAP
            if [[ ! $CONFIRM_LARGE_SWAP =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        
        # Ask for filesystem FIRST (before partitioning decisions)
        echo ""
        print_info "Filesystem selection for root partition:"
        echo ""
        echo "  ${CYAN}1)${NC} ext4 (recommended for most users)"
        echo "     - Mature, stable, widely supported"
        echo "     - Good performance, journaling, proven reliability"
        echo "     - Easy to resize, repair, and maintain"
        echo "     - Default choice for Linux distributions"
        echo ""
        echo "  ${CYAN}2)${NC} btrfs (advanced users, modern features)"
        echo "     - Snapshots, compression, subvolumes, RAID"
        echo "     - Built-in checksums, self-healing (RAID1/10)"
        echo "     - Dynamic resizing, efficient storage"
        echo "     - Higher learning curve, potential stability issues"
        echo ""
        echo "  ${CYAN}3)${NC} xfs (high-performance, large files)"
        echo "     - Excellent performance with large files"
        echo "     - Dynamic inode allocation, project quotas"
        echo "     - Good for media servers, databases"
        echo "     - Cannot shrink, limited repair tools"
        echo ""
        smart_clear
        read -r -p "Choose filesystem [1-3] (default: 1): " FS_CHOICE
        
        case "$FS_CHOICE" in
            2) ROOT_FS="btrfs" ;;
            3) ROOT_FS="xfs" ;;
            *) ROOT_FS="ext4" ;;
        esac
        
        print_success "Selected filesystem: $ROOT_FS"
        
        # Bootloader selection
        echo ""
        print_info "Bootloader selection:"
        echo ""
        echo "  ${CYAN}1)${NC} GRUB (recommended for most users)"
        echo "     - Mature, feature-rich bootloader"
        echo "     - Supports both BIOS and UEFI"
        echo "     - Advanced configuration options"
        echo "     - Default choice for Linux distributions"
        echo ""
        
        if [ "$BOOT_MODE" == "UEFI" ]; then
            echo "  ${CYAN}2)${NC} systemd-boot (modern, simple)"
            echo "     - Modern UEFI-only bootloader"
            echo "     - Integrated with systemd"
            echo "     - Simple configuration, fast boot"
            echo "     - Requires UEFI, no BIOS support"
            echo ""
            echo "  ${CYAN}3)${NC} Limine (lightweight, fast)"
            echo "     - Minimal, fast bootloader"
            echo "     - Supports both BIOS and UEFI"
            echo "     - Modern features, simple config"
            echo "     - Good for advanced users"
            echo ""
            smart_clear
            read -r -p "Choose bootloader [1-3] (default: 1): " BOOTLOADER_CHOICE
            
            case "$BOOTLOADER_CHOICE" in
                2) BOOTLOADER="systemd-boot" ;;
                3) BOOTLOADER="limine" ;;
                *) BOOTLOADER="grub" ;;
            esac
        else
            echo "  ${CYAN}2)${NC} Limine (lightweight, fast)"
            echo "     - Minimal, fast bootloader"
            echo "     - Supports both BIOS and UEFI"
            echo "     - Modern features, simple config"
            echo "     - Good for advanced users"
            echo ""
            smart_clear
            read -r -p "Choose bootloader [1-2] (default: 1): " BOOTLOADER_CHOICE
            
            case "$BOOTLOADER_CHOICE" in
                2) BOOTLOADER="limine" ;;
                *) BOOTLOADER="grub" ;;
            esac
        fi
        
        print_success "Selected bootloader: $BOOTLOADER"
        
        # Check for small disks (<64GB) and force single partition layout
        if [ "$DISK_SIZE_GB" -lt 64 ]; then
            print_warning "Disk size ${DISK_SIZE_GB}GB is smaller than recommended minimum of 64GB"
            print_info "For small disks, ALIE will use a single partition layout with limited swap"
            print_info "Swap will be capped at 2GB maximum (minimum 128MB)"
            read -r -p "Continue with single partition layout? (y/N): " CONFIRM_SMALL_DISK
            if [[ ! $CONFIRM_SMALL_DISK =~ ^[Yy]$ ]]; then
                print_info "Installation cancelled"
                exit 1
            fi
            
            # Force single partition scheme
            PARTITION_SCHEME="single"
            CREATE_HOME=false
            ROOT_SIZE=""
            print_info "Using single partition layout (/, limited swap)"
            
            # Adjust swap size to maximum 2GB
            if [ "$SWAP_SIZE" -gt 2 ]; then
                print_info "Reducing swap from ${SWAP_SIZE}GB to 2GB due to small disk"
                SWAP_SIZE=2
            fi
        else
            # Now ask for partition scheme based on filesystem choice
            echo ""
            print_info "Partition scheme selection:"
            echo ""
            echo "Available options:"
            echo "  ${CYAN}1)${NC} Single partition (/) - Simple, everything in root"
            echo "     - Pros: Easy to manage, no space allocation worries"
            echo "     - Cons: User data mixed with system, harder to reinstall"
            echo "     - Recommended for: Beginners, small disks (<50GB)"
            echo ""
            echo "  ${CYAN}2)${NC} Separate /home - User data isolated"
            echo "     - Pros: User data survives OS reinstalls, better organization"
            echo "     - Cons: Fixed sizes, more complex partitioning"
            echo "     - Recommended for: Most users, large disks (>100GB)"
            echo ""
            
            if [ "$ROOT_FS" = "btrfs" ]; then
                echo "  ${CYAN}3)${NC} Btrfs subvolumes - Advanced Btrfs features"
                echo "     - Pros: Flexible subvolumes, snapshots, compression"
                echo "     - Cons: Complex, requires Btrfs knowledge"
                echo "     - Recommended for: Advanced users, power users"
                echo ""
            fi
            
            if [ "$ROOT_FS" = "btrfs" ]; then
                read -r -p "Choose partition scheme [1-3] (default: 2): " SCHEME_CHOICE
            else
                read -r -p "Choose partition scheme [1-2] (default: 2): " SCHEME_CHOICE
            fi
            
            case "$SCHEME_CHOICE" in
                1) PARTITION_SCHEME="single" ;;
                3) if [ "$ROOT_FS" = "btrfs" ]; then
                       PARTITION_SCHEME="btrfs-subvolumes"
                   else
                       PARTITION_SCHEME="home"
                   fi ;;
                *) PARTITION_SCHEME="home" ;;
            esac
            
            print_success "Selected partition scheme: $PARTITION_SCHEME"
        fi
        
        # Configure partitioning based on scheme
        case "$PARTITION_SCHEME" in
            "single")
                CREATE_HOME=false
                ROOT_SIZE=""
                print_info "Using single partition layout (/, swap, EFI)"
                ;;
            "home")
                configure_home_partitioning
                ;;
            "btrfs-subvolumes")
                CREATE_HOME=false
                ROOT_SIZE=""
                print_info "Using Btrfs subvolumes (/, /home as subvolumes, swap, EFI)"
                print_info "Note: /home will be a Btrfs subvolume, not a separate partition"
                ;;
        esac
        
        # Final safety check before partitioning
        echo ""
        print_info "[PLAN] Partitioning Plan:"
        echo "  Disk: $DISK_PATH (${DISK_SIZE_GB}GB)"
        echo "  Boot mode: $BOOT_MODE"
        if [ "$BOOT_MODE" == "UEFI" ]; then
            echo "  EFI partition: 512MB (FAT32, ESP)"
        fi
        echo "  Swap partition: ${SWAP_SIZE}GB (Linux swap)"
        if [ "$PARTITION_SCHEME" = "btrfs-subvolumes" ]; then
            echo "  Root partition: remaining space ($ROOT_FS with @, @home, @var, @tmp, @.snapshots subvolumes)"
            echo "  Layout: / on @ subvolume, /home on @home subvolume, /var on @var, /tmp on @tmp, snapshots on @.snapshots"
            echo "  Filesystem options: $MOUNT_OPTS"
            echo "  Btrfs features: compression (zstd:3), checksums, copy-on-write, subvolumes"
        elif [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
            echo "  Root partition: ${ROOT_SIZE}GB ($ROOT_FS)"
            echo "  Home partition: ${HOME_SIZE}GB ($ROOT_FS)"
            echo "  Filesystem options: $MOUNT_OPTS"
        else
            echo "  Root partition: remaining space ($ROOT_FS)"
            echo "  Filesystem options: $MOUNT_OPTS"
        fi
        echo "  Partition table: ${PARTITION_TABLE:-GPT}"
        echo "  Boot configuration: $BOOT_MODE ${PARTITION_TABLE:-GPT}"
        echo ""
        print_warning "[WARNING] This will ERASE ALL DATA on $DISK_PATH!"
        read -r -p "Final confirmation - proceed with partitioning? (yes/no): " FINAL_CONFIRM
        
        if [[ ! "$FINAL_CONFIRM" =~ ^(yes|y)$ ]]; then
            print_error "Partitioning cancelled by user"
            exit 1
        fi
        
        # Re-validate disk exists before proceeding (double-check)
        if [ ! -b "$DISK_PATH" ]; then
            print_error "Disk $DISK_PATH disappeared! It may have been disconnected."
            exit 1
        fi
        
        # Perform partitioning with enhanced safety checks
        print_info "Creating partition table and partitions..."
        
        # Validate total space requirements before partitioning
        EFI_SIZE=1  # 1GB for EFI
        if [ "$PARTITION_SCHEME" = "btrfs-subvolumes" ]; then
            TOTAL_RESERVED=$((EFI_SIZE + SWAP_SIZE + 64))  # Minimum 64GB for root with subvolumes
        elif [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
            TOTAL_RESERVED=$((EFI_SIZE + SWAP_SIZE + ROOT_SIZE + 10))  # +10GB minimum for /home
        else
            TOTAL_RESERVED=$((EFI_SIZE + SWAP_SIZE + 64))  # Minimum 64GB for single partition
        fi
        
        print_info "Space requirements check:"
        print_info "  - Total required: ${TOTAL_RESERVED}GB"
        print_info "  - Disk available: ${DISK_SIZE_GB}GB"
        
        if [ "$TOTAL_RESERVED" -gt "$DISK_SIZE_GB" ]; then
            print_error "Insufficient disk space!"
            print_info "Required: ${TOTAL_RESERVED}GB, Available: ${DISK_SIZE_GB}GB"
            exit 1
        fi
        print_success "Space requirements validation passed"
        
        # Unmount if mounted
        umount -R /mnt 2>/dev/null || true
        swapoff -a 2>/dev/null || true
        
        # Wipe disk with verification
        print_info "Wiping existing partition signatures..."
        wipefs -af "$DISK_PATH" &>/dev/null || true
        sgdisk -Z "$DISK_PATH" &>/dev/null || true
        
        # Verify disk is still available after wipe
        if [ ! -b "$DISK_PATH" ]; then
            print_error "Disk $DISK_PATH became unavailable after wipe!"
            exit 1
        fi
        print_success "Disk wipe completed successfully"
        
        if [ "$BOOT_MODE" == "UEFI" ]; then
            # UEFI partitioning (GPT)
            print_info "Creating GPT partition table for UEFI..."
            run_critical_command "parted -s \"$DISK_PATH\" mklabel gpt" "Create GPT partition table" || exit 1
            
            # EFI partition (512MB)
            run_critical_command "parted -s \"$DISK_PATH\" mkpart primary fat32 1MiB 513MiB" "Create EFI partition" || exit 1
            run_critical_command "parted -s \"$DISK_PATH\" set 1 esp on" "Set EFI partition ESP flag" || exit 1
            
            # Swap partition
            SWAP_START=513
            SWAP_END=$((SWAP_START + SWAP_SIZE * 1024))
            run_critical_command "parted -s \"$DISK_PATH\" mkpart primary linux-swap ${SWAP_START}MiB ${SWAP_END}MiB" "Create swap partition" || exit 1
            
            if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
                # Root partition
                ROOT_START=$SWAP_END
                ROOT_END=$((ROOT_START + ROOT_SIZE * 1024))
                run_critical_command "parted -s \"$DISK_PATH\" mkpart primary $ROOT_FS ${ROOT_START}MiB ${ROOT_END}MiB" "Create root partition" || exit 1
                
                # Home partition (rest of disk)
                run_critical_command "parted -s \"$DISK_PATH\" mkpart primary $ROOT_FS ${ROOT_END}MiB 100%" "Create home partition" || exit 1
            else
                # Root partition (rest of disk)
                run_critical_command "parted -s \"$DISK_PATH\" mkpart primary $ROOT_FS ${SWAP_END}MiB 100%" "Create root partition" || exit 1
            fi
            
        else
            # BIOS partitioning - ask for table type
            smart_clear
            echo ""
            echo "Partition table type:"
            echo "  1) MBR (msdos) - Traditional, max 2TB"
            echo "  2) GPT - Modern, better for large disks"
            read -r -p "Choose [1-2] (default: 2): " PT_CHOICE
            
            if [ "$PT_CHOICE" == "1" ]; then
                PARTITION_TABLE="MBR"
                print_info "Creating MBR partition table..."
                run_critical_command "parted -s \"$DISK_PATH\" mklabel msdos" "Create MBR partition table" || exit 1
                
                # Swap
                run_critical_command "parted -s \"$DISK_PATH\" mkpart primary linux-swap 1MiB $((SWAP_SIZE * 1024))MiB" "Create swap partition" || exit 1
                
                if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
                    # Root
                    ROOT_START=$((SWAP_SIZE * 1024))
                    ROOT_END=$((ROOT_START + ROOT_SIZE * 1024))
                    run_critical_command "parted -s \"$DISK_PATH\" mkpart primary $ROOT_FS ${ROOT_START}MiB ${ROOT_END}MiB" "Create root partition" || exit 1
                    
                    # Home
                    run_critical_command "parted -s \"$DISK_PATH\" mkpart primary $ROOT_FS ${ROOT_END}MiB 100%" "Create home partition" || exit 1
                else
                    # Root (rest)
                    run_critical_command "parted -s \"$DISK_PATH\" mkpart primary $ROOT_FS $((SWAP_SIZE * 1024))MiB 100%" "Create root partition" || exit 1
                fi
                
            else
                PARTITION_TABLE="GPT"
                print_info "Creating GPT partition table for BIOS..."
                run_critical_command "parted -s \"$DISK_PATH\" mklabel gpt" "Create GPT partition table" || exit 1
                
                # BIOS boot partition (1MB)
                run_critical_command "parted -s \"$DISK_PATH\" mkpart primary 1MiB 2MiB" "Create BIOS boot partition" || exit 1
                run_critical_command "parted -s \"$DISK_PATH\" set 1 bios_grub on" "Set BIOS boot flag" || exit 1
                
                # Swap
                SWAP_START=2
                SWAP_END=$((SWAP_START + SWAP_SIZE * 1024))
                run_critical_command "parted -s \"$DISK_PATH\" mkpart primary linux-swap ${SWAP_START}MiB ${SWAP_END}MiB" "Create swap partition" || exit 1
                
                if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
                    # Root
                    ROOT_START=$SWAP_END
                    ROOT_END=$((ROOT_START + ROOT_SIZE * 1024))
                    run_critical_command "parted -s \"$DISK_PATH\" mkpart primary $ROOT_FS ${ROOT_START}MiB ${ROOT_END}MiB" "Create root partition" || exit 1
                    
                    # Home
                    run_critical_command "parted -s \"$DISK_PATH\" mkpart primary $ROOT_FS ${ROOT_END}MiB 100%" "Create home partition" || exit 1
                else
                    # Root (rest)
                    run_critical_command "parted -s \"$DISK_PATH\" mkpart primary $ROOT_FS ${SWAP_END}MiB 100%" "Create root partition" || exit 1
                fi
            fi
        fi
        
        # Wait for kernel to update partition table
        print_info "Updating partition table..."
        run_critical_command "partprobe \"$DISK_PATH\"" "Update kernel partition table" || {
            print_warning "partprobe failed, trying alternative methods..."
            partx -u "$DISK_PATH" 2>/dev/null || true
            udevadm trigger 2>/dev/null || true
            sleep 2
        }
        
        # Detect partition naming (sda1 vs nvme0n1p1)
        if [[ $DISK_NAME == nvme* ]] || [[ $DISK_NAME == mmcblk* ]]; then
            PART_PREFIX="${DISK_PATH}p"
        else
            PART_PREFIX="${DISK_PATH}"
        fi
        
        # Verify partitions were created
        print_info "Verifying partition creation..."
        PARTITION_COUNT=$(lsblk -n -o NAME "$DISK_PATH" | grep -c "^${DISK_NAME}[0-9]")
        if [ "$PARTITION_COUNT" -eq 0 ]; then
            print_error "No partitions were created on $DISK_PATH"
            print_info "Current disk layout:"
            lsblk "$DISK_PATH"
            exit 1
        fi
        print_success "Created $PARTITION_COUNT partition(s) successfully"
        
        # Wait for partitions to appear in /dev
        print_info "Waiting for partitions to be recognized..."
        EXPECTED_PART="${PART_PREFIX}1"
        if wait_for_operation "[ -b '$EXPECTED_PART' ]" 10 1; then
            print_success "Partitions created and recognized!"
        else
            print_warning "Partition recognition timeout, but continuing..."
        fi
        
        echo ""
        lsblk "$DISK_PATH"
        
        # Format partitions
        print_info "Formatting partitions..."
        
        # Detect partition naming (sda1 vs nvme0n1p1)
        if [[ $DISK_NAME == nvme* ]] || [[ $DISK_NAME == mmcblk* ]]; then
            PART_PREFIX="${DISK_PATH}p"
        else
            PART_PREFIX="${DISK_PATH}"
        fi
        
        # Define partition variables based on boot mode
        if [ "$BOOT_MODE" == "UEFI" ]; then
            EFI_PARTITION="${PART_PREFIX}1"
            SWAP_PARTITION="${PART_PREFIX}2"
            ROOT_PARTITION="${PART_PREFIX}3"
            if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
                HOME_PARTITION="${PART_PREFIX}4"
            fi
        else
            if [ "$PARTITION_TABLE" == "GPT" ]; then
                BIOS_BOOT_PARTITION="${PART_PREFIX}1"
                SWAP_PARTITION="${PART_PREFIX}2"
                ROOT_PARTITION="${PART_PREFIX}3"
                if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
                    HOME_PARTITION="${PART_PREFIX}4"
                fi
            else
                # MBR
                SWAP_PARTITION="${PART_PREFIX}1"
                ROOT_PARTITION="${PART_PREFIX}2"
                if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
                    HOME_PARTITION="${PART_PREFIX}3"
                fi
            fi
        fi
        
        # Ensure partitions are unmounted before formatting
        print_info "Ensuring partitions are not mounted..."
        
        # Only unmount the partitions we created, not all partitions on the disk
        PARTITIONS_TO_CHECK=("$SWAP_PARTITION" "$ROOT_PARTITION")
        if [ "$BOOT_MODE" == "UEFI" ]; then
            PARTITIONS_TO_CHECK+=("$EFI_PARTITION")
        elif [ "$BOOT_MODE" == "BIOS" ] && [ "$PARTITION_TABLE" == "GPT" ]; then
            PARTITIONS_TO_CHECK+=("$BIOS_BOOT_PARTITION")
        fi
        if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
            PARTITIONS_TO_CHECK+=("$HOME_PARTITION")
        fi
        
        for part in "${PARTITIONS_TO_CHECK[@]}"; do
            if [ -b "$part" ] && (mountpoint -q "$part" 2>/dev/null || mount | grep -q "^$part"); then
                print_warning "Partition $part is mounted, unmounting..."
                umount "$part" 2>/dev/null || umount -l "$part" 2>/dev/null || {
                    print_error "Failed to unmount $part"
                    exit 1
                }
            fi
        done
        
        # Disable any active swap on these partitions
        for part in "${PARTITIONS_TO_CHECK[@]}"; do
            if swapon --show | grep -q "^$part"; then
                print_info "Deactivating swap on $part..."
                swapoff "$part" 2>/dev/null || {
                    print_warning "Failed to deactivate swap on $part"
                }
            fi
        done
        
        print_info "Setting up swap..."
        run_critical_command "mkswap '$SWAP_PARTITION'" "Create swap" || exit 1
        
        print_info "Formatting root partition as $ROOT_FS..."
        case "$ROOT_FS" in
            ext4)
                # Ext4 with optimal options:
                # -F: force (even if mounted)
                # -L: filesystem label
                # -O ^metadata_csum_seed: disable for better compatibility
                # -E lazy_itable_init=0,lazy_journal_init=0: initialize fully for reliability
                mkfs.ext4 -F -L "ArchRoot" -m 1 -E lazy_itable_init=0,lazy_journal_init=0 "$ROOT_PARTITION"
                ;;
            btrfs)
                # Btrfs with optimal options:
                # -f: force
                # -L: filesystem label
                # -m: metadata profile (dup for single device)
                # -d: data profile (single for single device)
                mkfs.btrfs -f -L "ArchRoot" -m dup -d single "$ROOT_PARTITION"
                
                # Create subvolumes if using Btrfs subvolumes scheme
                if [ "$PARTITION_SCHEME" = "btrfs-subvolumes" ]; then
                    print_info "Creating Btrfs subvolumes..."
                    # Mount temporarily to create subvolumes
                    mkdir -p /tmp/btrfs-mount
                    mount "$ROOT_PARTITION" /tmp/btrfs-mount
                    
                    # Create root subvolume
                    btrfs subvolume create /tmp/btrfs-mount/@
                    # Create home subvolume  
                    btrfs subvolume create /tmp/btrfs-mount/@home
                    # Create var subvolume
                    btrfs subvolume create /tmp/btrfs-mount/@var
                    # Create tmp subvolume
                    btrfs subvolume create /tmp/btrfs-mount/@tmp
                    # Create snapshots subvolume
                    btrfs subvolume create /tmp/btrfs-mount/@.snapshots
                    
                    # Unmount
                    umount /tmp/btrfs-mount
                    rmdir /tmp/btrfs-mount
                    print_success "Btrfs subvolumes created (@, @home, @var, @tmp, @.snapshots)"
                fi
                ;;
            xfs)
                # XFS with optimal options:
                # -f: force
                # -L: filesystem label
                # -b size=4096: 4K block size
                # -m crc=1: enable metadata checksums
                mkfs.xfs -f -L "ArchRoot" -b size=4096 -m crc=1,finobt=1 "$ROOT_PARTITION"
                ;;
        esac
        
        if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
            print_info "Formatting /home partition as $ROOT_FS..."
            case "$ROOT_FS" in
                ext4)
                    mkfs.ext4 -F -L "ArchHome" -m 1 -E lazy_itable_init=0,lazy_journal_init=0 "$HOME_PARTITION"
                    ;;
                btrfs)
                    mkfs.btrfs -f -L "ArchHome" -m dup -d single "$HOME_PARTITION"
                    ;;
                xfs)
                    mkfs.xfs -f -L "ArchHome" -b size=4096 -m crc=1,finobt=1 "$HOME_PARTITION"
                    ;;
            esac
        fi
        
        print_success "All partitions formatted!"
        
        # Set flag for later use
        AUTO_PARTITIONED=true
        ;;
        
    2)
        # Manual partitioning
        print_info "Launching manual partitioning tool..."
        echo ""
        lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
        echo ""
        read -r -p "Enter disk to partition (e.g., sda or /dev/sda, nvme0n1 or /dev/nvme0n1): " DISK_NAME
        
        if [ -z "$DISK_NAME" ]; then
            print_error "No disk specified"
            exit 1
        fi
        
        DISK_PATH="/dev/$DISK_NAME"
        
        if [ ! -b "$DISK_PATH" ]; then
            print_error "$DISK_PATH is not a valid block device"
            exit 1
        fi
        
        echo ""
        echo "Partitioning guidelines:"
        if [ "$BOOT_MODE" == "UEFI" ]; then
            echo "  - EFI partition: 512MB-1GB, type EFI System"
        else
            echo "  - For GPT: Create 1MB BIOS boot partition (type: BIOS boot)"
        fi
        echo "  - Swap partition: RAM size + 2GB recommended"
        echo "  - Root partition: 30-50GB minimum (type: Linux filesystem)"
        echo "  - Home partition: Remaining space (optional)"
        echo ""
        
        smart_clear
        echo "Available tools:"
        echo "  1) cfdisk (recommended, user-friendly)"
        echo "  2) fdisk (traditional)"
        echo "  3) parted (advanced)"
        read -r -p "Choose tool [1-3]: " TOOL_CHOICE
        
        case "$TOOL_CHOICE" in
            1) cfdisk "$DISK_PATH" ;;
            2) fdisk "$DISK_PATH" ;;
            3) parted "$DISK_PATH" ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
        
        # After partitioning, ask user to format
        echo ""
        print_info "Current partition layout:"
        lsblk "$DISK_PATH"
        echo ""
        
        smart_clear
        read -r -p "Do you want to format the partitions now? (Y/n): " FORMAT_NOW
        
        if [[ ! $FORMAT_NOW =~ ^[Nn]$ ]]; then
            # Ask for each partition and format
            if [ "$BOOT_MODE" == "UEFI" ]; then
                read -r -p "Enter EFI partition (e.g., /dev/sda1): " EFI_PARTITION
                if [ -n "$EFI_PARTITION" ] && [ -b "$EFI_PARTITION" ]; then
                    # Check if partition already has a filesystem (dual-boot warning)
                    EXISTING_FS=$(blkid -o value -s TYPE "$EFI_PARTITION" 2>/dev/null || echo "")
                    
                    if [ -n "$EXISTING_FS" ]; then
                        print_warning "Partition $EFI_PARTITION already has filesystem: $EXISTING_FS"
                        print_warning "This may contain bootloaders from other operating systems!"
                        read -r -p "Format anyway? This will destroy other OS bootloaders! (y/N): " CONFIRM_FORMAT_EFI
                        
                        if [[ ! $CONFIRM_FORMAT_EFI =~ ^[Yy]$ ]]; then
                            print_info "Skipping EFI partition format - will use existing"
                        else
                            print_info "Formatting EFI partition as FAT32..."
                            mkfs.fat -F32 -n "EFI" "$EFI_PARTITION"
                        fi
                    else
                        print_info "Formatting EFI partition as FAT32..."
                        mkfs.fat -F32 -n "EFI" "$EFI_PARTITION"
                    fi
                fi
            else
                read -r -p "Using GPT? (y/N): " USING_GPT
                if [[ $USING_GPT =~ ^[Yy]$ ]]; then
                    PARTITION_TABLE="GPT"
                    read -r -p "Enter BIOS boot partition (e.g., /dev/sda1): " BIOS_BOOT_PARTITION
                else
                    PARTITION_TABLE="MBR"
                fi
            fi
            
            read -r -p "Enter swap partition: " SWAP_PARTITION
            if [ -n "$SWAP_PARTITION" ] && [ -b "$SWAP_PARTITION" ]; then
                print_info "Setting up swap..."
                mkswap "$SWAP_PARTITION"
            fi
            
            read -r -p "Enter root partition: " ROOT_PARTITION
            if [ -n "$ROOT_PARTITION" ] && [ -b "$ROOT_PARTITION" ]; then
                smart_clear
                echo "Choose filesystem:"
                echo "  1) ext4"
                echo "  2) btrfs"
                echo "  3) xfs"
                read -r -p "Choose [1-3]: " FS_CHOICE
                
                case "$FS_CHOICE" in
                    2) ROOT_FS="btrfs" ;;
                    3) ROOT_FS="xfs" ;;
                    *) ROOT_FS="ext4" ;;
                esac
                
                print_info "Formatting root as $ROOT_FS..."
                case "$ROOT_FS" in
                    ext4) mkfs.ext4 -F -L "ArchRoot" -m 1 -E lazy_itable_init=0,lazy_journal_init=0 "$ROOT_PARTITION" ;;
                    btrfs) mkfs.btrfs -f -L "ArchRoot" -m dup -d single "$ROOT_PARTITION" ;;
                    xfs) mkfs.xfs -f -L "ArchRoot" -b size=4096 -m crc=1,finobt=1 "$ROOT_PARTITION" ;;
                esac
            fi
            
            read -r -p "Do you have a separate /home partition? (y/N): " HAS_HOME
            if [[ $HAS_HOME =~ ^[Yy]$ ]]; then
                read -r -p "Enter /home partition: " HOME_PARTITION
                if [ -n "$HOME_PARTITION" ] && [ -b "$HOME_PARTITION" ]; then
                    print_info "Formatting /home as $ROOT_FS..."
                    case "$ROOT_FS" in
                        ext4) mkfs.ext4 -F -L "ArchHome" -m 1 -E lazy_itable_init=0,lazy_journal_init=0 "$HOME_PARTITION" ;;
                        btrfs) mkfs.btrfs -f -L "ArchHome" -m dup -d single "$HOME_PARTITION" ;;
                        xfs) mkfs.xfs -f -L "ArchHome" -b size=4096 -m crc=1,finobt=1 "$HOME_PARTITION" ;;
                    esac
                fi
            fi
            
            # Mark as auto-partitioned to skip re-asking for partitions
            AUTO_PARTITIONED=true
        else
            AUTO_PARTITIONED=false
        fi
        ;;
        
    3)
        # Use existing partitions
        print_info "Using existing partitions (no formatting)"
        echo ""
        lsblk
        echo ""
        
        AUTO_PARTITIONED=false
        ;;
        
    4)
        print_info "Installation cancelled by user"
        exit 0
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

# ===================================
# STEP 4: PARTITION SELECTION & VALIDATION
# ===================================
smart_clear
show_alie_banner
print_step "STEP 4: Partition Selection"

# If not auto-partitioned, ask for partitions
if [ "$AUTO_PARTITIONED" != true ]; then
    echo ""
    lsblk
    echo ""
    
    read -r -p "Enter the root partition (e.g., /dev/sda3): " ROOT_PARTITION
    read -r -p "Enter the swap partition (e.g., /dev/sda2): " SWAP_PARTITION
    
    if [ "$BOOT_MODE" == "UEFI" ]; then
        read -r -p "Enter the EFI partition (e.g., /dev/sda1): " EFI_PARTITION
    else
        read -r -p "Are you using GPT partition table? (y/N): " USING_GPT
        if [[ $USING_GPT =~ ^[Yy]$ ]]; then
            PARTITION_TABLE="GPT"
            read -r -p "Enter the BIOS boot partition (e.g., /dev/sda1): " BIOS_BOOT_PARTITION
        else
            PARTITION_TABLE="MBR"
        fi
    fi
    
    read -r -p "Do you have a separate /home partition? (y/N): " HAS_HOME
    if [[ $HAS_HOME =~ ^[Yy]$ ]]; then
        read -r -p "Enter the /home partition (e.g., /dev/sda4): " HOME_PARTITION
    fi
fi

# Validate partitions
print_info "Validating partitions..."

if [ -z "$ROOT_PARTITION" ] || [ -z "$SWAP_PARTITION" ]; then
    print_error "Root and swap partitions are required"
    exit 1
fi

if [ "$BOOT_MODE" == "UEFI" ] && [ -z "$EFI_PARTITION" ]; then
    print_error "EFI partition is required for UEFI boot"
    exit 1
fi

if [ "$BOOT_MODE" == "BIOS" ] && [ "$PARTITION_TABLE" == "GPT" ] && [ -z "$BIOS_BOOT_PARTITION" ]; then
    print_error "BIOS boot partition is required for GPT on BIOS systems"
    exit 1
fi

if [[ $HAS_HOME =~ ^[Yy]$ ]] && [ -z "$HOME_PARTITION" ]; then
    print_error "/home partition path is required"
    exit 1
fi

if [ ! -b "$ROOT_PARTITION" ]; then
    print_error "$ROOT_PARTITION is not a valid block device"
    exit 1
fi

if [ ! -b "$SWAP_PARTITION" ]; then
    print_error "$SWAP_PARTITION is not a valid block device"
    exit 1
fi

if [ "$BOOT_MODE" == "UEFI" ] && [ ! -b "$EFI_PARTITION" ]; then
    print_error "$EFI_PARTITION is not a valid block device"
    exit 1
fi

if [ "$BOOT_MODE" == "BIOS" ] && [ "$PARTITION_TABLE" == "GPT" ] && [ ! -b "$BIOS_BOOT_PARTITION" ]; then
    print_error "$BIOS_BOOT_PARTITION is not a valid block device"
    exit 1
fi

if [[ $HAS_HOME =~ ^[Yy]$ ]] && [ ! -b "$HOME_PARTITION" ]; then
    print_error "$HOME_PARTITION is not a valid block device"
    exit 1
fi

print_success "All partitions validated"

# ===================================
# STEP 5: INSTALLATION SUMMARY
# ===================================
smart_clear
show_alie_banner
print_step "STEP 5: Installation Summary"

echo ""
print_info "Installation Configuration:"
echo "  - Boot mode: $BOOT_MODE"
if [ "$BOOT_MODE" == "BIOS" ]; then
    echo "  - Partition table: ${PARTITION_TABLE:-Not specified}"
fi
echo "  - Root partition: $ROOT_PARTITION"
echo "  - Swap partition: $SWAP_PARTITION"
if [ "$BOOT_MODE" == "UEFI" ]; then
    echo "  - EFI partition: $EFI_PARTITION"
elif [ "$PARTITION_TABLE" == "GPT" ]; then
    echo "  - BIOS boot partition: $BIOS_BOOT_PARTITION"
fi
if [[ $HAS_HOME =~ ^[Yy]$ ]]; then
    echo "  - Home partition: $HOME_PARTITION"
fi
echo ""

print_warning "This will install Arch Linux with the above configuration"
read -r -p "Continue with installation? (y/N): " CONFIRM

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled"
    exit 1
fi

# ===================================
# STEP 6: SYSTEM CLOCK
# ===================================
smart_clear
show_alie_banner
print_step "STEP 6: System Preparation"

print_info "Synchronizing system clock..."
timedatectl set-ntp true
sleep 5
print_success "System clock synchronized"

# ===================================
# STEP 7: MOUNT PARTITIONS
# ===================================
smart_clear
show_alie_banner
print_step "STEP 7: Mounting Partitions"

print_info "Preparing mount points..."
if mountpoint -q /mnt/boot 2>/dev/null; then
    umount /mnt/boot
fi

if mountpoint -q /mnt/home 2>/dev/null; then
    umount /mnt/home
fi

if mountpoint -q /mnt 2>/dev/null; then
    umount /mnt
fi

# Detect filesystem type for root partition
ROOT_FS=$(blkid -o value -s TYPE "$ROOT_PARTITION" 2>/dev/null || echo "unknown")
print_info "Detected root filesystem: $ROOT_FS"

# Set mount options based on filesystem
case "$ROOT_FS" in
    ext4)
        # ext4: noatime (no access time updates), commit=60 (journal every 60s), errors=remount-ro (safety)
        MOUNT_OPTS="defaults,noatime,errors=remount-ro,commit=60"
        ;;
    btrfs)
        # btrfs: noatime, zstd compression (level 3 default), space_cache=v2 (performance), discard=async (SSD trim)
        MOUNT_OPTS="defaults,noatime,compress=zstd:3,space_cache=v2,discard=async"
        ;;
    xfs)
        # xfs: noatime, inode64 (64-bit inodes), logbsize=256k (larger log buffer)
        MOUNT_OPTS="defaults,noatime,inode64,logbsize=256k"
        ;;
    *)
        MOUNT_OPTS="defaults,relatime"
        print_warning "Unknown filesystem, using default mount options"
        ;;
esac

# Mount root with optimized options
if [ "$ROOT_FS" = "btrfs" ] && [ "$PARTITION_SCHEME" = "btrfs-subvolumes" ]; then
    print_info "Mounting Btrfs root subvolume (@) with options: $MOUNT_OPTS"
    mount -o "$MOUNT_OPTS,subvol=@" "$ROOT_PARTITION" /mnt
    MOUNTED_PARTITIONS+=("/mnt")
    print_success "Root partition mounted"
    
    # Mount additional Btrfs subvolumes
    print_info "Mounting additional Btrfs subvolumes..."
    
    # Create directories
    mkdir -p /mnt/home /mnt/var /mnt/tmp /mnt/.snapshots
    
    # Mount @home
    mount -o "$MOUNT_OPTS,subvol=@home" "$ROOT_PARTITION" /mnt/home
    MOUNTED_PARTITIONS+=("/mnt/home")
    
    # Mount @var
    mount -o "$MOUNT_OPTS,subvol=@var" "$ROOT_PARTITION" /mnt/var
    MOUNTED_PARTITIONS+=("/mnt/var")
    
    # Mount @tmp
    mount -o "$MOUNT_OPTS,subvol=@tmp" "$ROOT_PARTITION" /mnt/tmp
    MOUNTED_PARTITIONS+=("/mnt/tmp")
    
    # Mount @.snapshots
    mount -o "$MOUNT_OPTS,subvol=@.snapshots" "$ROOT_PARTITION" /mnt/.snapshots
    MOUNTED_PARTITIONS+=("/mnt/.snapshots")
    
    print_success "All Btrfs subvolumes mounted"
else
    print_info "Mounting root partition with options: $MOUNT_OPTS"
    mount -o "$MOUNT_OPTS" "$ROOT_PARTITION" /mnt
    MOUNTED_PARTITIONS+=("/mnt")
    print_success "Root partition mounted"
fi

# Activate swap (deactivate first if already active)
if swapon --show | grep -q "$SWAP_PARTITION" 2>/dev/null; then
    swapoff "$SWAP_PARTITION"
fi
print_info "Activating swap partition..."
swapon "$SWAP_PARTITION"
SWAP_ACTIVE="$SWAP_PARTITION"
print_success "Swap activated"

# Mount EFI if UEFI
if [ "$BOOT_MODE" == "UEFI" ]; then
    mkdir -p /mnt/boot
    print_info "Mounting EFI partition..."
    # EFI: fmask=0077,dmask=0077 (secure permissions), codepage=437,iocharset=iso8859-1 (compatibility)
    mount -o "defaults,noatime,fmask=0077,dmask=0077,codepage=437,iocharset=iso8859-1" "$EFI_PARTITION" /mnt/boot
    MOUNTED_PARTITIONS+=("/mnt/boot")
    print_success "EFI partition mounted"
fi

# Mount home if separate (with same optimizations)
if [ "$PARTITION_SCHEME" = "home" ] || [ "$PARTITION_SCHEME" = "btrfs-subvolumes" ] || [[ ${HAS_HOME:-n} =~ ^[Yy]$ ]]; then
    mkdir -p /mnt/home
    
    if [ "$PARTITION_SCHEME" = "btrfs-subvolumes" ]; then
        # Mount Btrfs @home subvolume
        print_info "Mounting Btrfs /home subvolume (@home) with options: $HOME_OPTS"
        mount -o "$HOME_OPTS,subvol=@home" "$ROOT_PARTITION" /mnt/home
    else
        # Mount separate /home partition
        HOME_FS=$(blkid -o value -s TYPE "$HOME_PARTITION" 2>/dev/null || echo "$ROOT_FS")
        
        case "$HOME_FS" in
            ext4)
                HOME_OPTS="defaults,noatime,errors=remount-ro,commit=60"
                ;;
            btrfs)
                HOME_OPTS="defaults,noatime,compress=zstd:3,space_cache=v2,discard=async"
                ;;
            xfs)
                HOME_OPTS="defaults,noatime,inode64,logbsize=256k"
                ;;
            *)
                HOME_OPTS="defaults,relatime"
                ;;
        esac
        
        print_info "Mounting /home with options: $HOME_OPTS"
        mount -o "$HOME_OPTS" "$HOME_PARTITION" /mnt/home
    fi
    
    MOUNTED_PARTITIONS+=("/mnt/home")
    print_success "/home partition mounted"
fi

echo ""
print_success "All partitions mounted successfully!"
print_info "Current mount layout:"
lsblk | grep -E "(NAME|/mnt|SWAP)"

# ===================================

# ===================================
# SAVE CONFIGURATION FOR NEXT STEP
# ===================================
print_step "Saving Configuration"

# Detect and populate all system information
detect_system_info

# Save comprehensive configuration for use by subsequent scripts
save_system_config "/tmp/.alie-install-config"

# Also save to the new system for later use
if mountpoint -q /mnt 2>/dev/null; then
    mkdir -p /mnt/root
    save_system_config "/mnt/root/.alie-install-config"
    print_info "Configuration also saved to /mnt/root/.alie-install-config"
fi

# ===================================
# PARTITIONING COMPLETED
# ===================================
echo ""
print_step " Disk Partitioning Completed Successfully!"

# Mark progress
save_progress "01-partitions-ready"

echo ""
print_success "Partitioning and mounting finished!"
echo ""
print_info "Next steps:"
echo "  ${CYAN}1.${NC} (Optional) Select shells and editors:"
echo "     ${YELLOW}bash $(dirname "$0")/002-shell-editor-select.sh${NC}"
echo ""
echo "  ${CYAN}2.${NC} Install base system:"
echo "     ${YELLOW}bash $(dirname "$0")/003-system-install.sh${NC}"
echo ""
echo "  ${CYAN}3.${NC} Or continue with the main installer:"
echo "     ${YELLOW}bash $(dirname "$SCRIPT_DIR")/alie.sh${NC}"
echo ""
print_warning "Don't reboot yet! Continue with system installation."
echo ""
