#!/bin/bash
# ALIE System Configuration Script
# This script should be run inside arch-chroot
#
# ?????? WARNING: EXPERIMENTAL SCRIPT
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

# Welcome banner
show_alie_banner
show_warning_banner

print_info "This script will configure:"
echo "  ??? Timezone and system clock"
echo "  ??? Locale and keyboard layout"
echo "  ??? Hostname and network"
echo "  ??? Root password"
echo "  ??? Package manager (pacman)"
echo "  ??? Bootloader (GRUB)"
echo ""
read -r -p "Press Enter to continue or Ctrl+C to exit..."

# Validate environment
print_step "STEP 1: Environment Validation"

# Verify running as root
if ! require_root; then
    exit 1
fi

# Verify chroot environment
verify_chroot

# Load configuration from previous script
load_install_info

# ===================================
# STEP 2: COLLECT CONFIGURATION
# ===================================
print_step "STEP 2: System Configuration"

# Hostname
echo ""
print_info "Hostname Configuration"
echo "The hostname identifies your computer on a network"
echo "Example: arch-desktop, my-laptop, workstation"
read -r -p "Enter hostname: " HOSTNAME

# Validate inputs
if [ -z "$HOSTNAME" ]; then
    print_error "Hostname cannot be empty"
    exit 1
fi

