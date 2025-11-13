#!/bin/bash
# ALIE Base System Installation Script
# This script should be run from the Arch Linux installation media
#
# ?????? WARNING: EXPERIMENTAL SCRIPT
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

source "$LIB_DIR/shared-functions.sh"

# Global variables for cleanup
MOUNTED_PARTITIONS=()
SWAP_ACTIVE=""

# Cleanup function for Ctrl+C or errors
cleanup() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo ""
        print_warning "Installation interrupted or failed!"
        print_info "Cleaning up..."
        
        # Unmount partitions in reverse order
        for ((i=${#MOUNTED_PARTITIONS[@]}-1; i>=0; i--)); do
            local mount_point="${MOUNTED_PARTITIONS[i]}"
            if mountpoint -q "$mount_point" 2>/dev/null; then
                print_info "Unmounting $mount_point..."
                umount "$mount_point" 2>/dev/null || true
            fi
        done
        
        # Deactivate swap
        if [ -n "$SWAP_ACTIVE" ] && swapon --show | grep -q "$SWAP_ACTIVE" 2>/dev/null; then
            print_info "Deactivating swap..."
            swapoff "$SWAP_ACTIVE" 2>/dev/null || true
        fi
        
        print_info "Cleanup complete"
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
echo "  ??? Network connectivity verification"
echo "  ??? Disk partitioning and formatting"
echo "  ??? Base system installation"
echo "  ??? Bootloader configuration"
echo ""
read -p "Press Enter to continue or Ctrl+C to exit..."

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
    read -p "Choose option [1-4]: " NET_CHOICE
    
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
            read -p "Enter wireless interface name (e.g., wlan0): " WIFI_IFACE
            
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
                read -p "Press Enter to launch iwctl..."
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
    read -p "Continue anyway? (y/N): " CONTINUE_NO_NET
    if [[ ! $CONTINUE_NO_NET =~ ^[Yy]$ ]]; then
        print_info "Exiting. Configure network and run installer again."
        exit 1
    fi
fi

# ===================================
# STEP 2: SYSTEM INFORMATION
# ===================================
print_step "STEP 2: System Information"

# ===================================
# STEP 2: SYSTEM INFORMATION
# ===================================
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
    
    echo "  ?????? Requires: EFI partition (512MB-1GB, FAT32)"
else
    BOOT_MODE="BIOS"
    print_success "Boot mode: BIOS (Legacy)"
    echo "  ?????? Can use: MBR or GPT partition table"
fi

# Show system info
echo ""
print_info "System Information:"
echo "  ??? CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
echo "  ??? RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "  ??? Architecture: $(uname -m)"

# ===================================
# STEP 3: DISK PARTITIONING
# ===================================
print_step "STEP 3: Disk Partitioning & Formatting"

print_info "Available disks:"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
echo ""

echo "Partitioning options:"
echo "  1) Automatic partitioning (DESTRUCTIVE - erases entire disk)"
echo "  2) Manual partitioning (I'll use cfdisk/fdisk/parted)"
echo "  3) Use existing partitions (already partitioned)"
read -p "Choose option [1-3]: " PART_CHOICE

case "$PART_CHOICE" in
    1)
        # Automatic partitioning
        print_warning "AUTOMATIC PARTITIONING - THIS WILL ERASE THE ENTIRE DISK!"
        echo ""
        lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
        echo ""
        read -p "Enter disk to use (e.g., sda, nvme0n1, vda): " DISK_NAME
        
        # Sanitize disk name - remove /dev/ prefix if present and validate
        DISK_NAME="${DISK_NAME#/dev/}"
        DISK_NAME="$(echo "$DISK_NAME" | tr -d '[:space:]')"  # Remove whitespace
        
        if [ -z "$DISK_NAME" ]; then
            print_error "No disk specified"
            exit 1
        fi
        
        # Validate disk name format (alphanumeric only, no special chars except digits)
        if ! [[ "$DISK_NAME" =~ ^[a-z]+[0-9]*n?[0-9]*$ ]]; then
            print_error "Invalid disk name format: $DISK_NAME"
            print_info "Expected format: sda, sdb, nvme0n1, vda, etc."
            exit 1
        fi
        
        DISK_PATH="/dev/$DISK_NAME"
        
        if [ ! -b "$DISK_PATH" ]; then
            print_error "$DISK_PATH is not a valid block device"
            print_info "Available disks:"
            lsblk -d -o NAME,SIZE,TYPE | grep disk
            exit 1
        fi
        
        # Show current layout
        echo ""
        print_info "Current disk layout:"
        lsblk "$DISK_PATH"
        echo ""
        
        print_warning "??????  ALL DATA ON $DISK_PATH WILL BE DESTROYED! ??????"
        read -p "Type 'YES' in uppercase to confirm: " CONFIRM_WIPE
        
        if [ "$CONFIRM_WIPE" != "YES" ]; then
            print_error "Partitioning cancelled"
            exit 1
        fi
        
        # Ask for swap size
        RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
        SUGGESTED_SWAP=$((RAM_GB + 2))
        echo ""
        read -p "Swap size in GB (suggested: ${SUGGESTED_SWAP}GB): " SWAP_SIZE
        SWAP_SIZE=${SWAP_SIZE:-$SUGGESTED_SWAP}
        
        # Validate swap size is a positive integer
        if ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]] || [ "$SWAP_SIZE" -lt 1 ]; then
            print_error "Invalid swap size: $SWAP_SIZE"
            print_info "Swap size must be a positive integer (GB)"
            exit 1
        fi
        
        if [ "$SWAP_SIZE" -gt 128 ]; then
            print_warning "Swap size of ${SWAP_SIZE}GB seems unusually large"
            read -p "Continue anyway? (y/N): " CONFIRM_LARGE_SWAP
            if ! [[ $CONFIRM_LARGE_SWAP =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        
        # Ask for separate home
        read -p "Create separate /home partition? (y/N): " CREATE_HOME
        
        if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
            read -p "Size for / (root) in GB (recommended: 30-50GB, minimum: 23GB): " ROOT_SIZE
            
            if [ -z "$ROOT_SIZE" ]; then
                print_error "Root size is required when creating separate /home"
                exit 1
            fi
            
            # Validate root size is a positive integer
            if ! [[ "$ROOT_SIZE" =~ ^[0-9]+$ ]] || [ "$ROOT_SIZE" -lt 1 ]; then
                print_error "Invalid root size: $ROOT_SIZE"
                print_info "Root size must be a positive integer (GB)"
                exit 1
            fi
            
            # Validate minimum size (following wiki recommendation)
            if [ "$ROOT_SIZE" -lt 23 ]; then
                print_error "Root partition too small: ${ROOT_SIZE}GB"
                print_info "Minimum recommended size is 23GB for ALIE"
                exit 1
            fi
            
            if [ "$ROOT_SIZE" -lt 30 ]; then
                print_warning "Root size is below recommended 30 GB minimum"
                read -p "Continue anyway? (y/N): " CONFIRM_SMALL_ROOT
                if [[ ! $CONFIRM_SMALL_ROOT =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
        fi
        
        # Choose filesystem
        echo ""
        echo "Choose filesystem for root partition:"
        echo "  1) ext4 (stable, widely supported)"
        echo "  2) btrfs (modern, snapshots, compression)"
        echo "  3) xfs (high performance, large files)"
        read -p "Choose [1-3] (default: 1): " FS_CHOICE
        
        case "$FS_CHOICE" in
            2) ROOT_FS="btrfs" ;;
            3) ROOT_FS="xfs" ;;
            *) ROOT_FS="ext4" ;;
        esac
        
        print_success "Selected filesystem: $ROOT_FS"
        
        # Re-validate disk exists before proceeding
        if [ ! -b "$DISK_PATH" ]; then
            print_error "Disk $DISK_PATH disappeared! It may have been disconnected."
            exit 1
        fi
        
        # Perform partitioning
        print_info "Creating partition table and partitions..."
        
        # Unmount if mounted
        umount -R /mnt 2>/dev/null || true
        swapoff -a 2>/dev/null || true
        
        # Wipe disk
        print_info "Wiping existing partition signatures..."
        wipefs -af "$DISK_PATH" &>/dev/null || true
        sgdisk -Z "$DISK_PATH" &>/dev/null || true
        
        if [ "$BOOT_MODE" == "UEFI" ]; then
            # UEFI partitioning (GPT)
            print_info "Creating GPT partition table for UEFI..."
            
            parted -s "$DISK_PATH" mklabel gpt
            
            # EFI partition (512MB)
            parted -s "$DISK_PATH" mkpart primary fat32 1MiB 513MiB
            parted -s "$DISK_PATH" set 1 esp on
            
            # Swap partition
            SWAP_START=513
            SWAP_END=$((SWAP_START + SWAP_SIZE * 1024))
            parted -s "$DISK_PATH" mkpart primary linux-swap ${SWAP_START}MiB ${SWAP_END}MiB
            
            if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
                # Root partition
                ROOT_START=$SWAP_END
                ROOT_END=$((ROOT_START + ROOT_SIZE * 1024))
                parted -s "$DISK_PATH" mkpart primary $ROOT_FS ${ROOT_START}MiB ${ROOT_END}MiB
                
                # Home partition (rest of disk)
                parted -s "$DISK_PATH" mkpart primary $ROOT_FS ${ROOT_END}MiB 100%
            else
                # Root partition (rest of disk)
                parted -s "$DISK_PATH" mkpart primary $ROOT_FS ${SWAP_END}MiB 100%
            fi
            
        else
            # BIOS partitioning - ask for table type
            echo ""
            echo "Partition table type:"
            echo "  1) MBR (msdos) - Traditional, max 2TB"
            echo "  2) GPT - Modern, better for large disks"
            read -p "Choose [1-2] (default: 2): " PT_CHOICE
            
            if [ "$PT_CHOICE" == "1" ]; then
                PARTITION_TABLE="MBR"
                print_info "Creating MBR partition table..."
                parted -s "$DISK_PATH" mklabel msdos
                
                # Swap
                parted -s "$DISK_PATH" mkpart primary linux-swap 1MiB $((SWAP_SIZE * 1024))MiB
                
                if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
                    # Root
                    ROOT_START=$((SWAP_SIZE * 1024))
                    ROOT_END=$((ROOT_START + ROOT_SIZE * 1024))
                    parted -s "$DISK_PATH" mkpart primary $ROOT_FS ${ROOT_START}MiB ${ROOT_END}MiB
                    
                    # Home
                    parted -s "$DISK_PATH" mkpart primary $ROOT_FS ${ROOT_END}MiB 100%
                else
                    # Root (rest)
                    parted -s "$DISK_PATH" mkpart primary $ROOT_FS $((SWAP_SIZE * 1024))MiB 100%
                fi
                
            else
                PARTITION_TABLE="GPT"
                print_info "Creating GPT partition table for BIOS..."
                parted -s "$DISK_PATH" mklabel gpt
                
                # BIOS boot partition (1MB)
                parted -s "$DISK_PATH" mkpart primary 1MiB 2MiB
                parted -s "$DISK_PATH" set 1 bios_grub on
                
                # Swap
                SWAP_START=2
                SWAP_END=$((SWAP_START + SWAP_SIZE * 1024))
                parted -s "$DISK_PATH" mkpart primary linux-swap ${SWAP_START}MiB ${SWAP_END}MiB
                
                if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
                    # Root
                    ROOT_START=$SWAP_END
                    ROOT_END=$((ROOT_START + ROOT_SIZE * 1024))
                    parted -s "$DISK_PATH" mkpart primary $ROOT_FS ${ROOT_START}MiB ${ROOT_END}MiB
                    
                    # Home
                    parted -s "$DISK_PATH" mkpart primary $ROOT_FS ${ROOT_END}MiB 100%
                else
                    # Root (rest)
                    parted -s "$DISK_PATH" mkpart primary $ROOT_FS ${SWAP_END}MiB 100%
                fi
            fi
        fi
        
        # Wait for kernel to update partition table
        print_info "Updating partition table..."
        partprobe "$DISK_PATH" 2>/dev/null || true
        
        # Detect partition naming (sda1 vs nvme0n1p1)
        if [[ $DISK_NAME == nvme* ]] || [[ $DISK_NAME == mmcblk* ]]; then
            PART_PREFIX="${DISK_PATH}p"
        else
            PART_PREFIX="${DISK_PATH}"
        fi
        
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
        
        # Ensure partitions are unmounted before formatting
        print_info "Ensuring partitions are not mounted..."
        for part in ${PART_PREFIX}*; do
            if mountpoint -q "$part" 2>/dev/null || mount | grep -q "$part"; then
                print_warning "Partition $part is mounted, unmounting..."
                umount "$part" 2>/dev/null || umount -l "$part" 2>/dev/null || true
            fi
        done
        
        # Disable any active swap on these partitions
        if swapon --show | grep -q "${DISK_PATH}"; then
            print_info "Deactivating swap on disk..."
            swapoff -a 2>/dev/null || true
        fi
        
        if [ "$BOOT_MODE" == "UEFI" ]; then
            EFI_PARTITION="${PART_PREFIX}1"
            SWAP_PARTITION="${PART_PREFIX}2"
            ROOT_PARTITION="${PART_PREFIX}3"
            
            print_info "Formatting EFI partition as FAT32..."
            print_warning "This will erase any existing bootloaders on this partition!"
            mkfs.fat -F32 "$EFI_PARTITION"
            
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
        
        print_info "Setting up swap..."
        mkswap "$SWAP_PARTITION"
        
        print_info "Formatting root partition as $ROOT_FS..."
        case "$ROOT_FS" in
            ext4)
                mkfs.ext4 -F "$ROOT_PARTITION"
                ;;
            btrfs)
                mkfs.btrfs -f "$ROOT_PARTITION"
                ;;
            xfs)
                mkfs.xfs -f "$ROOT_PARTITION"
                ;;
        esac
        
        if [[ $CREATE_HOME =~ ^[Yy]$ ]]; then
            print_info "Formatting /home partition as $ROOT_FS..."
            case "$ROOT_FS" in
                ext4)
                    mkfs.ext4 -F "$HOME_PARTITION"
                    ;;
                btrfs)
                    mkfs.btrfs -f "$HOME_PARTITION"
                    ;;
                xfs)
                    mkfs.xfs -f "$HOME_PARTITION"
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
        read -p "Enter disk to partition (e.g., sda, nvme0n1): " DISK_NAME
        
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
            echo "  ??? EFI partition: 512MB-1GB, type EFI System"
        else
            echo "  ??? For GPT: Create 1MB BIOS boot partition (type: BIOS boot)"
        fi
        echo "  ??? Swap partition: RAM size + 2GB recommended"
        echo "  ??? Root partition: 30-50GB minimum (type: Linux filesystem)"
        echo "  ??? Home partition: Remaining space (optional)"
        echo ""
        
        echo "Available tools:"
        echo "  1) cfdisk (recommended, user-friendly)"
        echo "  2) fdisk (traditional)"
        echo "  3) parted (advanced)"
        read -p "Choose tool [1-3]: " TOOL_CHOICE
        
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
        
        read -p "Do you want to format the partitions now? (Y/n): " FORMAT_NOW
        
        if [[ ! $FORMAT_NOW =~ ^[Nn]$ ]]; then
            # Ask for each partition and format
            if [ "$BOOT_MODE" == "UEFI" ]; then
                read -p "Enter EFI partition (e.g., /dev/sda1): " EFI_PARTITION
                if [ -n "$EFI_PARTITION" ] && [ -b "$EFI_PARTITION" ]; then
                    # Check if partition already has a filesystem (dual-boot warning)
                    EXISTING_FS=$(blkid -o value -s TYPE "$EFI_PARTITION" 2>/dev/null || echo "")
                    
                    if [ -n "$EXISTING_FS" ]; then
                        print_warning "Partition $EFI_PARTITION already has filesystem: $EXISTING_FS"
                        print_warning "This may contain bootloaders from other operating systems!"
                        read -p "Format anyway? This will destroy other OS bootloaders! (y/N): " CONFIRM_FORMAT_EFI
                        
                        if [[ ! $CONFIRM_FORMAT_EFI =~ ^[Yy]$ ]]; then
                            print_info "Skipping EFI partition format - will use existing"
                        else
                            print_info "Formatting EFI partition as FAT32..."
                            mkfs.fat -F32 "$EFI_PARTITION"
                        fi
                    else
                        print_info "Formatting EFI partition as FAT32..."
                        mkfs.fat -F32 "$EFI_PARTITION"
                    fi
                fi
            else
                read -p "Using GPT? (y/N): " USING_GPT
                if [[ $USING_GPT =~ ^[Yy]$ ]]; then
                    PARTITION_TABLE="GPT"
                    read -p "Enter BIOS boot partition (e.g., /dev/sda1): " BIOS_BOOT_PARTITION
                else
                    PARTITION_TABLE="MBR"
                fi
            fi
            
            read -p "Enter swap partition: " SWAP_PARTITION
            if [ -n "$SWAP_PARTITION" ] && [ -b "$SWAP_PARTITION" ]; then
                print_info "Setting up swap..."
                mkswap "$SWAP_PARTITION"
            fi
            
            read -p "Enter root partition: " ROOT_PARTITION
            if [ -n "$ROOT_PARTITION" ] && [ -b "$ROOT_PARTITION" ]; then
                echo "Choose filesystem:"
                echo "  1) ext4"
                echo "  2) btrfs"
                echo "  3) xfs"
                read -p "Choose [1-3]: " FS_CHOICE
                
                case "$FS_CHOICE" in
                    2) ROOT_FS="btrfs" ;;
                    3) ROOT_FS="xfs" ;;
                    *) ROOT_FS="ext4" ;;
                esac
                
                print_info "Formatting root as $ROOT_FS..."
                case "$ROOT_FS" in
                    ext4) mkfs.ext4 -F "$ROOT_PARTITION" ;;
                    btrfs) mkfs.btrfs -f "$ROOT_PARTITION" ;;
                    xfs) mkfs.xfs -f "$ROOT_PARTITION" ;;
                esac
            fi
            
            read -p "Do you have a separate /home partition? (y/N): " HAS_HOME
            if [[ $HAS_HOME =~ ^[Yy]$ ]]; then
                read -p "Enter /home partition: " HOME_PARTITION
                if [ -n "$HOME_PARTITION" ] && [ -b "$HOME_PARTITION" ]; then
                    print_info "Formatting /home as $ROOT_FS..."
                    case "$ROOT_FS" in
                        ext4) mkfs.ext4 -F "$HOME_PARTITION" ;;
                        btrfs) mkfs.btrfs -f "$HOME_PARTITION" ;;
                        xfs) mkfs.xfs -f "$HOME_PARTITION" ;;
                    esac
                fi
            fi
        fi
        
        AUTO_PARTITIONED=false
        ;;
        
    3)
        # Use existing partitions
        print_info "Using existing partitions (no formatting)"
        echo ""
        lsblk
        echo ""
        
        AUTO_PARTITIONED=false
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

