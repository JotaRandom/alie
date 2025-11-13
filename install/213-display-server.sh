#!/bin/bash
# ALIE Interactive Display Server Installation
# Choose between Xorg, Wayland, or both display servers
# This script should be run after user setup, as root
#
# ⚠️ WARNING: EXPERIMENTAL SCRIPT
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

# Information about the script
SCRIPT_NAME="Interactive Display Server Installation"
SCRIPT_DESC="Choose and install Xorg, Wayland, or both display servers with graphics drivers"

print_section_header "$SCRIPT_NAME" "$SCRIPT_DESC"

# Trap cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Display server installation failed!"
    fi
}
trap cleanup EXIT

# ============================================================================
# INTERACTIVE MENU FUNCTIONS
# ============================================================================

# Show main menu and get user selection
show_main_menu() {
    clear
    echo ""
    print_section_header "Display Server Selection" "Choose your graphics environment"
    echo ""
    
    # Detect hardware first
    print_info "🔍 Detected Hardware:"
    local gpu_info=$(lspci 2>/dev/null | grep -E "(VGA|3D|Display)" || echo "Could not detect GPU")
    echo "  GPU: $gpu_info"
    echo ""
    
    print_info "📺 Available options:"
    echo ""
    echo "  ${CYAN}1.${NC} 🖥️  Xorg Only              - Traditional X11 server (stable, mature)"
    echo "  ${CYAN}2.${NC} 🌊 Wayland Only          - Modern display protocol (core only)"
    echo "  ${CYAN}3.${NC} 🔄 Both Xorg + Wayland   - Maximum compatibility (recommended)"
    echo ""
    echo "  ${CYAN}4.${NC} ⚙️  Custom Xorg           - Select X11 components manually"
    echo "  ${CYAN}5.${NC} ⚙️  Custom Wayland        - Select Wayland components manually"
    echo ""
    echo "  ${CYAN}I.${NC} ℹ️  Information            - About each option"
    echo "  ${CYAN}Q.${NC} ❌ Quit                   - Exit without installing"
    echo ""
}

# Show information about each option
show_information() {
    clear
    echo ""
    print_section_header "Display Server Information" "Learn about each option"
    echo ""
    
    echo "🖥️  ${CYAN}XORG (X11)${NC}"
    echo "   • Mature, stable technology (40+ years)"
    echo "   • Excellent compatibility with older software"
    echo "   • Better support for NVIDIA proprietary drivers"
    echo "   • Network transparency (remote X)"
    echo "   • Standard for most desktop environments"
    echo ""
    
    echo "🌊 ${CYAN}WAYLAND${NC}"  
    echo "   • Modern display protocol (better security)"
    echo "   • Better performance and lower latency"
    echo "   • Built-in compositing (smoother graphics)"
    echo "   • Better multi-monitor support"
    echo "   • Energy efficient for laptops"
    echo "   • Note: Compositors (Sway, etc.) installed separately"
    echo ""
    
    echo "🔄 ${CYAN}BOTH${NC}"
    echo "   • Maximum compatibility - switch as needed"
    echo "   • Use Wayland with modern apps, X11 for legacy"
    echo "   • Future-proof your system"
    echo "   • Recommended for most users"
    echo ""
    
    echo "ℹ️  ${CYAN}SCOPE NOTE${NC}"
    echo "   • This script installs display SERVER protocols only"
    echo "   • Desktop environments (GNOME, KDE) installed separately"
    echo "   • Window managers (Sway, i3) installed separately"
    echo "   • Use 214-desktop-env.sh for compositors and DE"
    echo ""
    
    printf "${YELLOW}Press Enter to return to menu...${NC}"
    read
}

# Get user selection
get_display_selection() {
    local input
    
    while true; do
        show_main_menu
        
        printf "${CYAN}Select option [1-5, I, Q]: ${NC}"
        read -r input
        
        case "$input" in
            1)
                echo "xorg-only"
                return 0
                ;;
            2)
                echo "wayland-only" 
                return 0
                ;;
            3)
                echo "both"
                return 0
                ;;
            4)
                echo "custom-xorg"
                return 0
                ;;
            5)
                echo "custom-wayland"
                return 0
                ;;
            [iI])
                show_information
                ;;
            [qQ])
                print_info "Installation cancelled by user."
                exit 0
                ;;
            *)
                print_warning "Invalid option. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Confirm installation
