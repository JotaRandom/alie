#!/bin/bash
# =============================================================================
# ALIE Shell and Editor Selection Script - User Environment Configuration
# =============================================================================
#
# DESCRIPTION:
#   Allows users to select alternative shells and text editors beyond the base installation
#   Provides configuration options for nano and vim to enhance the user experience
#   Optional step that can be skipped for minimal installations
#
# ARCHITECTURAL ROLE:
#   - Second script in the 3-phase installation sequence (001 -> 002 -> 003)
#   - Enhances user experience with preferred tools and configurations
#   - Configures editors with syntax highlighting and modern features
#   - Prepares configuration for the base system installation
#
# KEY RESPONSIBILITIES:
#   - Interactive selection of alternative shells (zsh, fish, etc.)
#   - Multiple kernel selection for testing or specific use cases
#   - Text editor configuration with enhanced features
#   - Configuration persistence for script 003
#   - Validation of user selections and dependency checking
#
# SHELL OPTIONS:
#   - zsh: Powerful shell with extensive customization capabilities
#   - fish: User-friendly shell with modern features and syntax highlighting
#   - dash: Lightweight POSIX-compliant shell for minimal systems
#   - tcsh: Enhanced C-shell with advanced features
#   - ksh: Korn shell compatible with POSIX standards
#   - nushell: Modern Rust-based shell with structured data support
#
# KERNEL OPTIONS:
#   - linux: Standard stable kernel (recommended for most users)
#   - linux-zen: Desktop-optimized with performance patches
#   - linux-hardened: Security-focused with additional protections
#   - linux-lts: Long-term support kernel with extended maintenance
#
# EDITOR CONFIGURATION:
#   - nano: Enhanced with syntax highlighting package
#   - vim: Configured with modern settings and plugins support
#   - Additional editors: neovim, emacs, micro, helix
#
# CONFIGURATION OUTPUT:
#   - /tmp/.alie-shell-editor-config: Shell and editor selections
#   - /mnt/root/.alie-install-info: Persistent configuration data
#
# DEPENDENCIES:
#   - Requires script 001 to be completed (partitions mounted)
#   - Uses shared-functions.sh for common utilities
#   - Depends on config-functions.sh for configuration management
#
# USAGE SCENARIOS:
#   - Enhanced desktop installations with preferred tools
#   - Development environments requiring specific shells/editors
#   - Multi-user systems with diverse user preferences
#   - Testing different kernels or shell environments
#
# WARNING: EXPERIMENTAL SCRIPT
# This script is provided AS-IS without warranties.
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# =============================================================================
# SCRIPT INITIALIZATION - Environment Setup and Dependencies
# =============================================================================

# Determine script directory and set up paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Load shared functions library
if [ ! -f "$LIB_DIR/shared-functions.sh" ]; then
    echo "ERROR: shared-functions.sh not found at $LIB_DIR/shared-functions.sh"
    exit 1
fi
# shellcheck source=../lib/shared-functions.sh
# shellcheck disable=SC1091
source "$LIB_DIR/shared-functions.sh"

# Load configuration functions for data persistence
if [ ! -f "$LIB_DIR/config-functions.sh" ]; then
    echo "ERROR: config-functions.sh not found"
    exit 1
fi
# shellcheck source=../lib/config-functions.sh
# shellcheck disable=SC1091
source "$LIB_DIR/config-functions.sh"

# Script metadata and branding
SCRIPT_NAME="Shell and Editor Selection"
SCRIPT_DESC="Select alternative shells and configure text editors for installation"

print_section_header "$SCRIPT_NAME" "$SCRIPT_DESC"

# Verify root privileges (required for system configuration)
require_root

# Initialize selection arrays
SELECTED_SHELLS=()   # Array of selected shell packages
SELECTED_EDITORS=()  # Array of selected editor packages
SELECTED_KERNELS=()  # Array of selected kernel packages

