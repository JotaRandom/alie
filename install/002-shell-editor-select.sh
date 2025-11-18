#!/bin/bash
# ALIE Shell and Editor Selection
# This script allows selection of alternative shells and text editors
# Run this BEFORE 003-system-install.sh (OPTIONAL step)
#
# *** WARNING: EXPERIMENTAL SCRIPT
# This script is provided AS-IS without warranties.

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Load shared functions
if [ ! -f "$LIB_DIR/shared-functions.sh" ]; then
    echo "ERROR: shared-functions.sh not found at $LIB_DIR/shared-functions.sh"
    exit 1
fi

# shellcheck source=../lib/shared-functions.sh
# shellcheck disable=SC1091
source "$LIB_DIR/shared-functions.sh"

# Load configuration functions
if [ ! -f "$LIB_DIR/config-functions.sh" ]; then
    echo "ERROR: config-functions.sh not found"
    exit 1
fi

# shellcheck source=../lib/config-functions.sh
# shellcheck disable=SC1091
source "$LIB_DIR/config-functions.sh"

# Script information
SCRIPT_NAME="Shell and Editor Selection"
SCRIPT_DESC="Select alternative shells and configure text editors for installation"

print_section_header "$SCRIPT_NAME" "$SCRIPT_DESC"

# Verify running as root
require_root

# Arrays to store selected packages
SELECTED_SHELLS=()
SELECTED_EDITORS=()

# ===================================
# SHELL SELECTION
# ===================================
print_step "STEP 1: Shell Selection"

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

smart_clear
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
# EDITOR CONFIGURATION
# ===================================
print_step "STEP 2: Text Editor Configuration"

print_info "Base editors (nano and vim) are always installed."
echo ""

# Nano configuration
smart_clear
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
smart_clear
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
smart_clear
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
print_step "Installation Summary"

echo "Shells to be installed:"
if [ ${#SELECTED_SHELLS[@]} -eq 0 ]; then
    echo "  - bash (default only)"
else
    echo "  - bash (default)"
    for shell in "${SELECTED_SHELLS[@]}"; do
        echo "  - $shell"
    done
fi

echo ""
echo "Editors to be installed:"
echo "  - nano (default) - $([ "$CONFIGURE_NANO" = "true" ] && echo "with syntax highlighting" || echo "default config")"
echo "  - vim (default) - $([ "$CONFIGURE_VIM" = "true" ] && echo "enhanced config" || echo "default config")"
if [ ${#SELECTED_EDITORS[@]} -gt 0 ]; then
    for editor in "${SELECTED_EDITORS[@]}"; do
        # Skip nano-syntax-highlighting as it's already mentioned
        [[ "$editor" == "nano-syntax-highlighting" ]] && continue
        echo "  - $editor"
    done
fi

echo ""
smart_clear
read -r -p "Proceed with this configuration? (Y/n): " confirm
if [[ $confirm =~ ^[Nn]$ ]]; then
    print_warning "Installation cancelled by user"
    exit 0
fi

# ===================================
# SAVE CONFIGURATION
# ===================================
print_step "Saving Configuration"

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
    
} > "$CONFIG_FILE"

print_success "Configuration saved to: $CONFIG_FILE"

# Also save for later use (after chroot)
save_install_info "extra_shells" "${SELECTED_SHELLS[*]}"
save_install_info "extra_editors" "${SELECTED_EDITORS[*]}"
save_install_info "configure_nano" "$CONFIGURE_NANO"
save_install_info "configure_vim" "$CONFIGURE_VIM"

# Mark progress
save_progress "01b-shell-editor-selected"

# ===================================
# COMPLETION
# ===================================
print_step "*** Shell and Editor Selection Complete!"

echo ""
print_success "Configuration complete!"
echo ""
print_info "Next steps:"
echo "  ${CYAN}1.${NC} Continue with system installation:"
echo "     ${YELLOW}bash install/003-system-install.sh${NC}"
echo ""
print_info "The selected packages will be automatically included in the base installation."
echo ""