confirm_installation() {
    local selection="$1"
    local description=""
    
    case "$selection" in
        "xorg-only") description="Xorg (X11) display server only" ;;
        "wayland-only") description="Wayland display server only" ;;
        "both") description="Both Xorg and Wayland display servers" ;;
        "custom-xorg") description="Custom Xorg installation" ;;
        "custom-wayland") description="Custom Wayland installation" ;;
    esac
    
    echo ""
    print_info "You selected: ${CYAN}$description${NC}"
    echo ""
    
    while true; do
        printf "${YELLOW}Proceed with installation? (y/N): ${NC}"
        read -r confirm
        case "$confirm" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            [nN]|[nN][oO]|"")
                print_info "Installation cancelled."
                exit 0
                ;;
            *)
                print_warning "Please answer yes (y) or no (n)."
                ;;
        esac
    done
}

# ============================================================================
# GRAPHICS DRIVER FUNCTIONS
# ============================================================================

# Detect and configure graphics drivers
configure_graphics_drivers() {
    print_step "Configuring Graphics Drivers"
    
    print_info "Detecting graphics hardware..."
    
    local gpu_info=$(lspci | grep -E "(VGA|3D|Display)")
    print_info "Detected graphics hardware:"
    echo "$gpu_info"
    echo ""
    
    local GRAPHICS_PACKAGES=("mesa")  # Base Mesa for all
    
    # Detect and add specific drivers
    if echo "$gpu_info" | grep -qi "nvidia"; then
        print_info "NVIDIA GPU detected"
        echo "Choose NVIDIA driver:"
        echo "  1) nvidia (latest proprietary driver)"
        echo "  2) nvidia-lts (LTS kernel driver)"
        echo "  3) nouveau (open source, basic functionality)"
        
        read -p "Choose driver [1-3] (default: 1): " nvidia_choice
        nvidia_choice=${nvidia_choice:-1}
        
        case $nvidia_choice in
            1) GRAPHICS_PACKAGES+=("nvidia" "nvidia-utils") ;;
            2) GRAPHICS_PACKAGES+=("nvidia-lts" "nvidia-utils") ;;
            3) GRAPHICS_PACKAGES+=("xf86-video-nouveau") ;;
        esac
        
        # Add 32-bit support for gaming/compatibility
        GRAPHICS_PACKAGES+=("lib32-mesa")
        if [[ $nvidia_choice -eq 1 ]] || [[ $nvidia_choice -eq 2 ]]; then
            GRAPHICS_PACKAGES+=("lib32-nvidia-utils")
        fi
    fi
    
    if echo "$gpu_info" | grep -qi "amd\\|radeon"; then
        print_info "AMD GPU detected - using open source drivers"
        GRAPHICS_PACKAGES+=("xf86-video-amdgpu" "vulkan-radeon" "lib32-vulkan-radeon")
        GRAPHICS_PACKAGES+=("lib32-mesa")
    fi
    
    if echo "$gpu_info" | grep -qi "intel"; then
        print_info "Intel GPU detected - using open source drivers"
        GRAPHICS_PACKAGES+=("xf86-video-intel" "vulkan-intel" "lib32-vulkan-intel")
        GRAPHICS_PACKAGES+=("lib32-mesa")
    fi
    
    # Install graphics packages
    print_info "Installing graphics drivers: ${GRAPHICS_PACKAGES[*]}"
    run_privileged "pacman -S --needed --noconfirm ${GRAPHICS_PACKAGES[*]}"
    
    print_success "Graphics drivers configured"
}

# ============================================================================
# XORG INSTALLATION FUNCTIONS
# ============================================================================

