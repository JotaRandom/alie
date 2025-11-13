#!/bin/bash
# ALIE Packages Installation Script
# This script installs all Linux Mint packages and applications
# Run as regular user (not root)
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

source "$LIB_DIR/shared-functions.sh"

# Trap cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Package installation failed!"
    fi
}
trap cleanup EXIT

# Main script start
show_alie_banner
show_warning_banner

print_info "This script will install:"
echo "  ??? Fonts and themes"
echo "  ??? System utilities and tools"
echo "  ??? Graphics and multimedia applications"
echo "  ??? Internet and office applications"
echo "  ??? Filesystem and compression support"
echo "  ??? Optional: Laptop optimizations"
echo ""
print_warning "This process may take 30-60 minutes depending on your internet speed"
read -p "Press Enter to continue or Ctrl+C to exit..."

# Validate environment
print_step "STEP 1: Environment Validation"

# Verify NOT running as root
require_non_root

# Verify we're on Arch Linux
verify_arch_linux

# Verify NOT in chroot
verify_not_chroot

# Verify internet connectivity
verify_internet

# Check available disk space
print_info "Checking available disk space..."
AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 10 ]; then
    print_warning "Low disk space detected: ${AVAILABLE_SPACE}GB available"
    print_info "Recommended: At least 10GB free space for package installation"
    read -p "Continue anyway? (y/N): " CONTINUE_LOW_SPACE
    CONTINUE_LOW_SPACE="${CONTINUE_LOW_SPACE,,}"
    CONTINUE_LOW_SPACE="${CONTINUE_LOW_SPACE:0:1}"
    if [[ "$CONTINUE_LOW_SPACE" != "y" ]]; then
        print_error "Installation cancelled by user"
        exit 1
    fi
else
    print_success "Sufficient disk space available: ${AVAILABLE_SPACE}GB"
fi

# Verify yay is installed
print_info "Checking for YAY AUR helper..."
if ! command -v yay &>/dev/null; then
    print_error "YAY is not installed"
    print_info "Please run 211-install-yay.sh first"
    exit 1
fi
print_success "YAY is available"

# Validate desktop user and ensure running as that user
require_desktop_user

print_success "All prerequisites met"

# Installation tracking
TOTAL_STEPS=19
CURRENT_STEP=0
FAILED_STEPS=()

# Helper function to install packages with error handling
install_package_group() {
    local category="$1"
    shift
    local packages=("$@")
    
    ((CURRENT_STEP++))
    echo ""
    print_step "[$CURRENT_STEP/$TOTAL_STEPS] Installing $category"
    
    if yay -S --needed --noconfirm "${packages[@]}"; then
        print_success "$category installed successfully"
        return 0
    else
        print_error "$category installation failed"
        FAILED_STEPS+=("$category")
        return 1
    fi
}

# Fonts
install_package_group "Fonts" \
    noto-fonts noto-fonts-emoji noto-fonts-cjk noto-fonts-extra ttf-ubuntu-font-family

# Themes and icons
install_package_group "Themes and Icons" \
    mint-themes mint-l-themes mint-y-icons mint-x-icons mint-l-icons bibata-cursor-theme xapp-symbolic-icons

# LightDM settings
install_package_group "LightDM Settings" \
    lightdm-settings

# Wallpapers (optional - large download)
((CURRENT_STEP++))
echo ""
print_step "[$CURRENT_STEP/$TOTAL_STEPS] Linux Mint Wallpapers (Optional)"
read -p "Install Linux Mint wallpapers? (70+ MiB each) (y/N): " INSTALL_WALLS
# Sanitize input
INSTALL_WALLS="${INSTALL_WALLS,,}"  # lowercase
INSTALL_WALLS="${INSTALL_WALLS:0:1}"  # first char only
if [[ "$INSTALL_WALLS" == "y" ]]; then
    if yay -S --needed --noconfirm mint-backgrounds mint-artwork; then
        print_success "Wallpapers installed"
    else
        print_error "Wallpapers installation failed"
        FAILED_STEPS+=("Wallpapers")
    fi
else
    print_info "Skipping wallpapers"
fi

# Printer support
((CURRENT_STEP++))
echo ""
print_step "[$CURRENT_STEP/$TOTAL_STEPS] Installing Printer Support"
if yay -S --needed --noconfirm cups system-config-printer; then
    print_info "Enabling CUPS service..."
    sudo systemctl enable --now cups
    print_success "Printer support installed"
else
    print_error "Printer support installation failed"
    FAILED_STEPS+=("Printer Support")
fi