# ===================================
# STEP 4: PARTITION SELECTION & VALIDATION
# ===================================
print_step "STEP 4: Partition Selection"

# If not auto-partitioned, ask for partitions
if [ "$AUTO_PARTITIONED" != true ]; then
    echo ""
    lsblk
    echo ""
    
    read -p "Enter the root partition (e.g., /dev/sda3): " ROOT_PARTITION
    read -p "Enter the swap partition (e.g., /dev/sda2): " SWAP_PARTITION
    
    if [ "$BOOT_MODE" == "UEFI" ]; then
        read -p "Enter the EFI partition (e.g., /dev/sda1): " EFI_PARTITION
    else
        read -p "Are you using GPT partition table? (y/N): " USING_GPT
        if [[ $USING_GPT =~ ^[Yy]$ ]]; then
            PARTITION_TABLE="GPT"
            read -p "Enter the BIOS boot partition (e.g., /dev/sda1): " BIOS_BOOT_PARTITION
        else
            PARTITION_TABLE="MBR"
        fi
    fi
    
    read -p "Do you have a separate /home partition? (y/N): " HAS_HOME
    if [[ $HAS_HOME =~ ^[Yy]$ ]]; then
        read -p "Enter the /home partition (e.g., /dev/sda4): " HOME_PARTITION
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
print_step "STEP 5: Installation Summary"

