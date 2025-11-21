#!/bin/bash
# ALIE System Configuration Script
# This script should be run inside arch-chroot
#
# [WARNING] WARNING: EXPERIMENTAL SCRIPT
# This script is provided AS-IS without warranties.
# Review the code before running and use at your own risk.

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

# Validate and load config functions
if [ ! -f "$LIB_DIR/config-functions.sh" ]; then
    echo "ERROR: config-functions.sh not found at $LIB_DIR/config-functions.sh"
    echo "Cannot continue without config functions library."
    exit 1
fi

# shellcheck source=../lib/config-functions.sh
# shellcheck disable=SC1091
source "$LIB_DIR/config-functions.sh"

# Add signal handling for graceful interruption
setup_cleanup_trap

# Welcome banner
show_alie_banner
show_warning_banner

print_info "This script will configure:"
echo "  - Timezone and system clock"
echo "  - Locale and keyboard layout"
echo "  - Hostname and network"
echo "  - Root password"
echo "  - Package manager (pacman)"
echo "  - Bootloader (GRUB, systemd-boot, or Limine)"
echo ""
read -r -p "Press Enter to continue or Ctrl+C to exit..."

# Validate environment
print_step "101: STEP 1: Environment Validation"

# Verify running as root
if ! require_root; then
    exit 1
fi

# Verify chroot environment
verify_chroot

# Load configuration from previous script
load_install_info

# Initialize variables that might not be set in install info
CPU_VENDOR="${CPU_VENDOR:-}"
BOOT_MODE="${BOOT_MODE:-}"
ROOT_PARTITION="${ROOT_PARTITION:-}"
ROOT_FS="${ROOT_FS:-}"
SWAP_PARTITION="${SWAP_PARTITION:-}"
EFI_PARTITION="${EFI_PARTITION:-}"
BOOT_PARTITION="${BOOT_PARTITION:-}"
MICROCODE_INSTALLED="${MICROCODE_INSTALLED:-no}"
BOOTLOADER="${BOOTLOADER:-grub}"
TIMEZONE="${TIMEZONE:-America/New_York}"
LOCALE="${LOCALE:-en_US.UTF-8}"
KEYMAP="${KEYMAP:-us}"
HOSTNAME="${HOSTNAME:-arch-linux}"
SELECTED_KERNELS="${SELECTED_KERNELS:-}"

read -r -p "Press Enter to continue..."
smart_clear
# ===================================
# STEP 2: COLLECT CONFIGURATION
# ===================================
print_step "101: STEP 2: System Configuration"

# Hostname
echo ""
print_info "Hostname Configuration"
echo "The hostname identifies your computer on a network"
echo "Example: arch-desktop, my-laptop, workstation"
read -r -p "Enter hostname: " HOSTNAME

# Validate inputs
if [ -z "$HOSTNAME" ]; then
    print_error_detailed "Hostname cannot be empty" \
        "A hostname is required to identify your computer on the network" \
        "Enter a valid hostname (e.g., 'arch-desktop', 'my-laptop')" \
        "Use only letters, numbers, and hyphens. Must start/end with alphanumeric character"
    exit 1
fi

