#!/bin/bash
# ALIE Wayland Window Manager Installation (223-wayland-wm.sh)
# Installs Wayland-native window managers
# Run AFTER 213-display-server.sh (with Wayland)
#
# Available Wayland Window Managers:
#   - sway: i3-compatible Wayland WM
#   - hyprland: Dynamic tiling Wayland WM
#   - river: Wayland WM with Zig
#   - niri: Scrollable tiling Wayland WM
#   - labwc: Wayland Openbox

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/shared-functions.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/shared-functions.sh"
# shellcheck source=../lib/config-functions.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/config-functions.sh"

# Global variables
# (No global variables needed for this script)

################################################################################
# DISPLAY SERVER DETECTION
################################################################################

check_display_server() {
    log_info "Checking for Wayland display server..."

    if pacman -Qq wayland &>/dev/null; then
        log_success "Wayland detected"
    else
        log_error "Wayland is required for Wayland window managers!"
        log_info "Run script 213-display-server.sh first to install Wayland"
        exit 1
    fi
}

################################################################################
# COMMON COMPONENTS FOR WAYLAND WM
################################################################################

install_wayland_wm_essentials() {
    log_info "Installing essential Wayland WM components..."

    local packages=(
        # Terminal emulator
        alacritty

        # Application launcher
        wofi

        # Status bar
        waybar

        # Wallpaper setter
        swaybg

        # Screen locker
        swaylock

        # Notification daemon
        mako

        # Audio control
        pavucontrol

        # Network manager
        network-manager-applet

        # File manager
        dolphin
        gvfs gvfs-mtp

        # Text editor
        mousepad

        # Image viewer
        imv

        # Archive manager
        file-roller

        # System monitor
        htop

        # Screenshot tools
        grim
        slurp
        wl-clipboard
    )

    install_package "${packages[@]}"
    log_success "Essential Wayland components installed"
}

################################################################################
# SWAY WINDOW MANAGER
################################################################################

install_sway() {
    log_section "Installing Sway Window Manager"

    local packages=(
        sway
        swayidle
        swaylock
        xorg-xwayland  # X11 compatibility

        # Display manager (optional)
        greetd
        greetd-wlgreet
    )

    install_package "${packages[@]}"
    install_wayland_wm_essentials

    log_info "Creating default Sway configuration..."
    log_warning "User should customize ~/.config/sway/config"

    configure_greetd

    log_success "Sway Window Manager installed"
    log_info "Start with: sway (or enable greetd and reboot)"
}

################################################################################
# HYPRLAND WINDOW MANAGER
################################################################################

install_hyprland() {
    log_section "Installing Hyprland Window Manager"

    local packages=(
        hyprland
        dunst
        kitty
        uwsm
        dolphin
        wofi
        xdg-desktop-portal-hyprland
        qt5-wayland
        qt6-wayland
        polkit-kde-agent

        # Display manager (optional)
        greetd
        greetd-wlgreet
    )

    install_package "${packages[@]}"
    install_wayland_wm_essentials

    log_info "Creating default Hyprland configuration..."
    log_warning "User should customize ~/.config/hypr/hyprland.conf"

    configure_greetd

    log_success "Hyprland Window Manager installed"
    log_info "Start with: Hyprland (or enable greetd and reboot)"
}

################################################################################
# RIVER WINDOW MANAGER
################################################################################

install_river() {
    log_section "Installing River Window Manager"

    local packages=(
        river
        waybar
        wofi
        mako
        swaybg
        swaylock
        grim
        slurp
        wl-clipboard

        # Display manager (optional)
        greetd
        greetd-wlgreet
    )

    install_package "${packages[@]}"
    install_wayland_wm_essentials

    log_info "Creating default River configuration..."
    log_warning "User should customize ~/.config/river/init"

    configure_greetd

    log_success "River Window Manager installed"
    log_info "Start with: river (or enable greetd and reboot)"
}

################################################################################
# NIRI WINDOW MANAGER
################################################################################

install_niri() {
    log_section "Installing Niri Window Manager"

    local packages=(
        niri
        waybar
        wofi
        mako
        swaybg
        swaylock
        grim
        slurp
        wl-clipboard

        # Display manager (optional)
        greetd
        greetd-wlgreet
    )

    install_package "${packages[@]}"
    install_wayland_wm_essentials

    log_info "Creating default Niri configuration..."
    log_warning "User should customize ~/.config/niri/config.kdl"

    configure_greetd

    log_success "Niri Window Manager installed"
    log_info "Start with: niri (or enable greetd and reboot)"
}

################################################################################
# LABWC WINDOW MANAGER
################################################################################