echo ""
print_info "Installation Configuration:"
echo "  ??? Boot mode: $BOOT_MODE"
if [ "$BOOT_MODE" == "BIOS" ]; then
    echo "  ??? Partition table: ${PARTITION_TABLE:-Not specified}"
fi
echo "  ??? Root partition: $ROOT_PARTITION"
echo "  ??? Swap partition: $SWAP_PARTITION"
if [ "$BOOT_MODE" == "UEFI" ]; then
    echo "  ??? EFI partition: $EFI_PARTITION"
elif [ "$PARTITION_TABLE" == "GPT" ]; then
    echo "  ??? BIOS boot partition: $BIOS_BOOT_PARTITION"
fi
if [[ $HAS_HOME =~ ^[Yy]$ ]]; then
    echo "  ??? Home partition: $HOME_PARTITION"
fi
echo ""

print_warning "This will install Arch Linux with the above configuration"
read -p "Continue with installation? (y/N): " CONFIRM

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled"
    exit 1
fi

# ===================================
# STEP 6: SYSTEM CLOCK
# ===================================
print_step "STEP 6: System Preparation"

print_info "Synchronizing system clock..."
timedatectl set-ntp true
sleep 2
print_success "System clock synchronized"

# ===================================
# STEP 7: MOUNT PARTITIONS
# ===================================
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
        MOUNT_OPTS="defaults,noatime,commit=60"
        ;;
    btrfs)
        MOUNT_OPTS="defaults,noatime,compress=zstd,space_cache=v2"
        ;;
    xfs)
        MOUNT_OPTS="defaults,noatime,inode64"
        ;;
    *)
        MOUNT_OPTS="defaults,relatime"
        print_warning "Unknown filesystem, using default mount options"
        ;;