# Install complete Xorg
install_xorg_complete() {
    print_step "Installing Complete Xorg Display Server"
    
    local XORG_COMPLETE=(
        # Core X11 server
        "xorg-server"           # Main X server
        "xorg-xauth"            # X authentication
        "xorg-xinit"            # X initialization
        
        # Essential X11 utilities
        "xorg-xrandr"           # Display configuration
        "xorg-xset"             # X settings
        "xorg-xsetroot"         # Root window settings
        "xorg-xprop"            # Window properties
        "xorg-xwininfo"         # Window information
        "xorg-xkill"            # Force close windows
        "xorg-xev"              # Event tester
        "xorg-xdpyinfo"         # Display information
        
        # Additional useful tools
        "xorg-xmodmap"          # Keyboard mapping
        "xorg-xrdb"             # Resource database
        "xorg-xhost"            # Access control
        "xorg-xrefresh"         # Screen refresh
        "xorg-xlsclients"       # List clients
        "xorg-xvinfo"           # Video extension info
        
        # Clipboard and session
        "xclip"                 # Clipboard utility
        "xsel"                  # Selection utility
        
        # Fonts
        "xorg-fonts-misc"       # Miscellaneous fonts
        "ttf-dejavu"            # DejaVu fonts
        "ttf-liberation"        # Liberation fonts
    )
    
    print_info "Installing complete Xorg with utilities..."
    run_privileged "pacman -S --needed --noconfirm ${XORG_COMPLETE[*]}"
    
    print_success "Complete Xorg installation finished"
}

# Install minimal Xorg
install_xorg_minimal() {
    print_step "Installing Minimal Xorg Display Server"
    
    local XORG_MINIMAL=(
        "xorg-server"           # Main X server
        "xorg-xauth"            # X authentication
        "xorg-xinit"            # X initialization
        "xorg-xrandr"           # Display configuration
    )
    
    print_info "Installing minimal Xorg..."
    run_privileged "pacman -S --needed --noconfirm ${XORG_MINIMAL[*]}"
    
    print_success "Minimal Xorg installation finished"
}

# Custom Xorg selection
install_xorg_custom() {
    print_step "Custom Xorg Installation"
    
    local categories=()
    local input
    
    clear
    echo ""
    print_info "🛠️  Custom Xorg Components:"
    echo ""
    echo "  ${CYAN}1.${NC} Core X Server         (xorg-server, xauth, xinit)"
    echo "  ${CYAN}2.${NC} Display Tools        (xrandr, xset, xdpyinfo)"  
    echo "  ${CYAN}3.${NC} Window Tools         (xprop, xwininfo, xkill, xev)"
    echo "  ${CYAN}4.${NC} Input Tools          (xmodmap, xinput)"
    echo "  ${CYAN}5.${NC} Clipboard Tools      (xclip, xsel)"
    echo "  ${CYAN}6.${NC} Fonts Package        (xorg-fonts, ttf-dejavu)"
    echo "  ${CYAN}7.${NC} Development Tools    (xrdb, xhost, xlsclients)"
    echo ""
    
    while true; do
        if [ ${#categories[@]} -gt 0 ]; then
            print_info "Selected: $(printf "%s " "${categories[@]}")"
            echo ""
        fi
        
        printf "${CYAN}Select categories (1-7), 'I' to install, 'Q' to quit: ${NC}"
        read -r input
        
        case "$input" in
            [1-7])
                if [[ " ${categories[*]} " =~ " $input " ]]; then
                    categories=($(printf '%s\n' "${categories[@]}" | grep -v "^$input$"))
                else
                    categories+=("$input")
                fi
                ;;
            [iI])
                if [ ${#categories[@]} -eq 0 ]; then
                    print_warning "No categories selected."
                    read -p "Press Enter to continue..."
                else
                    break
                fi
                ;;
            [qQ])
                return 1
                ;;
            *)
                print_warning "Invalid option."
                read -p "Press Enter to continue..."
                ;;
        esac
        
        clear
        echo ""
        print_info "🛠️  Custom Xorg Components:"
        echo ""
        echo "  ${CYAN}1.${NC} Core X Server         (xorg-server, xauth, xinit)"
        echo "  ${CYAN}2.${NC} Display Tools        (xrandr, xset, xdpyinfo)"  
        echo "  ${CYAN}3.${NC} Window Tools         (xprop, xwininfo, xkill, xev)"
        echo "  ${CYAN}4.${NC} Input Tools          (xmodmap, xinput)"
        echo "  ${CYAN}5.${NC} Clipboard Tools      (xclip, xsel)"
        echo "  ${CYAN}6.${NC} Fonts Package        (xorg-fonts, ttf-dejavu)"
        echo "  ${CYAN}7.${NC} Development Tools    (xrdb, xhost, xlsclients)"
        echo ""
    done
    
    # Install selected components
    local XORG_PACKAGES=()
    
    for category in "${categories[@]}"; do
        case "$category" in
            1)
                XORG_PACKAGES+=("xorg-server" "xorg-xauth" "xorg-xinit")
                ;;
            2)
                XORG_PACKAGES+=("xorg-xrandr" "xorg-xset" "xorg-xdpyinfo" "xorg-xsetroot")
                ;;
            3)
                XORG_PACKAGES+=("xorg-xprop" "xorg-xwininfo" "xorg-xkill" "xorg-xev")
                ;;
            4)
                XORG_PACKAGES+=("xorg-xmodmap" "xorg-xinput")
                ;;
            5)
                XORG_PACKAGES+=("xclip" "xsel")
                ;;
            6)
                XORG_PACKAGES+=("xorg-fonts-misc" "ttf-dejavu" "ttf-liberation")
                ;;
            7)
                XORG_PACKAGES+=("xorg-xrdb" "xorg-xhost" "xorg-xlsclients" "xorg-xvinfo")
                ;;
        esac
    done
    
    print_info "Installing selected Xorg components..."
    run_privileged "pacman -S --needed --noconfirm ${XORG_PACKAGES[*]}"
    
    print_success "Custom Xorg installation finished"
}

