#!/bin/bash
# =============================================================================
# ALIE System Installation Script - Base System Deployment
# =============================================================================
#
# DESCRIPTION:
#   Performs the actual base Arch Linux system installation using pacstrap
#   Installs essential packages, generates fstab, and prepares for chroot configuration
#   Final step in the 3-phase installation sequence
#
# ARCHITECTURAL ROLE:
#   - Third and final script in the installation sequence (001 → 002 → 003)
#   - Executes pacstrap to install base system into mounted partitions
#   - Configures system files (fstab, editor configs) for the new installation
#   - Prepares system for chroot-based configuration and bootloader setup
#
# KEY RESPONSIBILITIES:
#   - Mirror optimization for faster package downloads
#   - Base system package installation via pacstrap
#   - Filesystem table generation with UUID-based mounting
#   - Text editor configuration (nano/vim) with enhanced features
#   - Installation configuration persistence
#   - Progress tracking and completion verification
#
# PACKAGE INSTALLATION:
#   - base: Core system packages (kernel, init, coreutils, etc.)
#   - linux-firmware: Hardware firmware for device support
#   - networkmanager: Network management and configuration
#   - Selected kernels, shells, and editors from previous steps
#   - Bootloader packages (grub, systemd-boot, or limine)
#   - Microcode packages for CPU-specific updates
#
# SYSTEM PREPARATION:
#   - NTP synchronization for accurate system time
#   - Partition validation and filesystem detection
#   - Space requirement verification before installation
#   - Error handling and retry logic for network issues
#
# CONFIGURATION OUTPUT:
#   - /mnt/etc/fstab: Filesystem mount configuration
#   - /mnt/etc/nanorc, /mnt/etc/vimrc: Editor configurations
#   - /mnt/root/.alie-install-config: Installation metadata
#
# DEPENDENCIES:
#   - Requires script 001 completion (mounted partitions)
#   - Optionally uses script 002 selections (shells/editors/kernels)
#   - Depends on shared-functions.sh for utilities
#   - Requires internet connectivity for package downloads
#
# CRITICAL SAFETY CHECKS:
#   - Validates live environment execution
#   - Confirms mounted root partition at /mnt
#   - Verifies sufficient disk space (minimum 2GB)
#   - Checks for existing installation progress
#
# USAGE SCENARIOS:
#   - Complete base system installation after partitioning
#   - Automated deployment with pre-configured selections
#   - Recovery installations with custom package sets
#   - Development system setup with specific tools
#
# WARNING: EXPERIMENTAL SCRIPT
# This script is provided AS-IS without warranties.
# Review the code before running and use at your risk.
# Requires 001-base-install.sh to be completed first.
# Optionally run 002-shell-editor-select.sh before this.
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# =============================================================================
# SCRIPT INITIALIZATION - Environment Setup and Validation
# =============================================================================

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

# Add signal handling for graceful interruption
setup_cleanup_trap

# Script header with installation overview
echo ""
print_step "*** ALIE System Installation"
echo ""
echo "This script installs the base Arch Linux system using pacstrap."
echo "It should be run AFTER disk partitioning and mounting is complete."
echo ""
echo "What this script does:"
echo "  - Optimize package mirrors"
echo "  - Install base system packages with pacstrap"
echo "  - Generate filesystem table (fstab)"
echo "  - Save installation configuration"
echo ""

# ===================================
# PREREQUISITES CHECK - Installation Readiness Validation
# ===================================
#
# PURPOSE:
#   Validates all prerequisites before attempting system installation
#   Prevents failures due to incomplete preparation or system state issues
#
# CRITICAL CHECKS:
#   - Live environment verification (must run from installation media)
#   - Root partition mount validation (required for pacstrap)
#   - Progress marker verification (ensures proper sequence)
#   - Configuration loading (uses settings from script 001)
#
# LIVE ENVIRONMENT DETECTION:
#   - Checks for /run/archiso (Arch ISO indicator)
#   - Verifies archiso kernel parameter
#   - Ensures we're not running on an installed system
#
# MOUNT VALIDATION:
#   - Confirms /mnt is a valid mount point
#   - Ensures target system is properly prepared
#   - Prevents installation into wrong location
#
# CONFIGURATION FALLBACK:
#   - Attempts to load saved configuration from script 001
#   - Falls back to auto-detection if config unavailable
#   - Detects mounted partitions and filesystem types
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
    print_info "Or manually mount your partitions and run this script again"
    exit 1
fi