esac

# Mount root with optimized options
print_info "Mounting root partition with options: $MOUNT_OPTS"
mount -o "$MOUNT_OPTS" "$ROOT_PARTITION" /mnt
MOUNTED_PARTITIONS+=("/mnt")
print_success "Root partition mounted"

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
    mount "$EFI_PARTITION" /mnt/boot
    MOUNTED_PARTITIONS+=("/mnt/boot")
    print_success "EFI partition mounted"
fi

# Mount home if separate (with same optimizations)
if [[ $HAS_HOME =~ ^[Yy]$ ]]; then
    mkdir -p /mnt/home
    HOME_FS=$(blkid -o value -s TYPE "$HOME_PARTITION" 2>/dev/null || echo "$ROOT_FS")
    
    case "$HOME_FS" in
        ext4)
            HOME_OPTS="defaults,noatime,commit=60"
            ;;
        btrfs)
            HOME_OPTS="defaults,noatime,compress=zstd,space_cache=v2"
            ;;
        xfs)
            HOME_OPTS="defaults,noatime,inode64"
            ;;
        *)
            HOME_OPTS="defaults,relatime"
            ;;
    esac
    
    print_info "Mounting /home with options: $HOME_OPTS"
    mount -o "$HOME_OPTS" "$HOME_PARTITION" /mnt/home
    MOUNTED_PARTITIONS+=("/mnt/home")
    print_success "/home partition mounted"