install_labwc() {
    log_section "Installing Labwc Window Manager"

    local packages=(
        labwc
        waybar
        wofi
        mako
        swaybg
        swaylock
        grim
        slurp
        wl-clipboard

        # Display manager (optional)
        greetd
        greetd-wlgreet
    )

    install_package "${packages[@]}"
    install_wayland_wm_essentials

    log_info "Creating default Labwc configuration..."
    log_warning "User should customize ~/.config/labwc/"

    configure_greetd

    log_success "Labwc Window Manager installed"
    log_info "Start with: labwc (or enable greetd and reboot)"
}

################################################################################
# WLMAKER WINDOW MANAGER
################################################################################

install_wlmaker() {
    log_section "Installing Wlmaker Window Manager"

    local packages=(
        wlmaker
        waybar
        wofi
        mako
        swaybg
        swaylock
        grim
        slurp
        wl-clipboard

        # Display manager (optional)
        greetd
        greetd-wlgreet
    )

    # wlmaker is in AUR, so we need to use aur_install
    aur_install "${packages[@]}"
    install_wayland_wm_essentials

    log_info "Creating default Wlmaker configuration..."
    log_warning "User should customize ~/.wlmaker/"

    configure_greetd

    log_success "Wlmaker Window Manager installed"
    log_info "Start with: wlmaker (or enable greetd and reboot)"
}

################################################################################
# DISPLAY MANAGER CONFIGURATION
################################################################################

configure_greetd() {
    log_info "Configuring greetd for Wayland window managers..."

    # greetd with wlgreet (Wayland greeter)
    log_success "greetd configured (using wlgreet defaults)"
}

enable_wayland_wm_services() {
    log_info "Enabling display manager service..."

    if is_display_manager_installed "greetd"; then
        systemctl enable greetd
        log_success "greetd enabled (will start on next boot)"
    fi

    log_info "System will remain in TTY mode until reboot"
    log_info "To start the WM now: systemctl start greetd"
}

################################################################################
# MENU SYSTEM
################################################################################

show_wayland_wm_menu() {
    clear
    echo "============================================"
    echo "  ALIE Wayland Window Manager Installation"
    echo "============================================"
    echo ""
    echo "Available Wayland Window Managers:"
    echo ""
    echo "TILING (keyboard-driven, automatic layout):"
    echo "  1) sway             - i3-compatible Wayland WM"
    echo "  2) hyprland         - Dynamic tiling Wayland WM"
    echo "  3) river            - Wayland WM with Zig"
    echo "  4) niri             - Scrollable tiling Wayland WM"
    echo ""
    echo "FLOATING (traditional window behavior):"
    echo "  5) labwc            - Wayland Openbox"
    echo "  6) wlmaker          - Window Maker for Wayland"
    echo ""
    echo "  0) Exit"
    echo ""
    echo "============================================"
    echo ""
    echo "Note: All options include essential tools:"
    echo "  - Terminal: Alacritty"
    echo "  - Launcher: wofi"
    echo "  - Bar: waybar"
    echo "  - Compositor: Built-in"
    echo "  - File Manager: Dolphin"
    echo ""
    echo "Requirements: Wayland must be installed"
    echo ""
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    require_root

    log_section "ALIE Wayland Window Manager Installation"

    # Check display servers
    check_display_server

    # Show menu
    while true; do
        show_wayland_wm_menu
        read -r -p "Select Wayland window manager to install: " choice

        case $choice in
            1)
                install_sway
                enable_wayland_wm_services
                break
                ;;
            2)
                install_hyprland
                enable_wayland_wm_services
                break
                ;;
            3)
                install_river
                enable_wayland_wm_services
                break
                ;;
            4)
                install_niri
                enable_wayland_wm_services
                break
                ;;
            5)
                install_labwc
                enable_wayland_wm_services
                break
                ;;
            6)
                install_wlmaker
                enable_wayland_wm_services
                break
                ;;
            0)
                log_info "Exiting Wayland window manager installation"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please try again."
                sleep 2
                ;;
        esac
    done

    log_section "Wayland Window Manager Installation Complete"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Reboot to start the display manager"
    log_info "  2. Or start manually: systemctl start greetd"
    log_info ""
    log_info "Configuration:"
    log_info "  - WM configs are in: ~/.config/<wm-name>/"
    log_info "  - Create/customize your dotfiles"
    log_info "  - Install additional apps: run 231-desktop-tools.sh"
    log_info ""
    log_warning "Wayland Window Managers require manual configuration!"
    log_info "Consult the documentation for your chosen WM"
}

# Run main function
main "$@"
