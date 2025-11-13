#!/bin/bash
# ALIE System Installation Script
# This script installs the base system using pacstrap after partitioning is complete
#
# ⚠️ WARNING: EXPERIMENTAL SCRIPT  
# This script is provided AS-IS without warranties.
# Review the code before running and use at your own risk.
# Requires 001-base-install.sh to be completed first.

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

# Script header
echo ""
print_step "🚀 ALIE System Installation"
echo ""
echo "This script installs the base Arch Linux system using pacstrap."
echo "It should be run AFTER disk partitioning and mounting is complete."
echo ""
echo "What this script does:"
echo "  🔄 Optimize package mirrors"  
echo "  📦 Install base system packages with pacstrap"
echo "  📋 Generate filesystem table (fstab)"
echo "  💾 Save installation configuration"
echo ""

# ===================================
# PREREQUISITES CHECK
# ===================================
print_step "Prerequisites Check"

# Check if running from live environment
if ! grep -q "archiso" /proc/cmdline 2>/dev/null; then
    print_error "This script should be run from the Arch Linux installation media"
    exit 1
fi

# Check if root partition is mounted
if ! mountpoint -q /mnt 2>/dev/null; then
    print_error "Root partition not mounted at /mnt"
    print_info "Please run 001-base-install.sh first to partition and mount the system"
    exit 1
fi

# Check if previous step was completed
if ! check_progress "01-partitions-ready"; then
    print_warning "001-base-install.sh progress marker not found"
    print_info "This script expects partitions to be ready"
    read -p "Continue anyway? (y/N): " CONTINUE_ANYWAY
    if [[ ! $CONTINUE_ANYWAY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Load saved configuration from 001 script
if load_system_config "/tmp/.alie-install-config"; then
    print_info "Using configuration from disk partitioning step"
else
    print_warning "Configuration from 001 script not found"
    print_info "Performing automatic system detection..."
    
    # Fallback: detect basic configuration
    detect_system_info
    
    print_info "Auto-detected configuration - please verify:"
fi

print_info "Current system configuration:"
echo "  • Boot mode: ${BOOT_MODE:-unknown}"
echo "  • Partition table: ${PARTITION_TABLE:-unknown}" 
echo "  • Root filesystem: ${ROOT_FS:-unknown}"
echo "  • Root partition: ${ROOT_PARTITION:-unknown}"
echo "  • CPU vendor: ${CPU_VENDOR:-unknown}"
if [ -n "${MICROCODE_PKG:-}" ]; then
    echo "  • Microcode: $MICROCODE_PKG"
fi
echo "  • Mount point: /mnt"

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

# Build package list using detected configuration
PACKAGES="base linux linux-firmware networkmanager grub vim sudo nano"

# Add microcode if detected
if [ -n "${MICROCODE_PKG:-}" ]; then
    print_info "Adding microcode package: $MICROCODE_PKG"
    PACKAGES="$PACKAGES $MICROCODE_PKG"
else
    print_info "No microcode package needed"
fi

# Add EFI tools for UEFI systems
if [ "$BOOT_MODE" = "UEFI" ]; then
    PACKAGES="$PACKAGES efibootmgr"
    print_info "Adding UEFI boot tools"
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
    echo "  • Network connectivity issues"
    echo "  • Mirror problems"
    echo "  • Insufficient disk space"
    echo "  • Package signing errors"
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

# Update configuration with installation completion
MICROCODE_INSTALLED="${MICROCODE_PKG:+yes}"
MICROCODE_INSTALLED="${MICROCODE_INSTALLED:-no}"

# Save comprehensive configuration to the new system
save_system_config "/mnt/root/.alie-install-config"

# Also save to temporary location for potential use by other scripts
save_system_config "/tmp/.alie-install-config"

# ===================================
# INSTALLATION COMPLETE
# ===================================
echo ""
print_step "✅ Base Installation Completed Successfully!"

# Mark progress
save_progress "02-base-installed"

echo ""
print_success "System installation finished!"
echo ""
print_info "Next steps:"
echo "  ${CYAN}1.${NC} Copy the ALIE scripts to the new system:"
echo "     ${YELLOW}cp -r $(dirname "$SCRIPT_DIR") /mnt/root/alie-scripts${NC}"
echo ""
echo "  ${CYAN}2.${NC} Enter the new system:"
echo "     ${YELLOW}arch-chroot /mnt${NC}"
echo ""
echo "  ${CYAN}3.${NC} Run the installer again (auto-detects chroot):"
echo "     ${YELLOW}bash /root/alie-scripts/alie.sh${NC}"
echo ""
print_warning "Don't reboot yet! Continue with system configuration."
echo ""