if ! [[ "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
    print_error_detailed "Invalid hostname format: '$HOSTNAME'" \
        "Hostname must follow RFC standards" \
        "Use only letters, numbers, and hyphens. Cannot start or end with hyphen" \
        "Examples: 'arch-linux', 'workstation-01', 'server'"
    exit 1
fi

print_success "Hostname: $HOSTNAME"

# Timezone
echo ""
print_info "Timezone Configuration"
echo "Common timezones:"
echo "  - America/New_York     (US Eastern)"
echo "  - America/Chicago      (US Central)"
echo "  - America/Denver       (US Mountain)"
echo "  - America/Los_Angeles  (US Pacific)"
echo "  - America/Mexico_City  (Mexico)"
echo "  - Europe/London        (UK)"
echo "  - Europe/Paris         (Central Europe)"
echo "  - Asia/Tokyo           (Japan)"
echo ""
print_info "For a complete list, check: /usr/share/zoneinfo/"
read -r -p "Enter timezone (e.g., America/New_York): " TIMEZONE

if [ -z "$TIMEZONE" ]; then
    print_error_detailed "Timezone cannot be empty" \
        "System clock requires a valid timezone for proper timekeeping" \
        "Choose from available timezones or use 'America/New_York' format" \
        "Run: timedatectl list-timezones | grep -i america"
    exit 1
fi

# Sanitize timezone input - prevent path traversal
TIMEZONE="${TIMEZONE//..\/}"  # Remove ../ sequences
TIMEZONE="${TIMEZONE#/}"      # Remove leading /
TIMEZONE="${TIMEZONE%/}"      # Remove trailing /

# Validate timezone format (Region/City or Region/Subregion/City)
if ! [[ "$TIMEZONE" =~ ^[A-Z][a-zA-Z_]+/[A-Z][a-zA-Z_]+(/[A-Z][a-zA-Z_]+)?$ ]]; then
    print_error_detailed "Invalid timezone format: $TIMEZONE" \
        "Timezone must be in Region/City format (e.g., America/New_York)" \
        "First letter of each component must be capitalized" \
        "Run: timedatectl list-timezones | head -20"
    exit 1
fi

    if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
    print_error_detailed "Timezone '$TIMEZONE' not found on system" \
        "The specified timezone is not available in the zoneinfo database" \
        "Check spelling and format. Use: timedatectl list-timezones" \
        "Common examples: America/New_York, Europe/London, Asia/Tokyo"
    exit 1
fi

print_success "Timezone: $TIMEZONE"

# Locale
echo ""
print_info "Locale Configuration"
echo "Common locales:"
echo "  - en_US.UTF-8  (English - United States)"
echo "  - en_GB.UTF-8  (English - United Kingdom)"
echo "  - es_ES.UTF-8  (Spanish - Spain)"
echo "  - es_MX.UTF-8  (Spanish - Mexico)"
echo "  - de_DE.UTF-8  (German - Germany)"
echo "  - fr_FR.UTF-8  (French - France)"
echo ""
read -r -p "Enter locale (default: en_US.UTF-8): " LOCALE
LOCALE=${LOCALE:-en_US.UTF-8}

if [ -z "$LOCALE" ]; then
    print_error_detailed "Locale cannot be empty" \
        "System language and regional settings require a valid locale" \
        "Choose from available locales (e.g., en_US.UTF-8, es_ES.UTF-8)" \
        "Run: localectl list-locales | grep -i utf"
    exit 1
fi

# Sanitize locale input - must match pattern xx_YY.UTF-8 or xx_YY.utf8
if ! [[ "$LOCALE" =~ ^[a-z]{2,3}_[A-Z]{2}\.([Uu][Tt][Ff]-?8)$ ]]; then
    print_error_detailed "Invalid locale format: $LOCALE" \
        "Locale must be in xx_YY.UTF-8 format (e.g., en_US.UTF-8, es_ES.UTF-8)" \
        "Language code (xx) and country code (YY) required, followed by .UTF-8" \
        "Run: localectl list-locales | head -10"
    exit 1
fi

# Verify locale exists in /usr/share/i18n/locales/
LOCALE_BASE=$(echo "$LOCALE" | cut -d. -f1)
if [ ! -f "/usr/share/i18n/locales/$LOCALE_BASE" ]; then
    print_warning "Locale $LOCALE_BASE not found in system"
    print_info "Will try to generate it anyway..."
fi

print_success "Locale: $LOCALE"

# Keyboard layout
echo ""
print_info "Keyboard Layout Configuration"

# Check if step 01 was completed (base installation done)
if is_step_completed "01-partitions-ready"; then
    print_info "Base installation completed, loading saved keyboard configuration..."
    
    # Load system configuration which includes KEYMAP
    if load_system_config; then
        if [ -n "$KEYMAP" ]; then
            print_info "Using keyboard layout from base installation: $KEYMAP"
            # Validate the existing keymap
            if [ -f "/usr/share/kbd/keymaps/${KEYMAP}.map.gz" ]; then
                print_success "Keymap '$KEYMAP' is valid"
                if loadkeys "$KEYMAP" 2>/dev/null; then
                    print_success "Keyboard layout loaded: $KEYMAP"
                else
                    print_warning "Failed to load keymap '$KEYMAP' (expected in chroot), but using saved configuration"
                fi
            else
                print_warning "Keymap '$KEYMAP' from base installation not found, selecting new one..."
                select_keymap
            fi
        else
            print_warning "KEYMAP not found in saved configuration, selecting..."
            select_keymap
        fi
    else
        print_warning "Could not load system configuration, selecting keyboard layout..."
        select_keymap
    fi
else
    print_warning "Base installation not completed, selecting keyboard layout..."
    select_keymap
fi

# Save user configuration for future reference
save_install_info "/root/.alie-install-info" HOSTNAME TIMEZONE LOCALE KEYMAP

read -r -p "Press Enter to continue..."
smart_clear
# ===================================
# STEP 3: BOOT CONFIGURATION
# ===================================
print_step "101: STEP 3: Boot Configuration"

# CPU vendor (from install info or fallback to detection)
if [ -n "$CPU_VENDOR" ]; then
    print_success "CPU vendor from install info: $CPU_VENDOR"
else
    print_warning "CPU vendor not found in install info, detecting..."
    if grep -q "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
        CPU_VENDOR="intel"
        print_success "Detected Intel CPU"
    elif grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then
        CPU_VENDOR="amd"
        print_success "Detected AMD CPU"
    else
        print_error_detailed "Could not auto-detect CPU vendor" \
            "CPU vendor detection is needed for proper microcode installation" \
            "Microcode updates are critical for security and stability" \
            "Check /proc/cpuinfo or specify vendor manually (intel/amd)"
        read -r -p "Enter CPU vendor (intel/amd): " CPU_VENDOR
        
        if [ "$CPU_VENDOR" != "intel" ] && [ "$CPU_VENDOR" != "amd" ]; then
            print_error_detailed "CPU vendor must be 'intel' or 'amd'" \
                "Only Intel and AMD CPUs are supported for microcode updates" \
                "Invalid vendor selection prevents proper security updates" \
                "Choose 'intel' for Intel processors or 'amd' for AMD processors"
            exit 1
        fi
    fi
fi

# Detect boot mode (or use from install info)
if [ -n "$BOOT_MODE" ]; then
    print_info "Using boot mode from install info: $BOOT_MODE"
else
    if [ -d /sys/firmware/efi/efivars ]; then
        BOOT_MODE="UEFI"
        print_success "Boot mode detected: UEFI"
    else
        BOOT_MODE="BIOS"
        print_success "Boot mode detected: BIOS"
    fi
fi

if [ "$BOOT_MODE" == "BIOS" ]; then
    # Try to use disk from install info
    if [ -n "$ROOT_PARTITION" ]; then
        # Extract disk from root partition (e.g., /dev/sda3 -> /dev/sda)
        TARGET_DISK="${ROOT_PARTITION%%[0-9]*}"
        TARGET_DISK="${TARGET_DISK%%p[0-9]*}"     # Handle NVMe partitions (e.g., /dev/nvme0n1p3 -> /dev/nvme0n1)
        print_info "Auto-detected target disk from installation: $TARGET_DISK"
        read -r -p "Use this disk for bootloader? (Y/n): " CONFIRM_DISK
        
        if [[ $CONFIRM_DISK =~ ^[Nn]$ ]]; then
            smart_clear
            # Allow user to enter disk name with retry logic
            while true; do
                read -r -p "Enter disk for bootloader (e.g., /dev/sda or sda): " TARGET_DISK
                
                # Sanitize input - remove /dev/ prefix if present and whitespace
                TARGET_DISK="${TARGET_DISK#/dev/}"
                TARGET_DISK="$(echo "$TARGET_DISK" | tr -d '[:space:]')"
                
                # Convert back to full path
                TARGET_DISK="/dev/$TARGET_DISK"
                
                if [ -z "$TARGET_DISK" ] || [ "$TARGET_DISK" = "/dev/" ]; then
                    print_error_detailed "Disk name cannot be empty" \
                        "Bootloader installation requires a valid target disk" \
                        "Without a target disk, the system cannot boot properly" \
                        "Enter a valid disk path like /dev/sda or /dev/nvme0n1"
                    echo ""
                    read -r -p "Try again or exit? (t/e): " RETRY_CHOICE
                    if [[ $RETRY_CHOICE =~ ^[Ee]$ ]]; then
                        print_info "Exiting installation..."
                        exit 1
                    fi
                    continue
                fi
                
                if [ ! -b "$TARGET_DISK" ]; then
                    print_error_detailed "$TARGET_DISK is not a valid block device" \
                        "The specified disk does not exist or is not accessible" \
                        "Bootloader cannot be installed on non-existent hardware" \
                        "Run: lsblk -d -o NAME,SIZE,TYPE,MODEL to see available disks"
                    print_info "Available disks:"
                    lsblk -d -o NAME,SIZE,TYPE,MODEL 2>/dev/null | grep disk | while read -r line; do
                        echo "  /dev/$(echo "$line" | awk '{print $1}')"
                    done
                    echo ""
                    read -r -p "Try again or exit? (t/e): " RETRY_CHOICE
                    if [[ $RETRY_CHOICE =~ ^[Ee]$ ]]; then
                        print_info "Exiting installation..."
                        exit 1
                    fi
                    continue
                fi
                
                # Valid disk found
                break
            done
        fi
    else
        print_info "Available disks:"
        lsblk -d -o NAME,SIZE,TYPE 2>/dev/null | grep disk
        echo ""
        # Allow user to enter disk name with retry logic
        while true; do
            read -r -p "Enter disk for bootloader (e.g., /dev/sda or sda): " TARGET_DISK
            
            # Sanitize input - remove /dev/ prefix if present and whitespace
            TARGET_DISK="${TARGET_DISK#/dev/}"
            TARGET_DISK="$(echo "$TARGET_DISK" | tr -d '[:space:]')"
            
            # Convert back to full path
            TARGET_DISK="/dev/$TARGET_DISK"
            
            if [ -z "$TARGET_DISK" ] || [ "$TARGET_DISK" = "/dev/" ]; then
                print_error_detailed "Disk name cannot be empty" \
                    "BIOS bootloader installation requires a valid target disk" \
                    "Without specifying a disk, GRUB cannot be installed for BIOS boot" \
                    "Enter a valid disk path like /dev/sda or /dev/nvme0n1"
                echo ""
                read -r -p "Try again or exit? (t/e): " RETRY_CHOICE
                if [[ $RETRY_CHOICE =~ ^[Ee]$ ]]; then
                    print_info "Exiting installation..."
                    exit 1
                fi
                continue
            fi
            
            if [ ! -b "$TARGET_DISK" ]; then
                print_error_detailed "$TARGET_DISK is not a valid block device" \
                    "The specified disk for BIOS bootloader does not exist" \
                    "GRUB BIOS installation requires a valid physical disk" \
                    "Run: lsblk -d -o NAME,SIZE,TYPE to list available disks"
                print_info "Available disks:"
                lsblk -d -o NAME,SIZE,TYPE,MODEL 2>/dev/null | grep disk | while read -r line; do
                    echo "  /dev/$(echo "$line" | awk '{print $1}')"
                done
                echo ""
                read -r -p "Try again or exit? (t/e): " RETRY_CHOICE
                if [[ $RETRY_CHOICE =~ ^[Ee]$ ]]; then
                    print_info "Exiting installation..."
                    exit 1
                fi
                continue
            fi
            
            # Valid disk found
            break
        done
    fi
    
    print_success "Bootloader will be installed to: $TARGET_DISK"
else
    # UEFI mode - verify /boot is mounted
    if ! mountpoint -q /boot 2>/dev/null; then
        print_error_detailed "/boot is not mounted!" \
            "UEFI installation requires EFI partition mounted at /boot" \
            "Without /boot mounted, bootloader files cannot be installed" \
            "Mount your EFI partition: mount /dev/efi-partition /boot"
        print_info "UEFI installation requires EFI partition mounted at /boot"
        print_info "Please mount it before continuing"
        exit 1
    fi
    
    print_success "EFI partition mounted at /boot"
fi

read -r -p "Press Enter to continue..."
smart_clear
# ===================================
# STEP 4: TIMEZONE CONFIGURATION
# ===================================
print_step "101: STEP 4: Configuring Timezone"

print_info "Setting timezone to $TIMEZONE..."
ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
hwclock --systohc
print_success "Timezone configured"

# ===================================
# STEP 5: LOCALE CONFIGURATION
# ===================================
print_step "101: STEP 5: Configuring Locale"

print_info "Generating locale $LOCALE..."
# Remove duplicates first (escape special characters in locale)
ESCAPED_LOCALE=$(printf '%s\n' "$LOCALE" | sed 's/[.[\*^$/]/\\&/g')
sed -i "/^${ESCAPED_LOCALE} UTF-8/d" /etc/locale.gen 2>/dev/null || true
sed -i '/^en_US.UTF-8 UTF-8/d' /etc/locale.gen 2>/dev/null || true
# Add locales
echo "$LOCALE UTF-8" >> /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
print_success "Locale configured"

# Configure keyboard
print_info "Setting console keymap to $KEYMAP..."
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
print_success "Console keymap configured"

read -r -p "Press Enter to continue..."
smart_clear
# ===================================
# STEP 6: NETWORK CONFIGURATION
# ===================================
print_step "101: STEP 6: Configuring Network"

print_info "Setting hostname to $HOSTNAME..."
echo "$HOSTNAME" > /etc/hostname

# Deploy hosts file from template
print_info "Deploying hosts configuration..."
deploy_config "network/hosts.template" "/etc/hosts" "HOSTNAME=$HOSTNAME"
# Deploy NetworkManager configuration
print_info "Deploying NetworkManager configuration..."
deploy_config_direct "network/NetworkManager.conf" "/etc/NetworkManager/NetworkManager.conf" "644"
# Deploy systemd-resolved configuration
print_info "Deploying systemd-resolved configuration..."
deploy_config_direct "network/resolved.conf" "/etc/systemd/resolved.conf" "644"
print_success "Network configuration complete"

read -r -p "Press Enter to continue..."
smart_clear
# ===================================
# STEP 7: ROOT PASSWORD
# ===================================
print_step "101: STEP 7: Root Password"

print_info "Set a strong password for the root account"
echo ""
passwd

read -r -p "Press Enter to continue..."
smart_clear
# ===================================
# STEP 8: PACMAN CONFIGURATION
# ===================================
print_step "101: STEP 8: Configuring Package Manager"

print_info "Enabling color output and multilib repository..."
sed -i 's/#Color/Color/' /etc/pacman.conf
sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf

print_info "Synchronizing package databases..."
if retry_command 3 "pacman -Syu --noconfirm"; then
    print_success "Package database synchronized"
else
    print_error_detailed "Failed to synchronize package database" \
        "Package database sync is required before installing software" \
        "Without updated package info, installations may fail or be insecure" \
        "Check internet connection and mirror status: ping archlinux.org"
    print_warning "Continuing anyway, but you may have issues later"
fi

read -r -p "Press Enter to continue..."
smart_clear
# ===================================
# STEP 9: BOOTLOADER INSTALLATION
# ===================================
print_step "101: STEP 9: Installing Bootloader (${BOOTLOADER:-grub})"

# Verify microcode was installed in step 01
if [ "$MICROCODE_INSTALLED" == "yes" ]; then
    print_success "Microcode already installed (from base installation)"
elif pacman -Q intel-ucode &>/dev/null || pacman -Q amd-ucode &>/dev/null; then
    print_success "Microcode already installed"
else
    print_warning "Microcode not detected! It should have been installed in step 01"
    print_warning "Bootloader may not load microcode updates properly"
fi

# Determine the target disk for bootloader installation (needed for BIOS mode)
if [ "$BOOT_MODE" != "UEFI" ] && [ -n "$ROOT_PARTITION" ]; then
    TARGET_DISK="${ROOT_PARTITION%%[0-9]*}"  # Extract disk from root partition (e.g., /dev/sda3 -> /dev/sda)
    TARGET_DISK="${TARGET_DISK%%p[0-9]*}"     # Handle NVMe partitions (e.g., /dev/nvme0n1p3 -> /dev/nvme0n1)
    print_info "Target disk for BIOS bootloader: $TARGET_DISK"
elif [ "$BOOT_MODE" != "UEFI" ]; then
    print_error_detailed "Cannot determine target disk for BIOS bootloader installation" \
        "ROOT_PARTITION is not set, cannot identify target disk for GRUB" \
        "BIOS boot requires knowing which disk to install the bootloader to" \
        "Check partitioning step or set ROOT_PARTITION manually"
    print_info "ROOT_PARTITION is not set"
    exit 1
fi

# Install and configure the selected bootloader
case "${BOOTLOADER:-grub}" in
    "grub")
        print_info "Installing GRUB bootloader..."
        
        if [ "$BOOT_MODE" == "UEFI" ]; then
            print_info "Installing GRUB for UEFI"
            
            # Try x86_64-efi first (most common)
            if grub-install --target=x86_64-efi --boot-directory=/boot --efi-directory=/boot; then
                print_success "GRUB installed successfully (UEFI x86_64 mode)"
            else
                print_warning "x86_64-efi installation failed, trying i386-efi..."
                # Fallback to i386-efi if x86_64 fails
                if grub-install --target=i386-efi --boot-directory=/boot --efi-directory=/boot; then
                    print_success "GRUB installed successfully (UEFI i386 mode)"
                else
                    print_error_detailed "GRUB UEFI installation failed on both x86_64 and i386 targets!" \
                        "Neither x86_64-efi nor i386-efi GRUB installation succeeded" \
                        "System may not boot without a working bootloader" \
                        "Check EFI partition mounting and try manual GRUB installation"
                    exit 1
                fi
            fi
        else
            # BIOS mode (works for both MBR and GPT)
            print_info "Installing GRUB for BIOS on disk: $TARGET_DISK"
            if grub-install --target=i386-pc "$TARGET_DISK"; then
                print_success "GRUB installed successfully (BIOS mode) on $TARGET_DISK"
            else
                print_error_detailed "GRUB BIOS installation failed!" \
                    "GRUB could not be installed for BIOS boot mode" \
                    "System will not be bootable without a working bootloader" \
                    "Verify disk is valid and try alternative bootloader (Limine)"
                exit 1
            fi
        fi

        print_info "GRUB installation completed"
        ;;
        
    "systemd-boot")
        if [ "$BOOT_MODE" != "UEFI" ]; then
            print_error_detailed "systemd-boot requires UEFI boot mode!" \
                "systemd-boot only works with UEFI firmware, not legacy BIOS" \
                "Wrong bootloader selection for current firmware type" \
                "Use GRUB or Limine for BIOS systems, or enable UEFI in firmware"
            print_info "Please select GRUB or Limine for BIOS systems"
            exit 1
        fi
        
        print_info "Installing systemd-boot..."
        if bootctl install; then
            print_success "systemd-boot installed successfully"
        else
            print_error_detailed "systemd-boot installation failed!" \
                "bootctl install command did not succeed" \
                "UEFI bootloader installation failed, system may not boot" \
                "Check EFI partition and try alternative bootloader (GRUB)"
            exit 1
        fi
        
        print_info "Configuring systemd-boot..."
        
        # Create loader configuration
        cat > /boot/loader/loader.conf << EOF