# ============================================================================
# WAYLAND INSTALLATION FUNCTIONS  
# ============================================================================

# Install complete Wayland
install_wayland_complete() {
    print_step "Installing Complete Wayland Display Server"
    
    local WAYLAND_COMPLETE=(
        # Core Wayland protocol
        "wayland"               # Wayland protocol libraries
        "wayland-protocols"     # Protocol extensions
        
        # Core infrastructure
        "wlroots"               # Compositor library (needed for most compositors)
        "seatd"                 # Seat management daemon
        
        # Essential utilities
        "wl-clipboard"          # Clipboard utilities for Wayland
        "xwayland"              # X11 compatibility layer
        
        # Basic tools (minimal set)
        "waybar"                # Status bar (can be used by many compositors)
    )
    
    print_info "Installing core Wayland infrastructure..."
    run_privileged "pacman -S --needed --noconfirm ${WAYLAND_COMPLETE[*]}"
    
    print_success "Core Wayland installation finished"
}

# Install minimal Wayland
install_wayland_minimal() {
    print_step "Installing Minimal Wayland Display Server"
    
    local WAYLAND_MINIMAL=(
        "wayland"               # Wayland protocol
        "wayland-protocols"     # Protocol extensions  
        "seatd"                 # Seat management
        "xwayland"              # X11 compatibility
    )
    
    print_info "Installing minimal Wayland protocol..."
    run_privileged "pacman -S --needed --noconfirm ${WAYLAND_MINIMAL[*]}"
    
    print_success "Minimal Wayland installation finished"
}