# Check if previous step was completed
if ! is_step_completed "01-partitions-ready"; then
    smart_clear
    print_warning "001-base-install.sh progress marker not found"
    print_info "This script expects partitions to be ready"
    read -r -p "Continue anyway? (y/N): " CONTINUE_ANYWAY
    if [[ ! $CONTINUE_ANYWAY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Load saved configuration from 001 script
if load_system_config "/tmp/.alie-install-config"; then
    print_info "Using configuration from disk partitioning step (001)"
else
    print_warning "Configuration from 001 script not found"
    print_info "Detecting system configuration from mounted partitions..."
    
    # Fallback: detect basic configuration
    detect_system_info
    
    # Detect mounted partitions
    if mountpoint -q /mnt 2>/dev/null; then
        ROOT_PARTITION=$(findmnt -n -o SOURCE /mnt 2>/dev/null || echo "unknown")
        ROOT_FS=$(findmnt -n -o FSTYPE /mnt 2>/dev/null || echo "unknown")
    fi
    
    if mountpoint -q /mnt/boot 2>/dev/null; then
        EFI_PARTITION=$(findmnt -n -o SOURCE /mnt/boot 2>/dev/null || echo "")
    fi
    
    if mountpoint -q /mnt/home 2>/dev/null; then
        HOME_PARTITION=$(findmnt -n -o SOURCE /mnt/home 2>/dev/null || echo "")
    fi
    
    SWAP_PARTITION=$(swapon --show=NAME --noheadings 2>/dev/null | head -n1 || echo "")
    
    print_success "Auto-detected configuration from mounted filesystems"
fi

print_info "Current system configuration:"
echo "  - Boot mode: ${BOOT_MODE:-unknown}"
echo "  - Partition table: ${PARTITION_TABLE:-unknown}"
echo "  - Root filesystem: ${ROOT_FS:-unknown}"
echo "  - Root partition: ${ROOT_PARTITION:-unknown}"
[ -n "${EFI_PARTITION:-}" ] && echo "  - EFI partition: $EFI_PARTITION"
[ -n "${HOME_PARTITION:-}" ] && echo "  - Home partition: $HOME_PARTITION"
[ -n "${SWAP_PARTITION:-}" ] && echo "  - Swap partition: $SWAP_PARTITION"
echo "  - CPU vendor: ${CPU_VENDOR:-unknown}"
if [ -n "${MICROCODE_PKG:-}" ]; then
    echo "  - Microcode: $MICROCODE_PKG"
fi
echo "  - Mount point: /mnt"

# Pause to let user read configuration
read -r -p "Press Enter to continue with mirror optimization..."

# ===================================
# STEP 8: MIRROR OPTIMIZATION - Package Download Performance
# ===================================
#
# PURPOSE:
#   Optimizes pacman mirror list for faster and more reliable package downloads
#   Critical for large base system installations with many packages
#
# WHY MIRROR OPTIMIZATION MATTERS:
#   - pacstrap downloads hundreds of packages (base system ~200-300MB)
#   - Slow mirrors can cause timeouts and installation failures
#   - Geographic proximity affects download speeds significantly
#   - Mirror reliability prevents partial installation failures
#
# OPTIMIZATION STRATEGY:
#   - Uses reflector to automatically select fastest mirrors
#   - Filters for HTTPS-only mirrors (security)
#   - Sorts by download rate for optimal performance
#   - Limits to 20 mirrors to balance speed and reliability
#
# REFLECTOR CONFIGURATION:
#   - --latest 20: Select 20 most recently updated mirrors
#   - --protocol https: Only HTTPS mirrors for security
#   - --sort rate: Sort by download speed
#   - --save: Update /etc/pacman.d/mirrorlist
#
# FALLBACK HANDLING:
#   - Continues with default mirrorlist if reflector fails
#   - Uses retry_command for network resilience
#   - Shows top 5 mirrors for user verification
#
# SECURITY CONSIDERATIONS:
#   - HTTPS-only mirrors prevent man-in-the-middle attacks
#   - Mirror updates ensure latest package databases
# ===================================
print_step "STEP 8: Optimizing Package Mirrors"

print_info "Installing archlinux-keyring for package verification..."
if ! pacman -S --needed --noconfirm archlinux-keyring; then
    print_error "Failed to install archlinux-keyring"
    print_warning "Package verification may fail..."
else
    print_success "archlinux-keyring installed"
fi

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

# Pause before major installation step
read -r -p "Press Enter to continue with base system installation..."

# ===================================
# STEP 9: BASE SYSTEM INSTALLATION - Core Package Deployment
# ===================================
#
# PURPOSE:
#   Installs the base Arch Linux system using pacstrap
#   Deploys essential packages for a functional system
#
# CRITICAL NATURE:
#   - This is the main installation step that creates the new system
#   - Downloads and installs ~200 packages (base, kernel, drivers, etc.)
#   - Requires stable internet connection and sufficient disk space
#   - Point of no return - system becomes bootable after this step
#
# PACKAGE CATEGORIES:
#   - base: Core system (kernel, init, coreutils, filesystem tools)
#   - linux-firmware: Hardware firmware for device support
#   - networkmanager: Network configuration and management
#   - vim, nano: Text editors for system administration
#   - sudo: Privilege escalation for multi-user systems
#
# DYNAMIC PACKAGE SELECTION:
#   - Bootloader: grub, systemd-boot, or limine based on user choice
#   - Microcode: CPU-specific updates (intel-ucode, amd-ucode)
#   - EFI tools: efibootmgr for UEFI systems
#   - User selections: Shells, editors, kernels from script 002
#
# SPACE VALIDATION:
#   - Checks available space on /mnt (minimum 2GB recommended)
#   - Warns about low space conditions (<5GB)
#   - Prevents installation failures due to insufficient space
#
# ERROR HANDLING:
#   - Temporarily disables set -e for pacstrap error management
#   - Provides retry option on failure
#   - Captures and reports exit codes for debugging
#
# PACSTRAP OPTIONS:
#   - -K: Initialize pacman keyring (required for new installations)
#   - Target directory: /mnt (mounted root partition)
# ===================================
print_step "STEP 9: Installing Base System"

print_info "Installing essential packages..."
echo "This will take several minutes depending on your connection..."
echo ""

# Build package list using detected configuration
PACKAGES=(
    base
    linux-firmware
    networkmanager
    vim
    sudo
    nano
)

# Add selected bootloader
if [ "${BOOTLOADER:-grub}" = "systemd-boot" ]; then
    # systemd-boot comes with systemd, no separate package needed
    print_info "Using systemd-boot (included with systemd)"
elif [ "${BOOTLOADER:-grub}" = "limine" ]; then
    PACKAGES+=("limine")
    print_info "Adding Limine bootloader"
else
    # Default to GRUB
    PACKAGES+=("grub")
    print_info "Adding GRUB bootloader"
fi

# Add microcode if detected
if [ -n "${MICROCODE_PKG:-}" ]; then
    print_info "Adding microcode package: $MICROCODE_PKG"
    PACKAGES+=("$MICROCODE_PKG")
else
    print_info "No microcode package needed"
fi

# Add EFI tools for UEFI systems
if [ "$BOOT_MODE" = "UEFI" ]; then
    PACKAGES+=("efibootmgr")
    print_info "Adding UEFI boot tools"
fi

# Add selected shells and editors from 002-shell-editor-select.sh
if [ -f /tmp/.alie-shell-editor-config ]; then
    print_info "Loading shell and editor selection..."
    # shellcheck disable=SC1091
    source "/tmp/.alie-shell-editor-config"
    
    if [ -n "${EXTRA_SHELLS:-}" ]; then
        read -r -a _extra_shells <<< "$EXTRA_SHELLS"
        PACKAGES+=("${_extra_shells[@]}")
        print_info "Adding shells: ${_extra_shells[*]}"
    fi
    
    if [ -n "${EXTRA_EDITORS:-}" ]; then
        read -r -a _extra_editors <<< "$EXTRA_EDITORS"
        PACKAGES+=("${_extra_editors[@]}")
        print_info "Adding editors: ${_extra_editors[*]}"
    fi
    
    # Add selected kernels
    if [ -n "${SELECTED_KERNELS:-}" ]; then
        read -r -a _selected_kernels <<< "$SELECTED_KERNELS"
        PACKAGES+=("${_selected_kernels[@]}")
        print_info "Adding kernels: ${_selected_kernels[*]}"
    else
        # Default to linux if no kernels selected
        PACKAGES+=("linux")
        print_info "Adding default kernel: linux"
    fi
fi

# Check available space on /mnt (minimum 2GB recommended for base install)
AVAILABLE_SPACE_MB=$(df -BM /mnt | awk 'NR==2 {print $4}' | sed 's/M//')
print_info "Available space on /mnt: ${AVAILABLE_SPACE_MB} MB"

if [ "$AVAILABLE_SPACE_MB" -lt 2048 ]; then
    print_error "Insufficient space on /mnt! Need at least 2GB, have ${AVAILABLE_SPACE_MB}MB"
    print_error "Installation cannot proceed"
    exit 1
elif [ "$AVAILABLE_SPACE_MB" -lt 5120 ]; then
    smart_clear
    print_warning "Low disk space: ${AVAILABLE_SPACE_MB}MB. Installation may fail if packages are large."
    read -r -p "Continue anyway? (y/N): " CONTINUE_LOW_SPACE
    if [[ ! $CONTINUE_LOW_SPACE =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Use -K flag to initialize empty pacman keyring (recommended by wiki)
print_info "Running: pacstrap -K /mnt ${PACKAGES[*]}"
echo ""

# Disable set -e temporarily for pacstrap to handle errors gracefully
set +e
pacstrap -K /mnt "${PACKAGES[@]}"
PACSTRAP_EXIT_CODE=$?
set -e

if [ $PACSTRAP_EXIT_CODE -ne 0 ]; then
    smart_clear
    print_error "pacstrap failed with exit code $PACSTRAP_EXIT_CODE"
    print_info "This could be due to:"
    echo "  - Network connectivity issues"
    echo "  - Mirror problems"
    echo "  - Insufficient disk space"
    echo "  - Package signing errors"
    echo ""
    read -r -p "Retry pacstrap? (Y/n): " RETRY_PACSTRAP
    
    if [[ ! $RETRY_PACSTRAP =~ ^[Nn]$ ]]; then
        print_info "Retrying pacstrap..."
        set +e
        pacstrap -K /mnt "${PACKAGES[@]}"
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
# STEP 9b: CONFIGURE EDITORS (if selected)
# ===================================
if [ "${CONFIGURE_NANO:-false}" = "true" ] || [ "${CONFIGURE_VIM:-false}" = "true" ]; then
    print_step "STEP 9b: Configuring Text Editors"
    
    # Get configs directory
    CONFIGS_DIR="$(dirname "$SCRIPT_DIR")/configs"
    
    # Configure Nano
    if [ "${CONFIGURE_NANO:-false}" = "true" ]; then
        print_info "Setting up nano with syntax highlighting..."
        
        mkdir -p /mnt/etc
        if [ -f "$CONFIGS_DIR/editor/nanorc" ]; then
            cp "$CONFIGS_DIR/editor/nanorc" /mnt/etc/nanorc
            print_success "Deployed nano configuration from: configs/editor/nanorc"
        else
            print_warning "Nano config not found, using inline configuration"
            cat > /mnt/etc/nanorc << 'EOF'
# ALIE - Nano Configuration
include "/usr/share/nano/*.nanorc"
include "/usr/share/nano-syntax-highlighting/*.nanorc"
set linenumbers
set softwrap
set tabsize 4
set tabstospaces
set autoindent
set mouse
EOF
        fi
        
        # Copy to user skeleton
        mkdir -p /mnt/etc/skel
        cp /mnt/etc/nanorc /mnt/etc/skel/.nanorc
        
        print_success "Nano configured with syntax highlighting"
    fi
    
    # Configure Vim
    if [ "${CONFIGURE_VIM:-false}" = "true" ]; then
        print_info "Setting up vim with enhanced configuration..."
        
        mkdir -p /mnt/etc
        if [ -f "$CONFIGS_DIR/editor/vimrc" ]; then
            cp "$CONFIGS_DIR/editor/vimrc" /mnt/etc/vimrc
            print_success "Deployed vim configuration from: configs/editor/vimrc"
        else
            print_warning "Vim config not found, using inline configuration"
            cat > /mnt/etc/vimrc << 'EOF'
" ALIE - Vim Configuration
set nocompatible              " Disable vi compatibility
syntax on                     " Enable syntax highlighting
filetype plugin indent on     " Enable filetype detection

set number                    " Show line numbers
set relativenumber            " Relative line numbers
set ruler                     " Show cursor position
set showcmd                   " Show command in bottom bar
set wildmenu                  " Visual autocomplete for command menu
set showmatch                 " Highlight matching brackets
set incsearch                 " Search as characters are entered
set hlsearch                  " Highlight search matches
set ignorecase                " Case insensitive search
set smartcase                 " Case sensitive when uppercase present

set tabstop=4                 " Visual spaces per TAB
set softtabstop=4             " Spaces per TAB when editing
set shiftwidth=4              " Spaces for autoindent
set expandtab                 " Tabs are spaces
set autoindent                " Auto indent
set smartindent               " Smart indent

set mouse=a                   " Enable mouse support
set encoding=utf-8            " UTF-8 encoding
set backspace=indent,eol,start " Backspace behavior

" Color scheme
set background=dark
colorscheme desert

" Better split navigation
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
EOF
        fi
        
        # Copy to user skeleton
        mkdir -p /mnt/etc/skel
        cp /mnt/etc/vimrc /mnt/etc/skel/.vimrc
        
        print_success "Vim configured with enhanced settings"
    fi
fi

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
print_step "*** Base Installation Completed Successfully!"

# Mark progress
save_progress "02-base-installed"

echo ""
print_success "System installation finished!"
echo ""

# Pause to let user read completion message
read -r -p "Press Enter to continue..."

# ===================================
# SYSTEM CONFIGURATION CHOICE
# ===================================
print_step "STEP 12: System Configuration Method"

echo ""
print_info "Choose how to continue with system configuration:"
echo ""
echo "  ${CYAN}1)${NC} Automatic configuration (recommended)"
echo "     - Automatically enter chroot environment"
echo "     - Configure timezone, locale, hostname, bootloader"
echo "     - Return to live environment when complete"
echo ""
echo "  ${CYAN}2)${NC} Manual configuration"
echo "     - Show instructions for manual chroot entry"
echo "     - You control each configuration step"
echo "     - More control but requires manual commands"
echo ""

smart_clear
read -r -p "Select configuration method [1-2]: " CONFIG_METHOD

case "$CONFIG_METHOD" in
    1)
        print_info "Selected: Automatic configuration"
        echo ""
        
        print_info "Copying ALIE scripts to the new system..."
        if cp -r "$(dirname "$SCRIPT_DIR")" /mnt/root/alie-scripts; then
            print_success "Scripts copied successfully"
        else
            print_error "Failed to copy scripts"
            print_warning "Falling back to manual configuration"
            CONFIG_METHOD="2"
        fi
        
        if [ "$CONFIG_METHOD" = "1" ]; then
            print_info "Entering chroot environment to continue configuration..."
            echo "The system will automatically configure timezone, locale, hostname, and bootloader."
            echo ""
            
            # Execute the configuration script inside chroot
            if arch-chroot /mnt bash /root/alie-scripts/install/101-configure-system.sh; then
                print_success "System configuration completed successfully!"
                echo ""
                print_info "Final steps:"
                echo "  ${CYAN}1.${NC} Unmount all partitions:"
                echo "     ${YELLOW}umount -R /mnt${NC}"
                echo ""
                echo "  ${CYAN}2.${NC} Sync filesystem:"
                echo "     ${YELLOW}sync${NC}"
                echo ""
                echo "  ${CYAN}3.${NC} Reboot the system:"
                echo "     ${YELLOW}reboot${NC}"
                echo ""
                print_warning "Remember to remove the installation media before rebooting!"
            else
                print_error "System configuration failed!"
                print_warning "Falling back to manual configuration instructions"
                CONFIG_METHOD="2"
            fi
        fi
        ;;
        
    2)
        print_info "Selected: Manual configuration"
        ;;
        
    *)
        print_error "Invalid selection, defaulting to manual configuration"
        CONFIG_METHOD="2"
        ;;
esac

if [ "$CONFIG_METHOD" = "2" ]; then
    print_info "Manual configuration selected."
    echo ""
    print_info "Next steps:"
    echo "  ${CYAN}1.${NC} Copy the ALIE scripts to the new system:"
    echo "     ${YELLOW}cp -r $(dirname "$SCRIPT_DIR") /mnt/root/alie-scripts${NC}"
    echo ""
    echo "  ${CYAN}2.${NC} Enter the new system:"
    echo "     ${YELLOW}arch-chroot /mnt${NC}"
    echo ""
    echo "  ${CYAN}3.${NC} Run the configuration script:"
    echo "     ${YELLOW}bash /root/alie-scripts/install/101-configure-system.sh${NC}"
    echo ""
    echo "  ${CYAN}4.${NC} After configuration completes, exit chroot:"
    echo "     ${YELLOW}exit${NC}"
    echo ""
    echo "  ${CYAN}5.${NC} Unmount all partitions:"
    echo "     ${YELLOW}umount -R /mnt${NC}"
    echo ""
    echo "  ${CYAN}6.${NC} Sync filesystem:"
    echo "     ${YELLOW}sync${NC}"
    echo ""
    echo "  ${CYAN}7.${NC} Reboot the system:"
    echo "     ${YELLOW}reboot${NC}"
    echo ""
    print_warning "Remember to remove the installation media before rebooting!"
fi

echo ""