fi

echo ""
print_success "All partitions mounted successfully!"
print_info "Current mount layout:"
lsblk | grep -E "(NAME|/mnt|SWAP)"

# ===================================
# STEP 8: MIRROR OPTIMIZATION
# ===================================
print_step "STEP 8: Optimizing Package Mirrors"

print_info "Installing reflector..."
if ! pacman -S --needed --noconfirm reflector; then
    print_error "Failed to install reflector"
    print_warning "Continuing with default mirrorlist..."
else
    print_info "Fetching fastest mirrors (this may take a minute)..."
    echo "Using automatic country detection and selecting 20 fastest HTTPS mirrors..."
    
    # Use reflector with better defaults - no hardcoded country
    # The wiki recommends using geographically close mirrors
    if retry_command 2 "reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist"; then
        print_success "Mirror list optimized"
        print_info "Top 5 mirrors:"
        head -n 5 /etc/pacman.d/mirrorlist | grep "^Server" || true
    else
        print_warning "Reflector failed, using default mirrorlist"
    fi
fi

# ===================================
# STEP 9: BASE SYSTEM INSTALLATION
# ===================================
print_step "STEP 9: Installing Base System"

print_info "Installing essential packages..."
echo "This will take several minutes depending on your connection..."
echo ""

# Detect CPU vendor for microcode
CPU_VENDOR=""
MICROCODE_INSTALLED="no"
if grep -q "GenuineIntel" /proc/cpuinfo; then
    CPU_VENDOR="intel"
    MICROCODE_PKG="intel-ucode"
    MICROCODE_INSTALLED="yes"
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    CPU_VENDOR="amd"
    MICROCODE_PKG="amd-ucode"
    MICROCODE_INSTALLED="yes"