# Custom Wayland selection
install_wayland_custom() {
    print_step "Custom Wayland Installation"
    
    local categories=()
    local input
    
    clear
    echo ""
    print_info "🌊 Custom Wayland Components:"
    echo ""
    echo "  ${CYAN}1.${NC} Core Wayland         (wayland, protocols, seatd)"
    echo "  ${CYAN}2.${NC} Compositor Library   (wlroots - needed for most compositors)"
    echo "  ${CYAN}3.${NC} Basic Utilities      (waybar status bar, wl-clipboard)"
    echo "  ${CYAN}4.${NC} X11 Compatibility    (xwayland)"
    echo "  ${CYAN}5.${NC} Development Tools    (wayland-scanner, pkg-config)"
    echo ""
    
    while true; do
        if [ ${#categories[@]} -gt 0 ]; then
            print_info "Selected: $(printf "%s " "${categories[@]}")"
            echo ""
        fi
        
        printf "${CYAN}Select categories (1-7), 'I' to install, 'Q' to quit: ${NC}"
        read -r input
        
        case "$input" in
            [1-5])
                if [[ " ${categories[*]} " =~ " $input " ]]; then
                    categories=($(printf '%s\n' "${categories[@]}" | grep -v "^$input$"))
                else
                    categories+=("$input")
                fi
                ;;
            [iI])
                if [ ${#categories[@]} -eq 0 ]; then
                    print_warning "No categories selected."
                    read -p "Press Enter to continue..."
                else
                    break
                fi
                ;;
            [qQ])
                return 1
                ;;
            *)
                print_warning "Invalid option."
                read -p "Press Enter to continue..."
                ;;
        esac
        
        clear
        echo ""
        print_info "🌊 Custom Wayland Components:"
        echo ""
        echo "  ${CYAN}1.${NC} Core Wayland         (wayland, protocols, seatd)"
        echo "  ${CYAN}2.${NC} Compositor Library   (wlroots - needed for most compositors)"
        echo "  ${CYAN}3.${NC} Basic Utilities      (waybar status bar, wl-clipboard)"
        echo "  ${CYAN}4.${NC} X11 Compatibility    (xwayland)"
        echo "  ${CYAN}5.${NC} Development Tools    (wayland-scanner, pkg-config)"
        echo ""
    done
    
    # Install selected components
    local WAYLAND_PACKAGES=()
    
    for category in "${categories[@]}"; do
        case "$category" in
            1)
                WAYLAND_PACKAGES+=("wayland" "wayland-protocols" "seatd")
                ;;
            2)
                WAYLAND_PACKAGES+=("wlroots")
                ;;
            3)
                WAYLAND_PACKAGES+=("waybar" "wl-clipboard")
                ;;
            4)
                WAYLAND_PACKAGES+=("xwayland")
                ;;
            5)
                WAYLAND_PACKAGES+=("wayland-scanner" "pkgconf")
                ;;
        esac
    done
    
    print_info "Installing selected Wayland components..."
    run_privileged "pacman -S --needed --noconfirm ${WAYLAND_PACKAGES[*]}"
    
    print_success "Custom Wayland installation finished"
}

# ============================================================================
# MAIN INSTALLATION LOGIC
# ============================================================================

# Main execution
main() {
    # Validate environment
    validate_root_environment
    
    print_success "Environment validation completed"
    
    # Get user selection
    selection=$(get_display_selection)
    
    # Confirm installation  
    confirm_installation "$selection"
    
    # Install graphics drivers first
    configure_graphics_drivers
    
    # Install based on selection
    case "$selection" in
        "xorg-only")
            install_xorg_complete
            ;;
        "wayland-only")
            install_wayland_complete
            ;;
        "both")
            install_xorg_complete
            install_wayland_complete
            ;;
        "custom-xorg")
            install_xorg_custom || {
                print_warning "Custom Xorg installation cancelled"
                exit 0
            }
            ;;
        "custom-wayland")
            install_wayland_custom || {
                print_warning "Custom Wayland installation cancelled"
                exit 0
            }
            ;;
    esac
    
    # Mark progress
    save_progress "06-display-server-installed"
    
    print_section_footer "Display Server Installation Completed"
    
    # Show summary
    echo ""
    print_success "Display server installation completed!"
    echo ""
    
    case "$selection" in
        "xorg-only")
            echo "✅ ${CYAN}Xorg (X11)${NC} display server installed"
            echo "   • Traditional, stable graphics environment"
            echo "   • Compatible with all desktop environments"
            ;;
        "wayland-only") 
            echo "✅ ${CYAN}Wayland${NC} display server installed"
            echo "   • Modern, secure graphics protocol"
            echo "   • Better performance and security"
            ;;
        "both")
            echo "✅ ${CYAN}Both Xorg and Wayland${NC} installed"
            echo "   • Maximum compatibility and flexibility"
            echo "   • Switch between protocols as needed"
            ;;
        "custom-xorg")
            echo "✅ ${CYAN}Custom Xorg${NC} components installed"
            echo "   • Selected components based on your needs"
            ;;
        "custom-wayland")
            echo "✅ ${CYAN}Custom Wayland${NC} components installed"
            echo "   • Selected components based on your needs"
            ;;
    esac
    
    echo ""
    print_info "Next steps:"
    echo "  ${CYAN}1.${NC} Install desktop environment: ${YELLOW}bash install/214-desktop-env.sh${NC}"
    echo "  ${CYAN}2.${NC} Or install Cinnamon directly: ${YELLOW}bash install/221-desktop-install.sh${NC}"
    echo "  ${CYAN}3.${NC} Configure display manager and graphics"
    echo "  ${CYAN}4.${NC} Reboot to test graphics system"
    echo ""
    print_info "Note: Desktop environments and compositors are installed separately"
}

# Run main function
main "$@"