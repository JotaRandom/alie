#!/bin/bash
# ALIE YAY Installation Script
# This script should be run as the regular user (not root)
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
YAY_BUILD_DIR=""
cleanup() {
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        print_error "YAY installation failed!"
        
        # Clean up build directory if it exists
        if [ -n "$YAY_BUILD_DIR" ] && [ -d "$YAY_BUILD_DIR" ]; then
            print_info "Cleaning up temporary files..."
            rm -rf "$YAY_BUILD_DIR" 2>/dev/null || true
        fi
    fi
}
trap cleanup EXIT

# Main script start
show_alie_banner
show_warning_banner

print_info "This script will install:"
echo "  ??? YAY AUR Helper (from source)"
echo "  ??? Update package database"
echo ""
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

# Verify base-devel and git are installed
print_info "Checking required packages..."
if ! pacman -Qq base-devel &>/dev/null; then
    print_error "base-devel is not installed"
    print_info "Please install it first: sudo pacman -S --needed base-devel"
    exit 1
fi

if ! command -v git &>/dev/null; then
    print_error "git is not installed"
    print_info "Please install it first: sudo pacman -S git"
    exit 1
fi

print_success "All prerequisites met"

# Validate desktop user and ensure running as that user
require_desktop_user

# Check if yay is already installed
print_step "STEP 2: YAY Installation Check"
if command -v yay &>/dev/null; then
    print_success "YAY is already installed"
    print_info "Updating package database..."
    yay -Syy
    echo ""
    print_success "YAY is ready to use!"
    save_progress "04-yay-installed"
    exit 0
fi

# Install yay from AUR
print_step "STEP 3: Building YAY from Source"

# Use a dedicated build directory in user's home
BUILD_BASE="$HOME/.cache/alie-build"
YAY_BUILD_DIR="$BUILD_BASE/yay"

print_info "Setting up build directory..."
mkdir -p "$BUILD_BASE"

# Remove old yay directory if exists
if [ -d "$YAY_BUILD_DIR" ]; then
    print_info "Removing old yay directory..."
    rm -rf "$YAY_BUILD_DIR"
fi

print_info "Cloning yay repository from AUR..."
if ! git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR"; then
    print_error "Failed to clone yay repository"
    print_info "Please check your internet connection and try again"
    exit 1
fi

# Verify clone was successful
if [ ! -d "$YAY_BUILD_DIR" ] || [ ! -f "$YAY_BUILD_DIR/PKGBUILD" ]; then
    print_error "YAY repository clone incomplete or corrupted"
    exit 1
fi

print_success "Repository cloned successfully"

print_info "Building and installing yay..."
print_warning "This may take a few minutes..."

# Build and install in the yay directory
if ! (cd "$YAY_BUILD_DIR" && makepkg -si --noconfirm); then
    print_error "Failed to build or install yay"
    print_info "Check the output above for errors"
    exit 1
fi

# Verify yay was installed
if ! command -v yay &>/dev/null; then
    print_error "YAY installation failed - command not found after install"
    exit 1
fi

print_success "YAY built and installed successfully"

# Clean up build directory
print_info "Cleaning up build files..."
rm -rf "$YAY_BUILD_DIR"
YAY_BUILD_DIR=""  # Clear variable so cleanup doesn't try again

# Update package database
print_step "STEP 4: Updating Package Database"
print_info "Syncing package databases..."
yay -Syy

# Save progress
save_progress "04-yay-installed"

echo ""
print_success "YAY installation completed!"
echo ""
print_info "YAY is now ready to install AUR packages"
print_info "Next step:"
echo "  ${CYAN}???${NC} Run ${YELLOW}212-install-packages.sh${NC} to install all Linux Mint packages"
echo ""