default  arch.conf
timeout  5
console-mode max
editor   no
EOF
        
        # Build kernel parameters according to Arch Wiki best practices
        ROOT_UUID=$(get_partition_uuid "$ROOT_PARTITION")
        
        # Base parameters
        KERNEL_PARAMS="root=UUID=$ROOT_UUID rw"
        
        # Add rootfstype for filesystem type
        if [ -n "$ROOT_FS" ]; then
            KERNEL_PARAMS="$KERNEL_PARAMS rootfstype=$ROOT_FS"
        fi
        
        # Add resume parameter for swap/hibernation
        if [ -n "$SWAP_PARTITION" ]; then
            SWAP_UUID=$(get_partition_uuid "$SWAP_PARTITION")
            if [ -n "$SWAP_UUID" ]; then
                KERNEL_PARAMS="$KERNEL_PARAMS resume=UUID=$SWAP_UUID"
            fi
        fi
        
        # Add rootflags for Btrfs subvolumes
        if [ "$ROOT_FS" = "btrfs" ] && [ "$PARTITION_SCHEME" = "btrfs-subvolumes" ]; then
            KERNEL_PARAMS="$KERNEL_PARAMS rootflags=subvol=@"
        fi
        
        # Add recommended kernel parameters
        KERNEL_PARAMS="$KERNEL_PARAMS quiet udev.log_priority=3 vt.global_cursor_default=0 loglevel=3"
        
        # Determine available kernels (expand detection for more variants)
        INSTALLED_KERNELS=()
        if [ -n "${SELECTED_KERNELS:-}" ]; then
            # Use selected kernels from installation
            read -r -a INSTALLED_KERNELS <<< "$SELECTED_KERNELS"
        else
            # Auto-detect installed kernels (include more variants)
            for kernel in linux linux-zen linux-hardened linux-lts linux-zen-git linux-hardened-git linux-mainline linux-mainline-git; do
                if pacman -Q "$kernel" &>/dev/null; then
                    INSTALLED_KERNELS+=("$kernel")
                fi
            done
            # Fallback to linux if none detected
            if [ ${#INSTALLED_KERNELS[@]} -eq 0 ]; then
                INSTALLED_KERNELS=("linux")
            fi
        fi
        
        print_info "Detected ${#INSTALLED_KERNELS[@]} kernel(s): ${INSTALLED_KERNELS[*]}"
        
        # Create boot entry for the first (default) kernel
        DEFAULT_KERNEL="${INSTALLED_KERNELS[0]}"
        
        # Add microcode if available (check once, reuse for all entries)
        MICROCODE_PARAM=""
        if pacman -Q intel-ucode &>/dev/null; then
            MICROCODE_PARAM="initrd  /intel-ucode.img"
        elif pacman -Q amd-ucode &>/dev/null; then
            MICROCODE_PARAM="initrd  /amd-ucode.img"
        fi
        
        cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-$DEFAULT_KERNEL
$MICROCODE_PARAM
initrd  /initramfs-$DEFAULT_KERNEL.img
options $KERNEL_PARAMS
EOF
        
        # Create entries for additional kernels
        for kernel_pkg in "${INSTALLED_KERNELS[@]:1}"; do
            kernel_name="${kernel_pkg#linux}"  # Remove "linux" prefix
            kernel_name="${kernel_name#-}"     # Remove leading dash if present
            [ -z "$kernel_name" ] && kernel_name="default"
            
            # Capitalize first letter for better display
            display_name="$(tr '[:lower:]' '[:upper:]' <<< "${kernel_name:0:1}")${kernel_name:1}"
            [ "$display_name" = "Default" ] && display_name="Stable"
            
            cat > /boot/loader/entries/arch-"$kernel_name".conf << EOF
title   Arch Linux ($display_name)
linux   /vmlinuz-$kernel_pkg
$MICROCODE_PARAM
initrd  /initramfs-$kernel_pkg.img
options $KERNEL_PARAMS
EOF
        done
        
        print_success "systemd-boot configured with ${#INSTALLED_KERNELS[@]} kernel(s)"
        
        # Verify systemd-boot configuration
        if [ -f /boot/loader/loader.conf ] && [ -f /boot/loader/entries/arch.conf ]; then
            print_success "systemd-boot configuration files verified"
            
            # Verify all kernel entries were created
            missing_entries=0
            for kernel_pkg in "${INSTALLED_KERNELS[@]}"; do
                kernel_name="${kernel_pkg#linux}"
                kernel_name="${kernel_name#-}"
                [ -z "$kernel_name" ] && kernel_name="default"
                
                if [ "$kernel_pkg" = "$DEFAULT_KERNEL" ]; then
                    # Main entry
                    [ ! -f "/boot/loader/entries/arch.conf" ] && ((missing_entries++))
                else
                    # Additional entries
                    [ ! -f "/boot/loader/entries/arch-$kernel_name.conf" ] && ((missing_entries++))
                fi
            done
            
            if [ $missing_entries -eq 0 ]; then
                print_success "All kernel boot entries created successfully"
            else
                print_warning "$missing_entries kernel boot entries missing"
            fi
        else
            print_error_detailed "systemd-boot configuration files missing!" \
                "Required boot configuration files were not created" \
                "System will not boot without proper systemd-boot configuration" \
                "Check /boot/loader/ directory and recreate configuration manually"
            exit 1
        fi
        ;;
        
    "limine")
        print_info "Installing Limine bootloader..."
        
        # Install Limine bootloader
        if [ "$BOOT_MODE" == "UEFI" ]; then
            print_info "Creating EFI boot directory..."
            mkdir -p /boot/EFI/BOOT
            mkdir -p /boot/limine
            if limine-install /boot/EFI/BOOT; then
                print_success "Limine files installed successfully (UEFI mode)"
                
                # Create NVRAM boot entry (required for UEFI)
                print_info "Creating UEFI boot entry for Limine..."
                
                # Find the ESP partition number
                ESP_PARTITION=$(findmnt -n -o SOURCE /boot | sed 's/.*\([0-9]\+\)$/\1/')
                ESP_DISK=$(findmnt -n -o SOURCE /boot | sed 's/p\?[0-9]\+$//')
                
                if [ -n "$ESP_PARTITION" ] && [ -n "$ESP_DISK" ]; then
                    if efibootmgr --create --disk "$ESP_DISK" --part "$ESP_PARTITION" --label "Arch Linux Limine" --loader '\EFI\BOOT\BOOTX64.EFI' --unicode; then
                        print_success "UEFI boot entry created for Limine"
                    else
                        print_error_detailed "Failed to create UEFI boot entry!" \
                            "efibootmgr could not add Limine to UEFI boot manager" \
                            "System may not boot automatically into Limine" \
                            "Boot entry may need to be created manually in firmware"
                        print_warning "You may need to create the boot entry manually after installation"
                    fi
                else
                    print_warning "Could not detect ESP partition for boot entry creation"
                    print_info "Limine files are installed, but you may need to create NVRAM entry manually"
                fi
            else
                print_error_detailed "Limine installation failed!" \
                    "limine-install command did not succeed for UEFI" \
                    "UEFI bootloader installation failed, system may not boot" \
                    "Check EFI partition mounting and try alternative bootloader"
                exit 1
            fi
        else
            # BIOS mode - copy limine-bios.sys and install bootloader
            print_info "Copying Limine BIOS stage 3 code..."
            mkdir -p /boot/limine
            if cp /usr/share/limine/limine-bios.sys /boot/limine/; then
                print_success "Limine BIOS stage 3 code copied"
                
                print_info "Installing Limine BIOS bootloader to $TARGET_DISK..."
                # For GPT disks, limine bios-install will auto-detect the BIOS boot partition
                # For MBR disks, it installs directly to MBR
                if limine bios-install "$TARGET_DISK"; then
                    print_success "Limine BIOS bootloader installed to $TARGET_DISK"
                else
                    print_error_detailed "Limine BIOS installation failed!" \
                        "limine bios-install command did not succeed" \
                        "BIOS bootloader installation failed, system may not boot" \
                        "Verify target disk and try alternative bootloader (GRUB)"
                    exit 1
                fi
            else
                print_error_detailed "Failed to copy limine-bios.sys!" \
                    "BIOS bootloader file could not be copied to /boot" \
                    "Without this file, Limine BIOS installation cannot proceed" \
                    "Check if limine package is installed: pacman -Q limine"
                exit 1
            fi
        fi
        
        print_info "Configuring Limine..."
        
        # Build kernel parameters according to Arch Wiki best practices
        ROOT_UUID=$(get_partition_uuid "$ROOT_PARTITION")
        
        # Base parameters
        KERNEL_PARAMS="root=UUID=$ROOT_UUID rw"
        
        # Add rootfstype for filesystem type
        if [ -n "$ROOT_FS" ]; then
            KERNEL_PARAMS="$KERNEL_PARAMS rootfstype=$ROOT_FS"
        fi
        
        # Add resume parameter for swap/hibernation
        if [ -n "$SWAP_PARTITION" ]; then
            SWAP_UUID=$(get_partition_uuid "$SWAP_PARTITION")
            if [ -n "$SWAP_UUID" ]; then
                KERNEL_PARAMS="$KERNEL_PARAMS resume=UUID=$SWAP_UUID"
            fi
        fi
        
        # Add rootflags for Btrfs subvolumes
        if [ "$ROOT_FS" = "btrfs" ] && [ "$PARTITION_SCHEME" = "btrfs-subvolumes" ]; then
            KERNEL_PARAMS="$KERNEL_PARAMS rootflags=subvol=@"
        fi
        
        # Add recommended kernel parameters
        KERNEL_PARAMS="$KERNEL_PARAMS quiet udev.log_priority=3 vt.global_cursor_default=0 loglevel=3"
        
        # Determine available kernels (expand detection for more variants)
        INSTALLED_KERNELS=()
        if [ -n "${SELECTED_KERNELS:-}" ]; then
            # Use selected kernels from installation
            read -r -a INSTALLED_KERNELS <<< "$SELECTED_KERNELS"
        else
            # Auto-detect installed kernels (include more variants)
            for kernel in linux linux-zen linux-hardened linux-lts linux-zen-git linux-hardened-git linux-mainline linux-mainline-git; do
                if pacman -Q "$kernel" &>/dev/null; then
                    INSTALLED_KERNELS+=("$kernel")
                fi
            done
            # Fallback to linux if none detected
            if [ ${#INSTALLED_KERNELS[@]} -eq 0 ]; then
                INSTALLED_KERNELS=("linux")
            fi
        fi
        
        print_info "Configuring Limine with ${#INSTALLED_KERNELS[@]} kernel(s): ${INSTALLED_KERNELS[*]}"
        
        # Determine limine.conf location based on boot mode
        if [ "$BOOT_MODE" == "UEFI" ]; then
            LIMINE_CONF_PATH="/boot/EFI/BOOT/limine.conf"
            mkdir -p /boot/EFI/BOOT
            BOOT_PARTITION="$EFI_PARTITION"
        else
            LIMINE_CONF_PATH="/boot/limine/limine.conf"
            mkdir -p /boot/limine
        fi
        
        # Determine if /boot is on a separate partition
        BOOT_PREFIX="boot():"
        if [ -n "$BOOT_PARTITION" ] && [ "$BOOT_PARTITION" != "$ROOT_PARTITION" ]; then
            # /boot is on separate partition, use PARTUUID
            BOOT_PARTUUID=$(blkid -s PARTUUID -o value "$BOOT_PARTITION" 2>/dev/null)
            if [ -n "$BOOT_PARTUUID" ]; then
                BOOT_PREFIX="uuid($BOOT_PARTUUID):"
            fi
        fi
        
        cat > "$LIMINE_CONF_PATH" << EOF
TIMEOUT=5

:Arch Linux
    PROTOCOL=linux
EOF
        
        # Add microcode module if available
        if pacman -Q intel-ucode &>/dev/null; then
            cat >> "$LIMINE_CONF_PATH" << EOF
    MODULE_PATH=${BOOT_PREFIX}/intel-ucode.img
EOF
        elif pacman -Q amd-ucode &>/dev/null; then
            cat >> "$LIMINE_CONF_PATH" << EOF
    MODULE_PATH=${BOOT_PREFIX}/amd-ucode.img
EOF
        fi
        
        # Add kernel and initramfs paths
        cat >> "$LIMINE_CONF_PATH" << EOF
    KERNEL_PATH=${BOOT_PREFIX}/vmlinuz-linux
    CMDLINE=$KERNEL_PARAMS
    MODULE_PATH=${BOOT_PREFIX}/initramfs-linux.img
EOF
        
        # Add entries for additional kernels if any
        for kernel_pkg in "${INSTALLED_KERNELS[@]:1}"; do
            kernel_name="${kernel_pkg#linux}"  # Remove "linux" prefix
            kernel_name="${kernel_name#-}"     # Remove leading dash if present
            [ -z "$kernel_name" ] && kernel_name="default"
            
            # Capitalize first letter for better display
            display_name="$(tr '[:lower:]' '[:upper:]' <<< "${kernel_name:0:1}")${kernel_name:1}"
            [ "$display_name" = "Default" ] && display_name="Stable"
            
            cat >> "$LIMINE_CONF_PATH" << EOF

:Arch Linux ($display_name)
    PROTOCOL=linux
EOF
            
            # Add microcode for additional kernels too
            if pacman -Q intel-ucode &>/dev/null; then
                cat >> "$LIMINE_CONF_PATH" << EOF
    MODULE_PATH=${BOOT_PREFIX}/intel-ucode.img
EOF
            elif pacman -Q amd-ucode &>/dev/null; then
                cat >> "$LIMINE_CONF_PATH" << EOF
    MODULE_PATH=${BOOT_PREFIX}/amd-ucode.img
EOF
            fi
            
            cat >> "$LIMINE_CONF_PATH" << EOF
    KERNEL_PATH=${BOOT_PREFIX}/vmlinuz-$kernel_pkg
    CMDLINE=$KERNEL_PARAMS
    MODULE_PATH=${BOOT_PREFIX}/initramfs-$kernel_pkg.img
EOF
        done
        
        print_success "Limine configured with ${#INSTALLED_KERNELS[@]} kernel(s)"
        
        # Verify Limine configuration
        if [ -f "$LIMINE_CONF_PATH" ]; then
            print_success "Limine configuration file verified at $LIMINE_CONF_PATH"
        else
            print_error_detailed "Limine configuration file missing!" \
                "limine.conf was not created in the expected location" \
                "System will not boot without proper Limine configuration" \
                "Check configuration file creation and recreate manually if needed"
            exit 1
        fi
        ;;
        
    *)
        print_error_detailed "Unknown bootloader: ${BOOTLOADER:-grub}" \
            "The specified bootloader is not supported by ALIE" \
            "Unsupported bootloader prevents system boot configuration" \
            "Use 'grub', 'systemd-boot', or 'limine' instead"
        print_info "Supported bootloaders: grub, systemd-boot, limine"
        exit 1
        ;;
esac

read -r -p "Press Enter to continue..."
smart_clear
# ===================================
# STEP 9b: CONFIGURE BOOT SYSTEM
# ===================================
print_step "101: STEP 9b: Configuring Boot System"

print_info "Configuring initramfs and bootloader for $ROOT_FS filesystem..."

# Configure mkinitcpio and GRUB with appropriate parameters
if configure_boot_system; then
    print_success "Boot system configured successfully"
else
    print_error_detailed "Failed to configure boot system!" \
        "Boot system configuration (initramfs + bootloader) did not complete" \
        "System may not boot correctly without proper configuration" \
        "Check mkinitcpio.conf and GRUB configuration manually"
    print_warning "The system may not boot correctly without proper initramfs configuration"
    print_info "You may need to manually configure mkinitcpio.conf and regenerate initramfs"
    read -r -p "Continue anyway? (y/N): " CONTINUE_BOOT_CONFIG
    if [[ ! $CONTINUE_BOOT_CONFIG =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ===================================
# STEP 10: AUDIO SYSTEM CONFIGURATION
# ===================================
print_step "101: STEP 10: Audio System Configuration"

echo ""
print_info "Audio Server Selection"
echo ""
echo "Choose your audio server:"
echo "  ${CYAN}1)${NC} PipeWire (modern, recommended)"
echo "     - Low latency audio/video routing"
echo "     - Pro-audio support (JACK compatibility)"
echo "     - Better Bluetooth support"
echo ""
echo "  ${CYAN}2)${NC} PulseAudio (traditional, stable)"
echo "     - Mature and widely tested"
echo "     - Good compatibility with older applications"
echo ""

read -r -p "Select audio server [1-2]: " AUDIO_SERVER

case "$AUDIO_SERVER" in
    1)
        print_info "Installing PipeWire..."
        if retry_command 3 "pacman -S --needed --noconfirm pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber"; then
            print_success "PipeWire installed"
            
            # Deploy PipeWire configurations
            print_info "Deploying PipeWire configurations..."
            mkdir -p /etc/pipewire
            deploy_config_direct "audio/pipewire.conf" "/etc/pipewire/pipewire.conf" "644"
            mkdir -p /etc/wireplumber/main.conf.d
            deploy_config_direct "audio/wireplumber.conf" "/etc/wireplumber/main.conf.d/50-alie.conf" "644"
            deploy_config_direct "audio/asound.conf" "/etc/asound.conf" "644"
            print_success "PipeWire configurations deployed"
        else
            print_error_detailed "Failed to install PipeWire" \
                "PipeWire audio system installation failed, preventing audio configuration" \
                "Check package database and network connectivity for package installation" \
                "pacman -Syu; pacman -S pipewire pipewire-alsa wireplumber"
            exit 1
        fi
        ;;
    2)
        print_info "Installing PulseAudio..."
        if retry_command 3 "pacman -S --needed --noconfirm pulseaudio pulseaudio-alsa"; then
            print_success "PulseAudio installed"
            
            # Deploy ALSA configuration for PulseAudio
            print_info "Deploying ALSA configuration for PulseAudio..."
            deploy_config_direct "audio/asound.conf" "/etc/asound.conf" "644"
            print_success "ALSA configuration deployed"
        else
            print_error_detailed "Failed to install PulseAudio" \
                "PulseAudio audio system installation failed, preventing audio configuration" \
                "Check package database and network connectivity for package installation" \
                "pacman -Syu; pacman -S pulseaudio pulseaudio-alsa"
            exit 1
        fi
        ;;
    *)
        print_error_detailed "Invalid selection" \
            "The selected audio system option is not valid" \
            "Choose 1 for PipeWire (recommended) or 2 for PulseAudio" \
            "echo 'Available options: 1) PipeWire, 2) PulseAudio'"
        exit 1
        ;;
esac

echo ""
print_info "GStreamer Multimedia Framework"
echo ""
echo "GStreamer provides multimedia codec support (audio/video playback)"
echo "Note: Only codec libraries, no GUI or display server dependencies"
echo ""
echo "Select GStreamer installation:"
echo "  ${CYAN}1)${NC} Full install (all plugins - recommended)"
echo "     base + good + bad + ugly + libav"
echo ""
echo "  ${CYAN}2)${NC} Essential only (base + good + libav)"
echo "     Most common codecs and formats"
echo ""
echo "  ${CYAN}3)${NC} Minimal (base only)"
echo "     Basic audio/video support"
echo ""
echo "  ${CYAN}4)${NC} Custom selection"
echo "     Choose individual plugin groups"
echo ""
echo "  ${CYAN}5)${NC} Skip (install later if needed)"
echo ""

read -r -p "Select option [1-5]: " GST_OPTION

case "$GST_OPTION" in
    1)
        print_info "Installing all GStreamer plugins..."
        if retry_command 3 "pacman -S --needed --noconfirm gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav"; then
            print_success "All GStreamer plugins installed"
        else
            print_warning "Failed to install some GStreamer plugins"
        fi
        ;;
    2)
        print_info "Installing essential GStreamer plugins..."
        if retry_command 3 "pacman -S --needed --noconfirm gst-plugins-base gst-plugins-good gst-libav"; then
            print_success "Essential GStreamer plugins installed"
        else
            print_warning "Failed to install some GStreamer plugins"
        fi
        ;;
    3)
        print_info "Installing minimal GStreamer..."
        if retry_command 3 "pacman -S --needed --noconfirm gst-plugins-base"; then
            print_success "Base GStreamer plugins installed"
        else
            print_warning "Failed to install GStreamer base"
        fi
        ;;
    4)
        echo ""
        print_info "Custom GStreamer Selection"
        echo "Select plugins to install (space-separated, e.g., 1 2 4):"
        echo "  1) gst-plugins-base (basic codecs - ogg, vorbis, theora)"
        echo "  2) gst-plugins-good (common formats - mp3, aac, webm, flac)"
        echo "  3) gst-plugins-bad (advanced/experimental codecs)"
        echo "  4) gst-plugins-ugly (patent-encumbered - mp3, dvd)"
        echo "  5) gst-libav (FFmpeg integration - h264, hevc, etc.)"
        echo ""
        read -r -a GST_CHOICES -p "Enter selections: "
        
        GST_PKGS=()
        for choice in "${GST_CHOICES[@]}"; do
            case "$choice" in
                1) GST_PKGS+=("gst-plugins-base") ;;
                2) GST_PKGS+=("gst-plugins-good") ;;
                3) GST_PKGS+=("gst-plugins-bad") ;;
                4) GST_PKGS+=("gst-plugins-ugly") ;;
                5) GST_PKGS+=("gst-libav") ;;
            esac
        done
        
        if [ ${#GST_PKGS[@]} -gt 0 ]; then
            print_info "Installing selected plugins: ${GST_PKGS[*]}"
            if retry_command 3 pacman -S --needed --noconfirm "${GST_PKGS[@]}"; then
                print_success "Selected GStreamer plugins installed"
            else
                print_warning "Failed to install some plugins"
            fi
        else
            print_info "No plugins selected"
        fi
        ;;
    5)
        print_info "Skipping GStreamer plugins"
        ;;
    *)
        print_error_detailed "Invalid selection" \
            "The selected GStreamer option is not valid" \
            "Choose 1-5 for GStreamer plugin installation options" \
            "echo 'Available options: 1) Full, 2) Essential, 3) Minimal, 4) Custom, 5) Skip'"
        exit 1
        ;;