if ! [[ "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
    print_error "Invalid hostname. Use only letters, numbers, and hyphens"
    print_info "Hostname must start and end with alphanumeric character"
    exit 1
fi

print_success "Hostname: $HOSTNAME"

# Timezone
echo ""
print_info "Timezone Configuration"
echo "Common timezones:"
echo "  ??? America/New_York     (US Eastern)"
echo "  ??? America/Chicago      (US Central)"
echo "  ??? America/Denver       (US Mountain)"
echo "  ??? America/Los_Angeles  (US Pacific)"
echo "  ??? America/Mexico_City  (Mexico)"
echo "  ??? Europe/London        (UK)"
echo "  ??? Europe/Paris         (Central Europe)"
echo "  ??? Asia/Tokyo           (Japan)"
echo ""
print_info "For a complete list, check: /usr/share/zoneinfo/"
read -r -p "Enter timezone (e.g., America/New_York): " TIMEZONE

if [ -z "$TIMEZONE" ]; then
    print_error "Timezone cannot be empty"
    exit 1
fi

# Sanitize timezone input - prevent path traversal
TIMEZONE="${TIMEZONE//..\/}"  # Remove ../ sequences
TIMEZONE="${TIMEZONE#/}"      # Remove leading /
TIMEZONE="${TIMEZONE%/}"      # Remove trailing /

# Validate timezone format (Region/City or Region/Subregion/City)
if ! [[ "$TIMEZONE" =~ ^[A-Z][a-zA-Z_]+/[A-Z][a-zA-Z_]+(/[A-Z][a-zA-Z_]+)?$ ]]; then
    print_error "Invalid timezone format: $TIMEZONE"
    print_info "Expected format: Region/City (e.g., America/New_York)"
    exit 1
fi

    if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
    print_error "Invalid timezone '$TIMEZONE'"
    print_info "Available regions:"
    # List top-level region directories in /usr/share/zoneinfo safely
    find /usr/share/zoneinfo -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | grep -v "^[a-z]" | head -20
    exit 1
fi

print_success "Timezone: $TIMEZONE"

# Locale
echo ""
print_info "Locale Configuration"
echo "Common locales:"
echo "  ??? en_US.UTF-8  (English - United States)"
echo "  ??? en_GB.UTF-8  (English - United Kingdom)"
echo "  ??? es_ES.UTF-8  (Spanish - Spain)"
echo "  ??? es_MX.UTF-8  (Spanish - Mexico)"
echo "  ??? de_DE.UTF-8  (German - Germany)"
echo "  ??? fr_FR.UTF-8  (French - France)"
echo ""
read -r -p "Enter locale (default: en_US.UTF-8): " LOCALE
LOCALE=${LOCALE:-en_US.UTF-8}

if [ -z "$LOCALE" ]; then
    print_error "Locale cannot be empty"
    exit 1
fi

# Sanitize locale input - must match pattern xx_YY.UTF-8 or xx_YY.utf8
if ! [[ "$LOCALE" =~ ^[a-z]{2,3}_[A-Z]{2}\.([Uu][Tt][Ff]-?8)$ ]]; then
    print_error "Invalid locale format: $LOCALE"
    print_info "Expected format: xx_YY.UTF-8 (e.g., en_US.UTF-8)"
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
echo "Common layouts:"
echo "  ??? us           (US English)"
echo "  ??? uk           (UK English)"
echo "  ??? de-latin1    (German)"
echo "  ??? es           (Spanish)"
echo "  ??? fr-latin1    (French)"
echo "  ??? la-latin1    (Latin American)"
echo ""
print_info "For all layouts: localectl list-keymaps"
read -r -p "Enter keyboard layout (default: us): " KEYMAP
KEYMAP=${KEYMAP:-us}

if [ -z "$KEYMAP" ]; then
    print_error "Keyboard layout cannot be empty"
    exit 1
fi

print_success "Keyboard layout: $KEYMAP"

# ===================================
# STEP 3: BOOT CONFIGURATION
# ===================================
print_step "STEP 3: Boot Configuration"

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
        print_error "Could not auto-detect CPU vendor"
        read -r -p "Enter CPU vendor (intel/amd): " CPU_VENDOR
        
        if [ "$CPU_VENDOR" != "intel" ] && [ "$CPU_VENDOR" != "amd" ]; then
            print_error "CPU vendor must be 'intel' or 'amd'"
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
        GRUB_DISK="${ROOT_PARTITION%%[0-9]*}"
        print_info "Auto-detected GRUB disk from installation: $GRUB_DISK"
        read -r -p "Use this disk for GRUB? (Y/n): " CONFIRM_DISK
        
        if [[ $CONFIRM_DISK =~ ^[Nn]$ ]]; then
            read -r -p "Enter disk for GRUB (e.g., /dev/sda): " GRUB_DISK
        fi
    else
        print_info "Available disks:"
        lsblk -d -o NAME,SIZE,TYPE | grep disk
        echo ""
        read -r -p "Enter disk for GRUB (e.g., /dev/sda): " GRUB_DISK
    fi
    
    if [ -z "$GRUB_DISK" ]; then
        print_error "GRUB disk cannot be empty for BIOS mode"
        exit 1
    fi
    
    if [ ! -b "$GRUB_DISK" ]; then
        print_error "$GRUB_DISK is not a valid block device"
        exit 1
    fi
    
    print_success "GRUB will be installed to: $GRUB_DISK"
else
    # UEFI mode - verify /boot is mounted
    if ! mountpoint -q /boot 2>/dev/null; then
        print_error "/boot is not mounted!"
        print_info "UEFI installation requires EFI partition mounted at /boot"
        print_info "Please mount it before continuing"
        exit 1
    fi
    
    print_success "EFI partition mounted at /boot"
fi

# ===================================
# STEP 4: TIMEZONE CONFIGURATION
# ===================================
print_step "STEP 4: Configuring Timezone"

print_info "Setting timezone to $TIMEZONE..."
ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
hwclock --systohc
print_success "Timezone configured"

# ===================================
# STEP 5: LOCALE CONFIGURATION
# ===================================
print_step "STEP 5: Configuring Locale"

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

# ===================================
# STEP 6: NETWORK CONFIGURATION
# ===================================
print_step "STEP 6: Configuring Network"

print_info "Setting hostname to $HOSTNAME..."
echo "$HOSTNAME" > /etc/hostname

# Create hosts file
cat > /etc/hosts << EOF
127.0.0.1      localhost
::1            localhost
127.0.1.1      $HOSTNAME
EOF
print_success "Network configuration complete"

# ===================================
# STEP 7: ROOT PASSWORD
# ===================================
print_step "STEP 7: Root Password"

print_info "Set a strong password for the root account"
echo ""
passwd

# ===================================
# STEP 8: PACMAN CONFIGURATION
# ===================================
print_step "STEP 8: Configuring Package Manager"

print_info "Enabling color output and multilib repository..."
sed -i 's/#Color/Color/' /etc/pacman.conf
sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf

print_info "Synchronizing package databases..."
if retry_command 3 "pacman -Syu --noconfirm"; then
    print_success "Package database synchronized"
else
    print_error "Failed to synchronize package database"
    print_warning "Continuing anyway, but you may have issues later"
fi

# ===================================
# STEP 9: GRUB INSTALLATION
# ===================================
print_step "STEP 9: Installing Bootloader (GRUB)"

# Verify microcode was installed in step 01
if [ "$MICROCODE_INSTALLED" == "yes" ]; then
    print_success "Microcode already installed (from base installation)"
elif pacman -Q intel-ucode &>/dev/null || pacman -Q amd-ucode &>/dev/null; then
    print_success "Microcode already installed"
else
    print_warning "Microcode not detected! It should have been installed in step 01"
    print_warning "GRUB may not load microcode updates properly"
fi

print_info "Installing GRUB bootloader..."
if [ "$BOOT_MODE" == "UEFI" ]; then
    if grub-install --verbose --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB; then
        print_success "GRUB installed successfully (UEFI mode)"
    else
        print_error "GRUB installation failed!"
        exit 1
    fi
else
    if grub-install --verbose --target=i386-pc "$GRUB_DISK"; then
        print_success "GRUB installed successfully (BIOS mode) to $GRUB_DISK"
    else
        print_error "GRUB installation failed!"
        exit 1
    fi
fi

print_info "Generating GRUB configuration..."
if grub-mkconfig -o /boot/grub/grub.cfg; then
    print_success "GRUB configuration generated"
    
    # Verify grub.cfg was created and has content
    if [ -s /boot/grub/grub.cfg ]; then
        print_success "GRUB configuration file verified"
    else
        print_error "GRUB configuration file is empty!"
        exit 1
    fi
else
    print_error "Failed to generate GRUB configuration!"
    exit 1
fi

# ===================================
# STEP 10: AUDIO SYSTEM CONFIGURATION
# ===================================
print_step "STEP 10: Audio System Configuration"

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
        else
            print_error "Failed to install PipeWire"
            exit 1
        fi
        ;;
    2)
        print_info "Installing PulseAudio..."
        if retry_command 3 "pacman -S --needed --noconfirm pulseaudio pulseaudio-alsa"; then
            print_success "PulseAudio installed"
        else
            print_error "Failed to install PulseAudio"
            exit 1
        fi
        ;;
    *)
        print_error "Invalid selection"
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
        print_error "Invalid selection"
        exit 1
        ;;
esac

# ===================================
# STEP 11: ENABLE SERVICES
# ===================================
print_step "STEP 11: Enabling System Services"

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
print_step "??? System Configuration Completed Successfully!"

# Mark progress
save_progress "02-system-configured"

echo ""
print_success "Configuration finished!"
echo ""
print_info "Next steps:"
echo "  ${CYAN}1.${NC} Exit the chroot environment:"
echo "     ${YELLOW}exit${NC}"
echo ""
echo "  ${CYAN}2.${NC} Unmount all partitions:"
echo "     ${YELLOW}umount -R /mnt${NC}"
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
