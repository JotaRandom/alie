#!/bin/bash
# ALIE Desktop Environment Installation
# Installs desktop environments (DE) only - applications are in 231-desktop-tools.sh
# This script should be run after display server setup (213), as root
#
# Available Desktop Environments:
#   - Cinnamon (Normal: 10 pkgs, Mint: ~130 pkgs LMAE-compliant)
#   - XFCE4 (Normal: core + goodies + gvfs)
#   - GNOME (Normal: 58, Full: 80, Complete: 140 pkgs)
#   - KDE Plasma (Normal: 64, Full: 253, Complete: 380+ pkgs)

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/shared-functions.sh"
source "${SCRIPT_DIR}/../lib/config-functions.sh"

# Global variables for display server detection
HAS_X11=0
HAS_WAYLAND=0

################################################################################
# DISPLAY SERVER DETECTION
################################################################################

check_display_server() {
    log_info "Checking installed display servers..."
    
    if pacman -Qq xorg-server &>/dev/null; then
        HAS_X11=1
        log_success "X11 (Xorg) detected"
    fi
    
    if pacman -Qq wayland &>/dev/null; then
        HAS_WAYLAND=1
        log_success "Wayland detected"
    fi
    
    if [[ $HAS_X11 -eq 0 && $HAS_WAYLAND -eq 0 ]]; then
        log_warning "No display server detected!"
        log_info "Run script 213-display-server.sh first to install X11 or Wayland"
    fi
}

check_display_compatibility() {
    local de_name="$1"
    
    case "$de_name" in
        "cinnamon"|"xfce4")
            # These DEs work best with X11
            if [[ $HAS_X11 -eq 0 ]]; then
                log_warning "$de_name works best with X11 (not installed)"
                log_info "Installing X11 display server..."
                install_package xorg-server xorg-xinit
                HAS_X11=1
            fi
            ;;
        "gnome")
            # GNOME requires Wayland only (XWayland handles legacy X11 apps)
            if [[ $HAS_WAYLAND -eq 0 ]]; then
                log_warning "GNOME requires Wayland (not installed)"
                log_info "Installing Wayland display server..."
                install_package wayland xorg-xwayland
                HAS_WAYLAND=1
            fi
            ;;
        "plasma")
            # KDE Plasma supports both X11 and Wayland
            if [[ $HAS_X11 -eq 0 && $HAS_WAYLAND -eq 0 ]]; then
                log_warning "KDE Plasma works with either X11 or Wayland (neither installed)"
                log_info "User should install preferred display server via script 213"
            fi
            ;;
    esac
}

################################################################################
# CINNAMON INSTALLATION
################################################################################

install_cinnamon_normal() {
    log_section "Installing Cinnamon Desktop (Normal - Minimal)"
    
    check_display_compatibility "cinnamon"
    
    local packages=(
        cinnamon
        nemo-fileroller
        system-config-printer
        gnome-screenshot
        gnome-terminal
        gedit
        file-roller
        eog
        evince
        lightdm-slick-greeter
    )
    
    install_package "${packages[@]}"
    configure_lightdm
    enable_desktop_services
    
    log_success "Cinnamon Desktop (Normal) installed successfully"
}

install_cinnamon_mint() {
    log_section "Installing Cinnamon Desktop (Mint Mode - LMAE Compliant)"
    
    check_display_compatibility "cinnamon"
    
    # Core Cinnamon + LightDM
    local core_packages=(
        cinnamon
        lightdm-slick-greeter
    )
    
    # LMAE-compliant package list for Mint mode (~130 packages)
    local mint_packages=(
        # File Management
        nemo-fileroller nemo-share
        
        # System Tools
        gnome-disk-utility gnome-system-monitor
        system-config-printer
        
        # Network & Bluetooth
        network-manager-applet nm-connection-editor
        blueman
        
        # Audio
        pavucontrol
        
        # Terminal & Text
        gnome-terminal
        gedit
        
        # Archive Management
        file-roller p7zip unrar unzip zip
        
        # Image Viewers & Editors
        eog
        pix
        drawing
        
        # Document Viewers
        evince
        
        # Media Players
        celluloid
        
        # Screenshot & Screen Recording
        gnome-screenshot
        
        # Utilities
        gnome-calculator
        gnome-font-viewer
        gucharmap
        
        # Themes & Icons (will be available from Mint repos/AUR in 222)
        
        # Additional Cinnamon Components
        cinnamon-translations
        cinnamon-control-center
        cinnamon-screensaver
        cinnamon-session
        cinnamon-settings-daemon
        cinnamon-desktop
        cinnamon-menus
        
        # Nemo Extensions
        nemo-audio-tab
        nemo-image-converter
        nemo-preview
        
        # Desktop Integration
        xdg-user-dirs-gtk
        xdg-utils
        
        # Fonts
        noto-fonts
        ttf-dejavu
        ttf-liberation
        
        # Common Dependencies
        gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-smb gvfs-nfs
    )
    
    install_package "${core_packages[@]}"
    install_package "${mint_packages[@]}"
    
    configure_lightdm
    enable_desktop_services
    
    log_success "Cinnamon Desktop (Mint Mode - LMAE) installed successfully"
    log_info "Install Mint themes from AUR using script 231-desktop-tools.sh"
}