# ===================================
# SHELL SELECTION - Alternative Shell Installation
# ===================================
#
# PURPOSE:
#   Allows users to install alternative shells beyond the default bash
#   Provides choice between different shell environments and features
#
# WHY THIS MATTERS:
#   - User preference for shell environment affects daily usage
#   - Different shells offer different features and scripting capabilities
#   - Some users require specific shells for work or development
#
# AVAILABLE SHELLS:
#   - zsh: Powerful shell with extensive customization (Oh My Zsh ecosystem)
#   - fish: User-friendly with syntax highlighting and autosuggestions
#   - dash: Lightweight POSIX shell, fast for scripting
#   - tcsh: Enhanced C-shell with advanced features
#   - ksh: Korn shell, POSIX compliant with enterprise features
#   - nushell: Modern shell with structured data and Rust performance
#
# SELECTION METHOD:
#   - Space-separated input allows multiple selections
#   - Input validation prevents invalid choices
#   - Empty input defaults to bash-only installation
#
# PACKAGE MAPPING:
#   - User selections are mapped to actual package names
#   - Package names match Arch Linux repository naming conventions
# ===================================
smart_clear
show_alie_banner
print_step "002: STEP 1: Shell Selection"

print_info "Available shells in official repositories:"
echo ""
echo "Default:"
echo "  - bash - Bourne Again SHell (already included in base)"
echo ""
echo "Additional shells:"
echo "  1) zsh - Z Shell (powerful, customizable)"
echo "  2) fish - Friendly Interactive SHell (user-friendly, modern)"
echo "  3) dash - Debian Almquist SHell (lightweight, POSIX)"
echo "  4) tcsh - TENEX C Shell (C-like syntax)"
echo "  5) ksh - Korn Shell (compatible with sh)"
echo "  6) nushell - Modern shell written in Rust (structured data)"
echo ""
echo "  0) None - stick with bash only"
echo ""

read -r -a shell_choices -p "Select shells to install (space-separated, e.g., '1 2', or 0 for none): "

if [ "${#shell_choices[@]}" -gt 0 ] && [ "${shell_choices[0]}" != "0" ]; then
    for choice in "${shell_choices[@]}"; do
        case $choice in
            1)
                SELECTED_SHELLS+=("zsh")
                print_success "Added: zsh"
                ;;
            2)
                SELECTED_SHELLS+=("fish")
                print_success "Added: fish"
                ;;
            3)
                SELECTED_SHELLS+=("dash")
                print_success "Added: dash"
                ;;
            4)
                SELECTED_SHELLS+=("tcsh")
                print_success "Added: tcsh"
                ;;
            5)
                SELECTED_SHELLS+=("ksh")
                print_success "Added: ksh"
                ;;
            6)
                SELECTED_SHELLS+=("nushell")
                print_success "Added: nushell"
                ;;
            *)
                print_warning "Invalid choice: $choice (skipped)"
                ;;
        esac
    done
fi

# ===================================
# KERNEL SELECTION - Multiple Kernel Support
# ===================================
#
# PURPOSE:
#   Allows installation of multiple Linux kernels for testing or specific requirements
#   Enables kernel switching and fallback options
#
# WHY MULTIPLE KERNELS MATTER:
#   - Testing new kernel features without risking system stability
#   - Hardware-specific kernel requirements (e.g., hardened for security)
#   - LTS kernels for long-term stability vs. latest features
#   - Desktop optimization vs. server stability trade-offs
#
# AVAILABLE KERNELS:
#   - linux: Standard kernel, good balance of features and stability
#   - linux-zen: Optimized for desktop use with interactivity patches
#   - linux-hardened: Security-focused with additional kernel protections
#   - linux-lts: Long-term support, receives updates for years
#
# KERNEL FEATURES:
#   - All include linux-firmware for hardware support
#   - Headers available separately for development
#   - Can be selected via bootloader (GRUB, systemd-boot, etc.)
#
# VALIDATION:
#   - Ensures at least one kernel is selected
#   - Prevents empty kernel arrays that would break installation
#   - Maps user choices to actual package names
# ===================================
smart_clear
show_alie_banner
print_step "002: STEP 2: Kernel Selection"

print_info "Select the Linux kernels to install:"
echo ""
echo "Available kernels:"
echo "  1) linux (default) - Standard Linux kernel (recommended for most users)"
echo "  2) linux-zen - Optimized for desktop use with patches for responsiveness"
echo "  3) linux-hardened - Security-focused with additional hardening patches"
echo "  4) linux-lts - Long Term Support kernel (stable, receives updates longer)"
echo ""
echo "Note: linux-firmware is always included regardless of kernel choice."
echo "You can select multiple kernels (e.g., '1 4' for linux and linux-lts)."
echo ""

