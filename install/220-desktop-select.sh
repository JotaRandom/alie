#!/bin/bash
# ALIE Desktop Selection Menu (220-desktop-select.sh)
# This script helps you choose between Desktop Environments, X11 Window Managers, Wayland Window Managers, or skip
# Run AFTER 213-display-server.sh
#
# Options:
#   - Desktop Environments (DE): Full desktop experience (Cinnamon, GNOME, KDE, XFCE4)
#   - X11 Window Managers (WM): Lightweight X11 WM (i3, bspwm, Awesome, Qtile, Xmonad, dwm)
#   - Wayland Window Managers (WM): Modern Wayland WM (Sway, Hyprland, River, Niri, Labwc)
#   - Skip: Continue without installing graphical environment

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/shared-functions.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/shared-functions.sh"

################################################################################
# INFORMATION SECTIONS
################################################################################

show_de_info() {
    clear
    echo "============================================"
    echo "  Desktop Environments (DE)"
    echo "============================================"
    echo ""
    echo "What is a Desktop Environment?"
    echo "  A complete graphical interface with:"
    echo "  - Window management and compositing"
    echo "  - File manager, terminal, text editor"
    echo "  - System settings and control panels"
    echo "  - Application menu and taskbar"
    echo "  - Preconfigured theme and appearance"
    echo ""
    echo "Available in ALIE:"
    echo "  - Cinnamon (Normal/Mint): Modern, elegant, user-friendly"
    echo "  - GNOME: Clean, modern, Wayland-native"
    echo "  - KDE Plasma: Feature-rich, highly customizable"
    echo "  - XFCE4: Lightweight, traditional, stable"
    echo ""
    echo "Pros:"
    echo "  + Ready to use out-of-the-box"
    echo "  + Integrated suite of applications"
    echo "  + User-friendly for beginners"
    echo "  + Consistent look and feel"
    echo ""
    echo "Cons:"
    echo "  - Higher resource usage (~500MB-2GB RAM)"
    echo "  - Less flexibility for advanced customization"
    echo "  - Larger installation size"
    echo ""
    read -r -p "Press Enter to continue..."
}

show_wm_info() {
    clear
    echo "============================================"
    echo "  Window Managers (WM)"
    echo "============================================"
    echo ""
    echo "What is a Window Manager?"
    echo "  A minimal component that only manages windows:"
    echo "  - Window placement and movement"
    echo "  - Keyboard-driven workflow (usually)"
    echo "  - Manual configuration required"
    echo "  - You choose all additional components"
    echo ""
    echo "Available in ALIE:"
    echo ""
    echo "X11 Window Managers:"
    echo "  - i3 / i3-gaps: Tiling, minimalist, productive"
    echo "  - bspwm: Binary space partitioning tiling"
    echo "  - Openbox: Floating, lightweight, flexible"
    echo "  - Awesome: Dynamic tiling, Lua-configured"
    echo "  - Qtile: Tiling WM written in Python"
    echo "  - Xmonad: Tiling WM written in Haskell"
    echo "  - dwm: Suckless, ultra-minimal (requires patching)"
    echo ""
    echo "Wayland Window Managers:"
    echo "  - Sway: i3-compatible Wayland WM"
    echo "  - Hyprland: Dynamic tiling Wayland WM"
    echo "  - River: Wayland WM with Zig"
    echo "  - Niri: Scrollable tiling Wayland WM"
    echo "  - Labwc: Wayland Openbox"
    echo ""
    echo "Pros:"
    echo "  + Extremely lightweight (~50-200MB RAM)"
    echo "  + Maximum customization and control"
    echo "  + Keyboard-centric workflow"
    echo "  + Learn system internals"
    echo ""
    echo "Cons:"
    echo "  - Steep learning curve"
    echo "  - Manual configuration required"
    echo "  - Need to choose all components (terminal, file manager, etc.)"
    echo "  - Not beginner-friendly"
    echo ""
    read -r -p "Press Enter to continue..."
}

show_skip_info() {
    clear
    echo "============================================"
    echo "  Skip Graphical Environment"
    echo "============================================"
    echo ""
    echo "Why skip?"
    echo "  - Server installation (no GUI needed)"
    echo "  - Minimal system (TTY only)"
    echo "  - Custom installation later"
    echo "  - Testing/development environment"
    echo ""
    echo "What happens:"
    echo "  - System remains in TTY (text mode)"
    echo "  - You can install DE/WM manually later"
    echo "  - All CLI tools are still available"
    echo ""
    read -r -p "Press Enter to continue..."
}

################################################################################
# MENU SYSTEM
################################################################################

show_main_menu() {
    clear
    echo "============================================"
    echo "  ALIE Desktop Selection"
    echo "============================================"
    echo ""
    echo "Choose your graphical environment:"
    echo ""
    echo "  1) Desktop Environment (DE)"
    echo "     Full graphical experience (Cinnamon, GNOME, KDE, XFCE4)"
    echo ""
    echo "  2) Window Manager - X11"
    echo "     Minimal, customizable X11 WM (i3, bspwm, Awesome, Qtile, etc.)"
    echo ""
    echo "  3) Window Manager - Wayland"
    echo "     Modern Wayland WM (Sway, Hyprland, River, Niri, Labwc)"
    echo ""
    echo "  4) Skip (No GUI)"
    echo "     Continue without graphical environment"
    echo ""
    echo "  i) More information"
    echo "  0) Exit"
    echo ""
    echo "============================================"
    echo ""
}

show_info_menu() {
    clear
    echo "============================================"
    echo "  Information Menu"
    echo "============================================"
    echo ""
    echo "  1) What is a Desktop Environment?"
    echo "  2) What is a Window Manager?"
    echo "  3) Why skip graphical environment?"
    echo ""
    echo "  0) Back to main menu"
    echo ""
    echo "============================================"
    echo ""
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    require_root
    
    log_section "ALIE Desktop Selection"
    
    while true; do
        show_main_menu
        read -r -p "Select option: " choice
        
        case $choice in
            1)
                log_info "Launching Desktop Environment installer..."
                exec "${SCRIPT_DIR}/221-desktop-environment.sh"
                ;;
            2)
                log_info "Launching X11 Window Manager installer..."
                exec "${SCRIPT_DIR}/222-window-manager.sh"
                ;;
            3)
                log_info "Launching Wayland Window Manager installer..."
                exec "${SCRIPT_DIR}/223-wayland-wm.sh"
                ;;
            4)
                log_info "Skipping graphical environment installation"
                log_success "You can install DE/WM later by running:"
                log_info "  - Desktop Environment: ${SCRIPT_DIR}/221-desktop-environment.sh"
                log_info "  - X11 Window Manager: ${SCRIPT_DIR}/222-window-manager.sh"
                log_info "  - Wayland Window Manager: ${SCRIPT_DIR}/223-wayland-wm.sh"
                exit 0
                ;;
            i|I)
                while true; do
                    show_info_menu
                    read -r -p "Select option: " info_choice
                    
                    case $info_choice in
                        1) show_de_info ;;
                        2) show_wm_info ;;
                        3) show_skip_info ;;
                        0) break ;;
                        *) 
                            log_error "Invalid option"
                            sleep 1
                            ;;
                    esac
                done
                ;;
            0)
                log_info "Exiting desktop selection"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Run main function
main "$@"