################################################################################
# XFCE4 INSTALLATION
################################################################################

install_xfce4_normal() {
    log_section "Installing XFCE4 Desktop (Normal)"
    
    check_display_compatibility "xfce4"
    
    local packages=(
        # Core XFCE4
        xfce4
        xfce4-goodies
        
        # Display Manager
        lightdm
        lightdm-gtk-greeter
        
        # File Management (gvfs needed for Thunar trash support)
        thunar-archive-plugin
        thunar-media-tags-plugin
        gvfs gvfs-mtp gvfs-gphoto2 gvfs-afc gvfs-smb
        
        # Network
        network-manager-applet
        
        # Audio
        pavucontrol
        
        # Archive Support
        file-roller
        
        # Common Applications
        mousepad
        ristretto
        
        # System Tools
        gnome-disk-utility
    )
    
    install_package "${packages[@]}"
    configure_lightdm_gtk
    enable_desktop_services
    
    log_success "XFCE4 Desktop installed successfully"
}

################################################################################
# GNOME INSTALLATION
################################################################################

install_gnome_normal() {
    log_section "Installing GNOME Desktop (Normal - 58 packages)"
    
    check_display_compatibility "gnome"
    
    local packages=(
        gnome  # Meta-package: 58 core packages
        gdm
    )
    
    install_package "${packages[@]}"
    configure_gdm
    enable_desktop_services
    
    log_success "GNOME Desktop (Normal) installed successfully"
    log_info "Total packages: ~58 (gnome meta-package)"
}

install_gnome_full() {
    log_section "Installing GNOME Desktop (Full - 80 packages)"
    
    check_display_compatibility "gnome"
    
    local packages=(
        gnome        # 58 packages
        gnome-extra  # 22 additional packages
        gdm
    )
    
    install_package "${packages[@]}"
    configure_gdm
    enable_desktop_services
    
    log_success "GNOME Desktop (Full) installed successfully"
    log_info "Total packages: ~80 (gnome + gnome-extra)"
}

install_gnome_complete() {
    log_section "Installing GNOME Desktop (Complete - 140 packages)"
    
    check_display_compatibility "gnome"
    
    local packages=(
        gnome         # 58 packages
        gnome-extra   # 22 packages
        gnome-circle  # 60 packages (community apps)
        gdm
    )
    
    install_package "${packages[@]}"
    configure_gdm
    enable_desktop_services
    
    log_success "GNOME Desktop (Complete) installed successfully"
    log_info "Total packages: ~140 (gnome + gnome-extra + gnome-circle)"
}

################################################################################
# KDE PLASMA INSTALLATION
################################################################################

install_plasma_normal() {
    log_section "Installing KDE Plasma Desktop (Normal - 64 packages)"
    
    check_display_compatibility "plasma"
    
    local packages=(
        plasma  # Meta-package: 64 core packages
        sddm
    )
    
    install_package "${packages[@]}"
    configure_sddm
    enable_desktop_services
    
    log_success "KDE Plasma Desktop (Normal) installed successfully"
    log_info "Total packages: ~64 (plasma meta-package)"
}

install_plasma_full() {
    log_section "Installing KDE Plasma Desktop (Full - 253 packages)"
    
    check_display_compatibility "plasma"
    
    local packages=(
        plasma             # 64 packages
        kde-applications   # 189 packages (full KDE app suite)
        sddm
    )
    
    install_package "${packages[@]}"
    configure_sddm
    enable_desktop_services
    
    log_success "KDE Plasma Desktop (Full) installed successfully"
    log_info "Total packages: ~253 (plasma + kde-applications)"
}

install_plasma_complete() {
    log_section "Installing KDE Plasma Desktop (Complete - 380+ packages)"
    
    check_display_compatibility "plasma"
    
    local packages=(
        plasma             # 64 packages
        kde-applications   # 189 packages
        kde-graphics       # 14 packages (Gwenview, Okular, etc.)
        kde-multimedia     # 14 packages (Elisa, K3b, etc.)
        kde-network        # 17 packages (KGet, Konversation, etc.)
        kde-utilities      # 32 packages (Ark, Kate, Konsole, etc.)
        kde-system         # 8 packages (Dolphin, KInfoCenter, etc.)
        sddm
    )
    
    install_package "${packages[@]}"
    configure_sddm
    enable_desktop_services
    
    log_success "KDE Plasma Desktop (Complete) installed successfully"
    log_info "Total packages: ~380+ (plasma + all kde groups)"
}

################################################################################
# DISPLAY MANAGER CONFIGURATION
################################################################################