# Audio (PipeWire)
install_package_group "PipeWire Audio" \
    pipewire-audio wireplumber pipewire-alsa pipewire-pulse pipewire-jack pavucontrol

# Bluetooth
((CURRENT_STEP++))
echo ""
print_step "[$CURRENT_STEP/$TOTAL_STEPS] Installing Bluetooth Support"
if yay -S --needed --noconfirm bluez bluez-utils; then
    print_info "Enabling Bluetooth service..."
    sudo systemctl enable --now bluetooth
    print_success "Bluetooth support installed"
else
    print_error "Bluetooth support installation failed"
    FAILED_STEPS+=("Bluetooth")
fi

# System tools and accessories
install_package_group "System Tools" \
    file-roller yelp warpinator mintstick xed gnome-screenshot redshift seahorse onboard \
    sticky xviewer gnome-font-viewer bulky xreader gnome-disk-utility gucharmap gnome-calculator

# Graphics applications
install_package_group "Graphics Applications" \
    simple-scan pix drawing

# Internet applications
install_package_group "Internet Applications" \
    firefox webapp-manager thunderbird transmission-gtk

# Office suite
install_package_group "Office Suite" \
    gnome-calendar libreoffice-fresh

# Development tools
install_package_group "Development Tools" \
    python

# Multimedia
install_package_group "Multimedia Applications" \
    rhythmbox celluloid

# Administration tools
install_package_group "Administration Tools" \
    timeshift gnome-logs baobab

# Configuration tools
install_package_group "Configuration Tools" \
    nemo nemo-fileroller nemo-image-converter nemo-preview nemo-share blueberry

# Filesystem support
install_package_group "Filesystem Support" \
    ntfs-3g exfatprogs dosfstools btrfs-progs xfsprogs f2fs-tools

# Compression tools
install_package_group "Compression Tools" \
    unrar unace lrzip

# Additional integrations
install_package_group "Additional Integrations" \
    xdg-desktop-portal-gtk xdg-utils

# Laptop optimizations (optional)
((CURRENT_STEP++))
echo ""
print_step "[$CURRENT_STEP/$TOTAL_STEPS] Laptop Optimizations (Optional)"
read -p "Is this a laptop? Install laptop optimizations? (y/N): " IS_LAPTOP
# Sanitize input
IS_LAPTOP="${IS_LAPTOP,,}"  # lowercase
IS_LAPTOP="${IS_LAPTOP:0:1}"  # first char only

if [[ "$IS_LAPTOP" == "y" ]]; then
    echo ""
    print_info "Installing laptop optimizations..."
    
    # TLP power management
    read -p "Install TLP for power management? (recommended) (Y/n): " INSTALL_TLP
    INSTALL_TLP="${INSTALL_TLP,,}"
    INSTALL_TLP="${INSTALL_TLP:0:1}"
    
    if [[ "$INSTALL_TLP" != "n" ]]; then
        print_info "Installing TLP..."
        if yay -S --needed --noconfirm tlp tlp-rdw; then
            print_info "Enabling TLP service..."
            sudo systemctl enable --now tlp
            print_success "TLP installed and enabled"
        else
            print_error "TLP installation failed"
            FAILED_STEPS+=("TLP")
        fi
    fi
    
    # Laptop tools
    print_info "Installing laptop tools..."
    if yay -S --needed --noconfirm linux-tools lm_sensors brightnessctl libinput-gestures xf86-input-libinput; then
        print_success "Laptop tools installed"
    else
        print_error "Laptop tools installation failed"
        FAILED_STEPS+=("Laptop Tools")
    fi
else
    print_info "Skipping laptop optimizations"
fi

# Save progress
save_progress "05-packages-installed"

# Final summary
echo ""
echo "?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????"
if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    print_success "All packages installed successfully!"
else
    print_warning "Installation completed with some errors"
    echo ""
    print_error "Failed to install the following categories:"
    for failed in "${FAILED_STEPS[@]}"; do
        echo "  ${RED}???${NC} $failed"
    done
    echo ""
    print_info "You can try to install failed packages manually with:"
    echo "  ${YELLOW}yay -S <package-name>${NC}"
fi
echo "?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????"
echo ""
print_info "Recommendations:"
echo "  ${CYAN}1.${NC} Reboot the system to ensure everything is loaded"
echo "  ${CYAN}2.${NC} Configure Timeshift for system backups"
echo "  ${CYAN}3.${NC} Customize desktop themes and appearance"
if [[ "$IS_LAPTOP" == "y" ]]; then
    echo "  ${CYAN}4.${NC} Run ${YELLOW}'sudo sensors-detect'${NC} to configure sensor monitoring"
fi
echo ""
