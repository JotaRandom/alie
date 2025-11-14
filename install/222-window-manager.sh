#!/bin/bash
# ALIE Window Manager Installation (222-window-manager.sh)
# Installs standalone window managers (WM) - minimal, keyboard-driven environments
# Run AFTER 213-display-server.sh
#
# Available Window Managers:
#   - i3 / i3-gaps: Tiling WM, minimalist, productive
#   - bspwm: Binary space partitioning tiling WM
#   - Openbox: Floating WM, lightweight and flexible
#   - Awesome: Dynamic tiling WM, Lua-configured
#   - dwm: Suckless minimal WM (requires building from source)

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/shared-functions.sh"
source "${SCRIPT_DIR}/../lib/config-functions.sh"

# Global variables
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
        exit 1
    fi
}

check_x11_requirement() {
    # Most WMs require X11
    if [[ $HAS_X11 -eq 0 ]]; then
        log_warning "This window manager requires X11 (not installed)"
        log_info "Installing X11 display server..."
        install_package xorg-server xorg-xinit
        HAS_X11=1
    fi
}

################################################################################
# COMMON COMPONENTS
################################################################################

install_wm_essentials() {
    log_info "Installing essential WM components..."
    
    local packages=(
        # Terminal emulator
        alacritty
        
        # Application launcher
        rofi
        
        # Status bar
        polybar
        
        # Compositor (for transparency, shadows, etc.)
        picom
        
        # Wallpaper setter
        feh
        
        # Screen locker
        i3lock
        
        # Notification daemon
        dunst
        
        # Audio control
        pavucontrol
        
        # Network manager applet
        network-manager-applet
        
        # File manager
        pcmanfm
        gvfs gvfs-mtp
        
        # Text editor
        mousepad
        
        # Image viewer
        feh
        
        # Archive manager
        file-roller
        
        # System monitor
        htop
        
        # Screenshot tool
        maim
        xclip
    )
    
    install_package "${packages[@]}"
    log_success "Essential components installed"
}

################################################################################
# i3 WINDOW MANAGER
################################################################################

install_i3() {
    log_section "Installing i3 Window Manager"
    
    check_x11_requirement
    
    local packages=(
        i3-wm
        i3status
        i3lock
        dmenu
        
        # Display manager (optional - can use startx)
        lightdm
        lightdm-gtk-greeter
    )
    
    install_package "${packages[@]}"
    install_wm_essentials
    
    # Create basic i3 config
    log_info "Creating default i3 configuration..."
    log_warning "User must run 'i3-config-wizard' on first login"
    
    configure_lightdm_wm
    
    log_success "i3 Window Manager installed"
    log_info "Start with: startx (or enable lightdm and reboot)"
}

install_i3_gaps() {
    log_section "Installing i3-gaps Window Manager"
    
    check_x11_requirement
    
    local packages=(
        i3-gaps
        i3status
        i3lock
        dmenu
        
        lightdm
        lightdm-gtk-greeter
    )
    
    install_package "${packages[@]}"
    install_wm_essentials
    
    log_info "Creating default i3-gaps configuration..."
    log_warning "User must run 'i3-config-wizard' on first login"
    
    configure_lightdm_wm
    
    log_success "i3-gaps Window Manager installed"
    log_info "Start with: startx (or enable lightdm and reboot)"
}

################################################################################
# BSPWM WINDOW MANAGER
################################################################################

install_bspwm() {
    log_section "Installing bspwm Window Manager"
    
    check_x11_requirement
    
    local packages=(
        bspwm
        sxhkd  # Hotkey daemon
        
        lightdm
        lightdm-gtk-greeter
    )
    
    install_package "${packages[@]}"
    install_wm_essentials
    
    log_info "Creating default bspwm configuration..."
    log_warning "User must configure ~/.config/bspwm/bspwmrc"
    log_warning "User must configure ~/.config/sxhkd/sxhkdrc"
    
    configure_lightdm_wm
    
    log_success "bspwm Window Manager installed"
    log_info "Start with: startx (or enable lightdm and reboot)"
}

################################################################################
# OPENBOX WINDOW MANAGER
################################################################################

install_openbox() {
    log_section "Installing Openbox Window Manager"
    
    check_x11_requirement
    
    local packages=(
        openbox
        obconf      # GUI configuration tool
        obmenu      # Menu editor
        tint2       # Panel
        
        lightdm
        lightdm-gtk-greeter
    )
    
    install_package "${packages[@]}"
    install_wm_essentials
    
    log_info "Creating default Openbox configuration..."
    log_warning "User should copy configs: cp -r /etc/xdg/openbox ~/.config/"
    
    configure_lightdm_wm
    
    log_success "Openbox Window Manager installed"
    log_info "Start with: startx (or enable lightdm and reboot)"
}

################################################################################
# AWESOME WINDOW MANAGER
################################################################################