esac

# ===================================
# STEP 11: ENABLE SERVICES
# ===================================
print_step "101: STEP 11: Enabling System Services"

print_info "Enabling NetworkManager..."
systemctl enable NetworkManager
print_success "NetworkManager will start on boot"

print_info "Installing and enabling reflector timer..."
if retry_command 3 "pacman -S --needed --noconfirm reflector"; then
    systemctl enable reflector.timer
    print_success "Reflector timer enabled (automatic mirror updates)"
else
    print_warning "Failed to install reflector, skipping"
fi

# ===================================
# CONFIGURATION COMPLETE
# ===================================
print_step "101: System Configuration Completed Successfully!"

# Mark progress
save_progress "02-system-configured"

echo ""
print_success "Configuration finished!"
echo ""
print_info "Next steps:"
echo "  ${CYAN}1.${NC} Exit the chroot environment:"
echo "     ${YELLOW}exit${NC}"
echo ""
echo "  ${CYAN}2.${NC} Unmount all partitions (in correct order):"
echo "     ${YELLOW}umount /mnt/home 2>/dev/null; umount /mnt/boot 2>/dev/null; umount /mnt${NC}"
echo ""
echo "  ${CYAN}3.${NC} Sync filesystem:"
echo "     ${YELLOW}sync${NC}"
echo ""
echo "  ${CYAN}4.${NC} Reboot the system:"
echo "     ${YELLOW}reboot${NC}"
echo ""
echo "  ${CYAN}5.${NC} After reboot, login as root and run:"
echo "     ${YELLOW}bash /root/alie-scripts/alie.sh${NC}"
echo ""
print_warning "Remember to remove the installation media before rebooting!"
echo ""