configure_lightdm() {
    log_info "Configuring LightDM with Slick Greeter..."
    
    # Deploy Slick Greeter configuration from configs/
    deploy_config_direct "display-managers/lightdm-slick-greeter.conf" "/etc/lightdm/slick-greeter.conf"
    
    # Execute configuration script to set greeter-session
    execute_config_script "display-managers/configure-lightdm-slick.sh"
    
    log_success "LightDM with Slick Greeter configured"
}

configure_lightdm_gtk() {
    log_info "Configuring LightDM with GTK Greeter..."
    
    # GTK Greeter uses default configuration - no custom config needed
    log_success "LightDM with GTK Greeter configured (using defaults)"
}

configure_gdm() {
    log_info "Configuring GDM..."
    
    # GDM uses Wayland by default - no custom config needed
    log_success "GDM configured (Wayland default)"
}

configure_sddm() {
    log_info "Configuring SDDM..."
    
    # Deploy SDDM configuration from configs/
    deploy_config_direct "display-managers/sddm.conf" "/etc/sddm.conf"
    
    log_success "SDDM configured with Breeze theme"
}

################################################################################
# SERVICE MANAGEMENT
################################################################################

enable_desktop_services() {
    log_info "Enabling display manager service..."
    
    # Detect which display manager is installed and enable it
    # Note: We use 'enable' WITHOUT --now to keep the system in TTY mode
    # User can reboot or manually start the service when ready
    
    if pacman -Qq sddm &>/dev/null; then
        systemctl enable sddm
        log_success "SDDM enabled (will start on next boot)"
    elif pacman -Qq gdm &>/dev/null; then
        systemctl enable gdm
        log_success "GDM enabled (will start on next boot)"
    elif pacman -Qq lightdm &>/dev/null; then
        systemctl enable lightdm
        log_success "LightDM enabled (will start on next boot)"
    else
        log_warning "No display manager detected - services not enabled"
    fi
    
    log_info "System will remain in TTY mode until reboot"
    log_info "To start the desktop now: systemctl start <display-manager>"
}

################################################################################
# MENU SYSTEM
################################################################################

show_de_menu() {
    clear
    echo "============================================"
    echo "  ALIE Desktop Environment Installation"
    echo "============================================"
    echo ""
    echo "Available Desktop Environments:"
    echo ""
    echo "CINNAMON:"
    echo "  1) Cinnamon (Normal)   - Minimal (10 packages)"
    echo "  2) Cinnamon (Mint)     - LMAE-compliant (~130 packages)"
    echo ""
    echo "XFCE4:"
    echo "  3) XFCE4 (Normal)      - Core + Goodies + GVFS"
    echo ""
    echo "GNOME:"
    echo "  4) GNOME (Normal)      - Core only (58 packages)"
    echo "  5) GNOME (Full)        - Core + Extra (80 packages)"
    echo "  6) GNOME (Complete)    - Core + Extra + Circle (140 packages)"
    echo ""
    echo "KDE PLASMA:"
    echo "  7) Plasma (Normal)     - Core only (64 packages)"
    echo "  8) Plasma (Full)       - Core + Applications (253 packages)"
    echo "  9) Plasma (Complete)   - Core + All KDE groups (380+ packages)"
    echo ""
    echo "  0) Exit"
    echo ""
    echo "============================================"
    echo ""
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    # Require root
    require_root
    
    log_section "ALIE Desktop Environment Installation"
    
    # Check display servers
    check_display_server
    
    # Show menu
    while true; do
        show_de_menu
        read -p "Select desktop environment to install: " choice
        
        case $choice in
            1)
                install_cinnamon_normal
                break
                ;;
            2)
                install_cinnamon_mint
                break
                ;;
            3)
                install_xfce4_normal
                break
                ;;
            4)
                install_gnome_normal
                break
                ;;
            5)
                install_gnome_full
                break
                ;;
            6)
                install_gnome_complete
                break
                ;;
            7)
                install_plasma_normal
                break
                ;;
            8)
                install_plasma_full
                break
                ;;
            9)
                install_plasma_complete
                break
                ;;
            0)
                log_info "Exiting desktop environment installation"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please try again."
                sleep 2
                ;;
        esac
    done
    
    log_section "Desktop Environment Installation Complete"
    log_info "Desktop environment has been installed successfully"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Reboot system to start the desktop environment"
    log_info "  2. Or manually start: systemctl start <display-manager>"
    log_info "  3. Install additional apps: run 231-desktop-tools.sh"
    log_info ""
    log_info "Display Managers installed:"
    if pacman -Qq sddm &>/dev/null; then
        log_info "  - SDDM (KDE Plasma)"
    fi
    if pacman -Qq gdm &>/dev/null; then
        log_info "  - GDM (GNOME)"
    fi
    if pacman -Qq lightdm &>/dev/null; then
        log_info "  - LightDM (Cinnamon/XFCE4)"
    fi
}

# Run main function
main "$@"
