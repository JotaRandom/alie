#!/bin/bash
# ALIE Desktop Tools and Applications (231-desktop-tools.sh)
# This script installs additional desktop applications and tools
# Run AFTER 221-desktop-environment.sh or 222-window-manager.sh
#
# Note: If you installed Cinnamon Mint Mode, you DON'T need this script.
#       Mint Mode already includes all Linux Mint applications.

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/shared-functions.sh"

################################################################################
# APPLICATION INSTALLERS
################################################################################

install_productivity() {
    log_info "Installing Productivity Suite..."
    
    local packages=(
        libreoffice-fresh
        libreoffice-fresh-es
        hunspell-en_us
        hunspell-es_es
    )
    
    install_package "${packages[@]}"
    log_success "Productivity suite installed"
}

install_multimedia() {
    log_info "Installing Multimedia Tools..."
    
    echo "Select multimedia tools:"
    echo "  1) All (GIMP, Inkscape, Kdenlive, OBS, Audacity)"
    echo "  2) Image editing only (GIMP, Inkscape, Krita)"
    echo "  3) Video tools only (Kdenlive, OBS)"
    echo "  4) Audio tools only (Audacity)"
    echo "  5) Skip"
    read -p "Choose [1-5]: " choice
    
    case "$choice" in
        1)
            install_package gimp inkscape krita kdenlive obs-studio audacity ffmpeg handbrake
            ;;
        2)
            install_package gimp inkscape krita
            ;;
        3)
            install_package kdenlive obs-studio
            ;;
        4)
            install_package audacity
            ;;
        5)
            log_info "Skipping multimedia tools"
            return
            ;;
    esac
    
    log_success "Multimedia tools installed"
}

install_internet() {
    log_info "Installing Internet Applications..."
    
    local packages=(
        firefox
        firefox-i18n-es-es
        thunderbird
        transmission-gtk
    )
    
    install_package "${packages[@]}"
    log_success "Internet applications installed"
}

install_mint_themes() {
    log_info "Linux Mint Themes Information"
    log_warning "Mint themes require AUR helper (yay/paru)"
    log_info "Install with: yay -S mint-themes mint-y-icons mint-x-icons"
    echo ""
    read -p "Press Enter to continue..."
}

install_development() {
    log_info "Installing Development Tools..."
    
    echo "Select development tools:"
    echo "  1) All (Git, build-essential, VS Code, Docker)"
    echo "  2) Basic only (Git, base-devel)"
    echo "  3) VS Code only"
    echo "  4) Skip"
    read -p "Choose [1-4]: " choice
    
    case "$choice" in
        1)
            install_package git base-devel code docker docker-compose python python-pip nodejs npm
            ;;
        2)
            install_package git base-devel
            ;;
        3)
            install_package code
            ;;
        4)
            log_info "Skipping development tools"
            return
            ;;
    esac
    
    log_success "Development tools installed"
}

install_gaming() {
    log_info "Installing Gaming Platform..."
    
    # Enable multilib for 32-bit support
    log_info "Enabling multilib repository..."
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
        pacman -Sy
    fi
    
    local packages=(
        steam
        lutris
        wine-staging
        winetricks
        gamemode
        lib32-nvidia-utils  # If using NVIDIA
    )
    
    install_package "${packages[@]}"
    log_success "Gaming platform installed"
}

################################################################################
# MENU SYSTEM
################################################################################

show_tools_menu() {
    echo ""
    log_info "Desktop Tools Selection"
    echo ""
    echo "Select tools to install:"
    echo ""
    echo "  1) Everything (all tools below)"
    echo "  2) Productivity (LibreOffice)"
    echo "  3) Multimedia (GIMP, Kdenlive, Audacity, etc.)"
    echo "  4) Internet (Firefox, Thunderbird, Transmission)"
    echo "  5) Mint Themes (AUR packages info)"
    echo "  6) Development Tools (VS Code, Git, build tools)"
    echo "  7) Gaming (Steam, Lutris, Wine)"
    echo "  8) Custom selection (choose individually)"
    echo ""
    echo "  0) Exit"
    echo ""
    
    read -p "Select option [1-8, 0]: " choice
    
    case "$choice" in
        1)
            install_productivity
            install_multimedia
            install_internet
            install_mint_themes
            install_development
            install_gaming
            ;;
        2) install_productivity ;;
        3) install_multimedia ;;
        4) install_internet ;;
        5) install_mint_themes ;;
        6) install_development ;;
        7) install_gaming ;;
        8)
            echo ""
            log_info "Custom selection - answer each category:"
            echo ""
            install_productivity
            install_multimedia
            install_internet
            install_mint_themes
            install_development
            install_gaming
            ;;
        0)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    require_root
    
    log_section "ALIE Desktop Tools Installation"
    
    log_info "This script installs additional desktop applications"
    echo "  - Productivity: LibreOffice"
    echo "  - Multimedia: GIMP, Kdenlive, OBS"
    echo "  - Internet: Firefox, Thunderbird"
    echo "  - Themes: Linux Mint themes (AUR)"
    echo "  - Development: VS Code, Git, build tools"
    echo "  - Gaming: Steam, Lutris, Wine"
    echo ""
    log_warning "Desktop environment must be installed first!"
    echo "  Run 221-desktop-environment.sh or 222-window-manager.sh if not done"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to exit..."
    
    # Show menu and install
    show_tools_menu
    
    log_section "Desktop Tools Installation Completed"
    
    echo ""
    log_success "Desktop tools installation completed!"
    echo ""
    log_info "Next steps:"
    echo "  - Explore your installed applications"
    echo "  - Configure your desktop environment"
    echo "  - Install AUR helper for Mint themes:"
    echo "    bash install/211-install-aur-helper.sh (as user)"
    echo ""
}

# Run main function
main "$@"