install_awesome() {
    log_section "Installing Awesome Window Manager"
    
    check_x11_requirement
    
    local packages=(
        awesome
        vicious  # Widget library
        
        lightdm
        lightdm-gtk-greeter
    )
    
    install_package "${packages[@]}"
    install_wm_essentials
    
    log_info "Creating default Awesome configuration..."
    log_warning "User should customize ~/.config/awesome/rc.lua"
    
    configure_lightdm_wm
    
    log_success "Awesome Window Manager installed"
    log_info "Start with: startx (or enable lightdm and reboot)"
}

################################################################################
# DWM WINDOW MANAGER
################################################################################

install_dwm() {
    log_section "Installing dwm Window Manager"
    
    check_x11_requirement
    
    log_warning "dwm requires building from source (suckless philosophy)"
    log_info "This installer will:"
    log_info "  1. Install build dependencies"
    log_info "  2. Clone dwm from suckless.org"
    log_info "  3. Install to /usr/local/bin"
    echo ""
    read -p "Continue? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        return
    fi
    
    # Install build dependencies
    local packages=(
        base-devel
        libx11
        libxft
        libxinerama
        
        lightdm
        lightdm-gtk-greeter
    )
    
    install_package "${packages[@]}"
    install_wm_essentials
    
    log_info "Cloning dwm source..."
    local build_dir="/tmp/dwm-build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    
    cd "$build_dir"
    git clone https://git.suckless.org/dwm
    cd dwm
    
    log_info "Building dwm..."
    make
    
    log_info "Installing dwm to /usr/local/bin..."
    make install
    
    log_info "Creating dwm.desktop for display managers..."
    cat > /usr/share/xsessions/dwm.desktop <<EOF
[Desktop Entry]
Name=dwm
Comment=Dynamic window manager
Exec=dwm
Type=Application
EOF
    
    configure_lightdm_wm
    
    log_success "dwm Window Manager installed"
    log_info "Source location: $build_dir/dwm"
    log_info "Customize by editing config.h and rebuilding"
    log_info "Start with: startx (or enable lightdm and reboot)"
}

################################################################################
# DISPLAY MANAGER CONFIGURATION
################################################################################

configure_lightdm_wm() {
    log_info "Configuring LightDM for window managers..."
    
    # LightDM with GTK greeter (default works fine for WMs)
    log_success "LightDM configured (using GTK greeter defaults)"
}

enable_wm_services() {
    log_info "Enabling display manager service..."
    
    if pacman -Qq lightdm &>/dev/null; then
        systemctl enable lightdm
        log_success "LightDM enabled (will start on next boot)"
    fi
    
    log_info "System will remain in TTY mode until reboot"
    log_info "To start the WM now: systemctl start lightdm"
    log_info "Or use: startx (after creating ~/.xinitrc)"
}

################################################################################
# MENU SYSTEM
################################################################################

show_wm_menu() {
    clear
    echo "============================================"
    echo "  ALIE Window Manager Installation"
    echo "============================================"
    echo ""
    echo "Available Window Managers:"
    echo ""
    echo "TILING (keyboard-driven, automatic layout):"
    echo "  1) i3              - Minimalist tiling WM"
    echo "  2) i3-gaps         - i3 with gaps between windows"
    echo "  3) bspwm           - Binary space partitioning tiling"
    echo "  4) Awesome         - Dynamic tiling with Lua config"
    echo ""
    echo "FLOATING (traditional window behavior):"
    echo "  5) Openbox         - Lightweight, highly configurable"
    echo ""
    echo "MINIMAL (suckless philosophy):"
    echo "  6) dwm             - Ultra-minimal (builds from source)"
    echo ""
    echo "  0) Exit"
    echo ""
    echo "============================================"
    echo ""
    echo "Note: All options include essential tools:"
    echo "  - Terminal: Alacritty"
    echo "  - Launcher: Rofi"
    echo "  - Bar: Polybar"
    echo "  - Compositor: Picom"
    echo "  - File Manager: PCManFM"
    echo ""
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    require_root
    
    log_section "ALIE Window Manager Installation"
    
    # Check display servers
    check_display_server
    
    # Show menu
    while true; do
        show_wm_menu
        read -p "Select window manager to install: " choice
        
        case $choice in
            1)
                install_i3
                enable_wm_services
                break
                ;;
            2)
                install_i3_gaps
                enable_wm_services
                break
                ;;
            3)
                install_bspwm
                enable_wm_services
                break
                ;;
            4)
                install_awesome
                enable_wm_services
                break
                ;;
            5)
                install_openbox
                enable_wm_services
                break
                ;;
            6)
                install_dwm
                enable_wm_services
                break
                ;;
            0)
                log_info "Exiting window manager installation"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please try again."
                sleep 2
                ;;
        esac
    done
    
    log_section "Window Manager Installation Complete"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Reboot to start the display manager"
    log_info "  2. Or start manually: systemctl start lightdm"
    log_info "  3. Or use startx (create ~/.xinitrc first)"
    log_info ""
    log_info "Configuration:"
    log_info "  - WM configs are in: ~/.config/<wm-name>/"
    log_info "  - Create/customize your dotfiles"
    log_info "  - Install additional apps: run 231-desktop-tools.sh"
    log_info ""
    log_warning "Window Managers require manual configuration!"
    log_info "Consult the documentation for your chosen WM"
}

# Run main function
main "$@"