fi

# Build package list
PACKAGES="base linux linux-firmware networkmanager grub vim sudo nano"

if [ -n "$MICROCODE_PKG" ]; then
    print_info "Detected $CPU_VENDOR CPU, will install $MICROCODE_PKG"
    PACKAGES="$PACKAGES $MICROCODE_PKG"
fi

if [ "$BOOT_MODE" == "UEFI" ]; then
    PACKAGES="$PACKAGES efibootmgr"
fi

# Check available space on /mnt (minimum 2GB recommended for base install)
AVAILABLE_SPACE_MB=$(df -BM /mnt | awk 'NR==2 {print $4}' | sed 's/M//')
print_info "Available space on /mnt: ${AVAILABLE_SPACE_MB} MB"

if [ "$AVAILABLE_SPACE_MB" -lt 2048 ]; then
    print_error "Insufficient space on /mnt! Need at least 2GB, have ${AVAILABLE_SPACE_MB}MB"
    print_error "Installation cannot proceed"
    exit 1
elif [ "$AVAILABLE_SPACE_MB" -lt 5120 ]; then
    print_warning "Low disk space: ${AVAILABLE_SPACE_MB}MB. Installation may fail if packages are large."
    read -p "Continue anyway? (y/N): " CONTINUE_LOW_SPACE
    if [[ ! $CONTINUE_LOW_SPACE =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Use -K flag to initialize empty pacman keyring (recommended by wiki)
print_info "Running: pacstrap -K /mnt $PACKAGES"
echo ""

# Disable set -e temporarily for pacstrap to handle errors gracefully
set +e
pacstrap -K /mnt $PACKAGES
PACSTRAP_EXIT_CODE=$?
set -e

if [ $PACSTRAP_EXIT_CODE -ne 0 ]; then
    print_error "pacstrap failed with exit code $PACSTRAP_EXIT_CODE"
    print_info "This could be due to:"
    echo "  ??? Network connectivity issues"
    echo "  ??? Mirror problems"
    echo "  ??? Insufficient disk space"
    echo "  ??? Package signing errors"
    echo ""
    read -p "Retry pacstrap? (Y/n): " RETRY_PACSTRAP
    
    if [[ ! $RETRY_PACSTRAP =~ ^[Nn]$ ]]; then
        print_info "Retrying pacstrap..."
        set +e
        pacstrap -K /mnt $PACKAGES
        PACSTRAP_EXIT_CODE=$?
        set -e
        
        if [ $PACSTRAP_EXIT_CODE -ne 0 ]; then
            print_error "pacstrap failed again. Cannot continue."
            exit 1
        fi
    else
        print_error "Installation cancelled by user"
        exit 1
    fi
fi

print_success "Base system installed!"

# ===================================
# STEP 10: GENERATE FSTAB
# ===================================
print_step "STEP 10: Generating fstab"

print_info "Generating filesystem table with UUIDs..."
genfstab -U /mnt >> /mnt/etc/fstab
print_success "fstab generated"

print_info "fstab contents:"
cat /mnt/etc/fstab

# ===================================
# STEP 11: SAVE CONFIGURATION
# ===================================
print_step "STEP 11: Saving Installation Info"

# Save configuration using shared function
save_install_info "/mnt/root/.alie-install-info" \
    BOOT_MODE \
    PARTITION_TABLE \
    ROOT_PARTITION \
    SWAP_PARTITION \
    EFI_PARTITION \
    BIOS_BOOT_PARTITION \
    HOME_PARTITION \
    ROOT_FS \
    CPU_VENDOR \
    MICROCODE_INSTALLED

# ===================================
# INSTALLATION COMPLETE
# ===================================
echo ""
print_step "??? Base Installation Completed Successfully!"

# Mark progress
save_progress "01-base-installed"

echo ""
print_success "Installation finished!"
echo ""
print_info "Next steps:"
echo "  ${CYAN}1.${NC} Copy the ALIE scripts to the new system:"
echo "     ${YELLOW}cp -r $(dirname "$0") /mnt/root/alie-scripts${NC}"
echo ""
echo "  ${CYAN}2.${NC} Enter the new system:"
echo "     ${YELLOW}arch-chroot /mnt${NC}"
echo ""
echo "  ${CYAN}3.${NC} Run the installer again (auto-detects chroot):"
echo "     ${YELLOW}bash /root/alie-scripts/alie.sh${NC}"
echo ""
print_warning "Don't reboot yet! Continue with system configuration."
echo ""