read -r -a kernel_choices -p "Choose kernels [1-4] (space-separated, default: 1): "

if [ "${#kernel_choices[@]}" -eq 0 ]; then
    kernel_choices=(1)  # Default to linux
fi

for choice in "${kernel_choices[@]}"; do
    case $choice in
        1)
            SELECTED_KERNELS+=("linux")
            print_success "Added: linux (standard kernel)"
            ;;
        2)
            SELECTED_KERNELS+=("linux-zen")
            print_success "Added: linux-zen (desktop optimized)"
            ;;
        3)
            SELECTED_KERNELS+=("linux-hardened")
            print_success "Added: linux-hardened (security focused)"
            ;;
        4)
            SELECTED_KERNELS+=("linux-lts")
            print_success "Added: linux-lts (long term support)"
            ;;
        *)
            print_warning "Invalid choice: $choice (skipped)"
            ;;
    esac
done

# Ensure at least one kernel is selected
if [ ${#SELECTED_KERNELS[@]} -eq 0 ]; then
    SELECTED_KERNELS=("linux")
    print_warning "No valid kernels selected, using default: linux"
fi

echo ""

# ===================================
# EDITOR SELECTION
# ===================================
smart_clear
show_alie_banner
print_step "002: STEP 3: Text Editor Configuration"

print_info "Base editors (nano and vim) are always installed."
echo ""

# Nano configuration
echo "Configure nano with syntax highlighting?"
echo "  1) Yes - install nano-syntax-highlighting package"
echo "  2) No - use default nano configuration"
echo ""
read -r -p "Choice [1-2] (default: 1): " nano_choice
nano_choice=${nano_choice:-1}

if [ "$nano_choice" = "1" ]; then
    SELECTED_EDITORS+=("nano-syntax-highlighting")
    print_success "Will configure nano with syntax highlighting"
    CONFIGURE_NANO=true
else
    print_info "Nano will use default configuration"
    CONFIGURE_NANO=false
fi

echo ""

# Vim configuration
echo "Configure vim with enhanced settings?"
echo "  1) Yes - install vim with recommended plugins support"
echo "  2) No - use default vim configuration"
echo ""
read -r -p "Choice [1-2] (default: 1): " vim_choice
vim_choice=${vim_choice:-1}

if [ "$vim_choice" = "1" ]; then
    print_success "Will configure vim with enhanced settings"
    CONFIGURE_VIM=true
else
    print_info "Vim will use default configuration"
    CONFIGURE_VIM=false
fi

echo ""

# Additional editors
print_info "Additional text editors (optional):"
echo ""
echo "  1) neovim - Modern Vim fork (recommended)"
echo "  2) emacs - Extensible, customizable editor"
echo "  3) micro - Modern, intuitive terminal editor"
echo "  4) helix - Post-modern text editor"
echo ""
echo "  0) None - stick with nano and vim only"
echo ""

read -r -a editor_choices -p "Select additional editors (space-separated, e.g., '1 3', or 0 for none): "

if [ "${#editor_choices[@]}" -gt 0 ] && [ "${editor_choices[0]}" != "0" ]; then
    for choice in "${editor_choices[@]}"; do
        case $choice in
            1)
                SELECTED_EDITORS+=("neovim")
                print_success "Added: neovim"
                ;;
            2)
                SELECTED_EDITORS+=("emacs-nox")
                print_success "Added: emacs (no X11)"
                ;;
            3)
                SELECTED_EDITORS+=("micro")
                print_success "Added: micro"
                ;;
            4)
                SELECTED_EDITORS+=("helix")
                print_success "Added: helix"
                ;;
            *)
                print_warning "Invalid choice: $choice (skipped)"
                ;;
        esac
    done
fi

# ===================================
# SUMMARY
# ===================================
smart_clear
show_alie_banner
print_step "002: STEP 4: Installation Summary"

print_info "Shells to be installed:"
if [ ${#SELECTED_SHELLS[@]} -eq 0 ]; then
    echo "  - bash (default only)"
else
    echo "  - bash (default)"
    for shell in "${SELECTED_SHELLS[@]}"; do
        echo "  - $shell"
    done
fi

echo "Kernels to be installed:"
for kernel in "${SELECTED_KERNELS[@]}"; do
    echo "  - $kernel (with linux-firmware)"
done

echo ""
echo "Additional packages to be installed:"
echo "  - networkmanager (network management)"
echo "  - vim, nano (base editors)"
echo "  - sudo (privilege escalation)"

# Show bootloader info if available
if [ -f /tmp/.alie-install-config ]; then
    # shellcheck disable=SC1091
    source /tmp/.alie-install-config
    if [ "${BOOTLOADER:-grub}" = "systemd-boot" ]; then
        echo "  - systemd-boot (bootloader)"
    elif [ "${BOOTLOADER:-grub}" = "limine" ]; then
        echo "  - limine (bootloader)"
    else
        echo "  - grub (bootloader)"
    fi
    
    if [ -n "${MICROCODE_PKG:-}" ]; then
        echo "  - $MICROCODE_PKG (CPU microcode)"
    fi
    
    if [ "$BOOT_MODE" = "UEFI" ]; then
        echo "  - efibootmgr (UEFI boot manager)"
    fi
fi

# Show filesystem-specific packages
if [ -f /tmp/.alie-install-config ]; then
    case "${ROOT_FS:-ext4}" in
        "btrfs")
            echo "  - btrfs-progs (Btrfs filesystem tools)"
            ;;
        "xfs")
            echo "  - xfsprogs (XFS filesystem tools)"
            ;;
        "zfs")
            echo "  - zfs-linux (ZFS filesystem support)"
            ;;
    esac
fi

echo ""
read -r -p "Proceed with this configuration? (Y/n): " confirm
if [[ $confirm =~ ^[Nn]$ ]]; then
    print_warning "Installation cancelled by user"
    exit 0
fi

# ===================================
# SAVE CONFIGURATION
# ===================================
print_step "002: STEP 5: Saving Configuration"

# Create configuration file for 003-system-install.sh to read
CONFIG_FILE="/tmp/.alie-shell-editor-config"

{
    echo "# ALIE Shell and Editor Configuration"
    echo "# Generated by: 002-shell-editor-select.sh"
    echo "# Date: $(date)"
    echo ""
    
    if [ ${#SELECTED_SHELLS[@]} -gt 0 ]; then
        echo "EXTRA_SHELLS=\"${SELECTED_SHELLS[*]}\""
    else
        echo "EXTRA_SHELLS=\"\""
    fi
    
    if [ ${#SELECTED_EDITORS[@]} -gt 0 ]; then
        echo "EXTRA_EDITORS=\"${SELECTED_EDITORS[*]}\""
    else
        echo "EXTRA_EDITORS=\"\""
    fi
    
    echo "CONFIGURE_NANO=\"$CONFIGURE_NANO\""
    echo "CONFIGURE_VIM=\"$CONFIGURE_VIM\""
    echo "SELECTED_KERNELS=\"${SELECTED_KERNELS[*]}\""
    
} > "$CONFIG_FILE"

print_success "Configuration saved to: $CONFIG_FILE"

print_info "Configuration file content:"
echo "----------------------------------------"
cat "$CONFIG_FILE"
echo "----------------------------------------"

# Also save for later use (after chroot)
save_install_info "/mnt/root/.alie-install-info" "SELECTED_SHELLS" "SELECTED_EDITORS" "CONFIGURE_NANO" "CONFIGURE_VIM" "SELECTED_KERNELS"

# Mark progress
save_progress "01b-shell-editor-selected"

# ===================================
# CONTINUE TO SYSTEM INSTALLATION
# ===================================
smart_clear
show_alie_banner
print_step "002: STEP 6: Continuing to System Installation..."

echo ""
print_success "Configuration complete!"
echo ""
print_info "Automatically proceeding to system installation..."
echo ""

# Execute the next script automatically
if [ -f "$SCRIPT_DIR/003-system-install.sh" ]; then
    print_info "Running: 003-system-install.sh"
    echo ""
    bash "$SCRIPT_DIR/003-system-install.sh"
else
    print_error_detailed "003-system-install.sh not found in $SCRIPT_DIR" \
        "System installation script is required to continue the installation process" \
        "This script performs the actual base system installation with pacstrap" \
        "Ensure all ALIE scripts are present: ls -la install/"
    exit 1
fi
