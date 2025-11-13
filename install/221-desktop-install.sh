#!/bin/bash
# ALIE Desktop Environment Installation
# This script installs the complete desktop environment (Cinnamon + LightDM)
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
SCRIPT_NAME="Desktop Environment Installation"
SCRIPT_DESC="Installs Cinnamon desktop environment with LightDM display manager"

print_section_header "$SCRIPT_NAME" "$SCRIPT_DESC"

# Trap cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Desktop installation failed!"
    fi
}
trap cleanup EXIT

# Function to detect and configure graphics drivers
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
    
    if echo "$gpu_info" | grep -qi "amd\|radeon"; then
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
    run_with_retry "pacman -S --needed --noconfirm ${GRAPHICS_PACKAGES[*]}"
    
    print_success "Graphics drivers configured"
}

# Install X11/Xorg display server
install_display_server() {
    print_step "Installing Display Server (X11)"
    
    local XORG_PACKAGES=(
        "xorg-server"           # Main X server
        "xorg-xauth"            # X authentication
        "xorg-xinit"            # X initialization
        "xorg-xrandr"           # Display configuration
        "xorg-xset"             # X settings
        "xorg-xsetroot"         # Root window settings
        "xorg-xprop"            # Window properties
        "xorg-xwininfo"         # Window information
        "xorg-xkill"            # Force close windows
        "xterm"                 # Basic terminal
    )
    
    print_info "Installing Xorg display server..."
    run_with_retry "pacman -S --needed --noconfirm ${XORG_PACKAGES[*]}"
    
    print_success "Display server installed"
}

# Install Cinnamon desktop environment
install_cinnamon_desktop() {
    print_step "Installing Cinnamon Desktop Environment"
    
    local CINNAMON_PACKAGES=(
        # Core Cinnamon
        "cinnamon"                    # Main desktop environment
        "cinnamon-translations"       # Language support
        
        # Display manager
        "lightdm"                     # Display manager
        "lightdm-slick-greeter"       # Modern greeter
        
        # Essential applications
        "gnome-terminal"              # Terminal emulator
        "nemo"                        # File manager (part of cinnamon)
        "nemo-fileroller"             # Archive support for Nemo
        "file-roller"                 # Archive manager
        
        # System tools
        "gnome-system-monitor"        # Task manager
        "gnome-calculator"            # Calculator
        "gnome-screenshot"            # Screenshot tool
        
        # Settings and configuration
        "gnome-keyring"               # Password management
        "network-manager-applet"      # Network management GUI
        
        # Audio
        "pulseaudio"                  # Audio system
        "pulseaudio-alsa"             # ALSA integration
        "pavucontrol"                 # Audio control
        
        # Fonts
        "ttf-dejavu"                  # Standard fonts
        "ttf-liberation"              # MS Office compatible fonts
        "noto-fonts"                  # Google fonts with wide language support
        
        # Utilities
        "xdg-user-dirs-gtk"           # User directory management
        "gvfs"                        # Virtual file system
        "gvfs-smb"                    # SMB/Windows share support
        "gvfs-mtp"                    # Mobile device support
    )
    
    print_info "Installing Cinnamon desktop packages..."
    run_with_retry "pacman -S --needed --noconfirm ${CINNAMON_PACKAGES[*]}"
    
    print_success "Cinnamon desktop installed"
}

# Configure LightDM display manager
configure_lightdm() {
    print_step "Configuring LightDM Display Manager"
    
    local lightdm_conf="/etc/lightdm/lightdm.conf"
    
    # Backup original config if not already backed up
    if [ ! -f "${lightdm_conf}.alie.bak" ]; then
        cp "$lightdm_conf" "${lightdm_conf}.alie.bak"
        print_info "LightDM configuration backed up"
    fi
    
    print_info "Configuring LightDM with Slick Greeter..."
    
    # Configure greeter
    if grep -q "^#greeter-session=" "$lightdm_conf"; then
        sed -i 's/^#greeter-session=.*/greeter-session=lightdm-slick-greeter/' "$lightdm_conf"
    elif grep -q "^greeter-session=" "$lightdm_conf"; then
        sed -i 's/^greeter-session=.*/greeter-session=lightdm-slick-greeter/' "$lightdm_conf"
    else
        # Add greeter-session if it doesn't exist
        sed -i '/^\[Seat:\*\]/a greeter-session=lightdm-slick-greeter' "$lightdm_conf"
    fi
    
    # Enable automatic login option (commented by default)
    # Users can uncomment and configure this later if desired
    cat >> "$lightdm_conf" << 'EOF'

# Automatic login (uncomment and configure if desired)
# autologin-user=username
# autologin-user-timeout=0
EOF
    
    # Configure Slick Greeter
    local slick_conf="/etc/lightdm/slick-greeter.conf"
    print_info "Configuring Slick Greeter appearance..."
    
    cat > "$slick_conf" << 'EOF'
[Greeter]
# Appearance
theme-name=Adwaita-dark
icon-theme-name=Adwaita
cursor-theme-name=Adwaita
font-name=Cantarell 11

# Background
background=/usr/share/pixmaps/arch-logo.png
background-color=#2e3436
user-background=true

# Features
show-hostname=true
show-power=true
show-a11y=true
show-keyboard=true
show-clock=true
clock-format=%H:%M

# Session selection
show-session=true

# Accessibility
high-contrast=false
screen-reader=false
EOF
    
    # Verify LightDM configuration
    if lightdm --test-mode --config="$lightdm_conf" 2>/dev/null; then
        print_success "LightDM configuration is valid"
    else
        print_warning "LightDM configuration test failed, but continuing..."
    fi
    
    print_success "LightDM configured"
}

# Enable desktop services
enable_desktop_services() {
    print_step "Enabling Desktop Services"
    
    # Enable LightDM
    print_info "Enabling LightDM display manager..."
    if systemctl enable lightdm; then
        print_success "LightDM enabled"
    else
        print_error "Failed to enable LightDM"
        exit 1
    fi
    
    # Set graphical target as default
    if systemctl get-default | grep -q "graphical.target"; then
        print_success "Graphical target already set"
    else
        print_info "Setting default target to graphical..."
        systemctl set-default graphical.target
        print_success "Default target set to graphical"
    fi
    
    # Enable other useful services
    local DESKTOP_SERVICES=(
        "cups"                  # Printing service
        "bluetooth"             # Bluetooth support
    )
    
    for service in "${DESKTOP_SERVICES[@]}"; do
        # Only enable if the package is installed
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            if systemctl enable "$service" 2>/dev/null; then
                print_info "$service service enabled"
            fi
        fi
    done
    
    print_success "Desktop services configured"
}

# Configure desktop environment for existing user
configure_user_desktop() {
    print_step "Configuring User Desktop Environment"
    
    # Load user information from previous setup
    load_system_config
    
    if [ -z "${DESKTOP_USER:-}" ]; then
        # Try to load from install info
        DESKTOP_USER=$(get_install_info "DESKTOP_USER" 2>/dev/null || echo "")
        
        if [ -z "$DESKTOP_USER" ]; then
            print_error "No desktop user found in configuration"
            print_info "Please run 201-user-setup.sh first"
            exit 1
        fi
    fi
    
    print_info "Configuring desktop for user: $DESKTOP_USER"
    
    # Verify user exists
    if ! id "$DESKTOP_USER" &>/dev/null; then
        print_error "User $DESKTOP_USER does not exist"
        print_info "Please run 201-user-setup.sh first"
        exit 1
    fi
    
    # Configure user's desktop directories
    print_info "Setting up desktop directories..."
    su - "$DESKTOP_USER" -c "xdg-user-dirs-update" 2>/dev/null || true
    
    # Create basic desktop configuration
    local user_config="/home/$DESKTOP_USER/.config"
    local cinnamon_config="$user_config/cinnamon"
    
    # Ensure config directories exist with proper ownership
    su - "$DESKTOP_USER" -c "mkdir -p '$cinnamon_config'" 2>/dev/null || true
    
    print_success "User desktop environment configured"
}

# Install additional desktop utilities
install_desktop_utilities() {
    print_step "Installing Desktop Utilities"
    
    local UTILITY_PACKAGES=(
        # Image viewers and editors
        "eog"                     # Eye of GNOME image viewer
        "imagemagick"             # Command-line image editing
        
        # Media players
        "vlc"                     # Video player
        
        # Archive tools
        "p7zip"                   # 7-Zip support
        "unrar"                   # RAR support
        
        # System utilities
        "gparted"                 # Partition editor
        "baobab"                  # Disk usage analyzer
        
        # Hardware support
        "cups"                    # Printing support
        "system-config-printer"   # Printer configuration GUI
        "bluez"                   # Bluetooth support
        "bluez-utils"             # Bluetooth utilities
        "pulseaudio-bluetooth"    # Bluetooth audio
        
        # Input methods and accessibility
        "onboard"                 # On-screen keyboard
        "orca"                    # Screen reader
    )
    
    print_info "Installing desktop utilities..."
    
    # Install packages that are available
    for package in "${UTILITY_PACKAGES[@]}"; do
        if pacman -Ss "^${package}$" &>/dev/null; then
            if ! pacman -Qq "$package" &>/dev/null; then
                print_info "Installing: $package"
                run_with_retry "pacman -S --needed --noconfirm $package"
            fi
        else
            print_warning "Package $package not found in repositories, skipping"
        fi
    done
    
    print_success "Desktop utilities installed"
}

# ============================================================================
# DISPLAY SERVER VERIFICATION
# ============================================================================

# Check if display server is already installed
check_display_server() {
    local has_xorg=false
    local has_wayland=false
    
    # Check for Xorg
    if command -v Xorg >/dev/null 2>&1 || pacman -Qq xorg-server >/dev/null 2>&1; then
        has_xorg=true
    fi
    
    # Check for Wayland
    if command -v sway >/dev/null 2>&1 || pacman -Qq wayland >/dev/null 2>&1; then
        has_wayland=true
    fi
    
    if [ "$has_xorg" = false ] && [ "$has_wayland" = false ]; then
        print_warning "No display server (Xorg or Wayland) detected!"
        echo ""
        print_info "📺 You need to install a display server first:"
        echo "   ${CYAN}→ Run:${NC} ${YELLOW}bash install/213-display-server.sh${NC}"
        echo ""
        print_info "213-display-server.sh offers:"
        echo "   • 🖥️  Xorg only (traditional, stable)"
        echo "   • 🌊 Wayland only (modern, secure)"
        echo "   • 🔄 Both Xorg + Wayland (maximum compatibility)"
        echo "   • ⚙️  Custom installation options"
        echo ""
        
        while true; do
            printf "${YELLOW}Continue without display server? (not recommended) (y/N): ${NC}"
            read -r continue_anyway
            case "$continue_anyway" in
                [yY]|[yY][eE][sS])
                    print_warning "Continuing without display server - desktop may not work!"
                    return 0
                    ;;
                [nN]|[nN][oO]|"")
                    print_info "Run 213-display-server.sh first, then return to this script."
                    exit 0
                    ;;
                *)
                    print_warning "Please answer yes (y) or no (n)."
                    ;;
            esac
        done
    fi
    
    # Show detected display servers
    if [ "$has_xorg" = true ] && [ "$has_wayland" = true ]; then
        print_success "✅ Both Xorg and Wayland detected"
        print_info "Desktop will be configured for maximum compatibility"
    elif [ "$has_xorg" = true ]; then
        print_success "✅ Xorg display server detected"
        print_info "Desktop will use traditional X11 graphics"
    elif [ "$has_wayland" = true ]; then
        print_success "✅ Wayland display server detected"  
        print_info "Desktop will use modern Wayland graphics"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Main script start
show_alie_banner
show_warning_banner

print_info "This script will install:"
echo "  ✅ Graphics drivers (auto-detected)"
echo "  ✅ Cinnamon desktop environment"
echo "  ✅ LightDM display manager with Slick Greeter"
echo "  ✅ Essential desktop applications"
echo "  ✅ Audio system (PulseAudio)"
echo "  ✅ Desktop utilities and tools"
echo ""
echo "ℹ️  Note: Display server (Xorg/Wayland) should be installed first"
echo "         Use ${YELLOW}213-display-server.sh${NC} to choose your graphics system"
echo ""
read -p "Press Enter to continue or Ctrl+C to exit..."

# Validate environment
print_step "STEP 1: Environment Validation"

# Verify running as root
require_root

# Verify we're on Arch Linux
verify_arch_linux

# Verify we're not in a chroot
verify_not_chroot

# Verify internet connectivity
verify_internet

# Check display server installation
check_display_server

# Check if user setup was completed
if ! check_progress "03-user-setup-completed"; then
    print_error "User setup not completed"
    print_info "Please run 201-user-setup.sh first"
    exit 1
fi

print_success "Environment validation completed"

# Display server installation is now handled by 213-display-server.sh
# If no display server is detected, the check_display_server() function above
# will guide the user to run 213-display-server.sh first

# Configure graphics drivers (if not already configured by 213)
if ! check_progress "06-display-server-installed"; then
    print_info "No display server installation progress found"
    print_info "Graphics drivers may need to be configured manually"
    configure_graphics_drivers
else
    print_success "Display server already configured - skipping graphics driver setup"
fi

# Install Cinnamon desktop environment
install_cinnamon_desktop

# Configure LightDM display manager
configure_lightdm

# Enable desktop services
enable_desktop_services

# Configure desktop for user
configure_user_desktop

# Install additional desktop utilities
install_desktop_utilities

# Mark progress
save_progress "04-desktop-installed"

print_section_footer "Desktop Environment Installation Completed"

echo ""
print_success "Desktop environment installation completed!"
echo ""

# Detect installed display servers for summary
local display_summary="Unknown"
if command -v Xorg >/dev/null 2>&1 && command -v sway >/dev/null 2>&1; then
    display_summary="Xorg + Wayland"
elif command -v Xorg >/dev/null 2>&1; then
    display_summary="Xorg"
elif command -v sway >/dev/null 2>&1; then
    display_summary="Wayland"
fi

print_info "Summary:"
echo "  • Display server: ${CYAN}${display_summary}${NC}"
echo "  • Desktop environment: ${CYAN}Cinnamon${NC}"
echo "  • Display manager: ${CYAN}LightDM with Slick Greeter${NC}"
echo "  • Audio system: ${CYAN}PulseAudio${NC}"
echo "  • User: ${CYAN}${DESKTOP_USER:-[configured]}${NC}"
echo ""
print_info "Next steps:"
echo "  ${CYAN}1.${NC} Reboot the system: ${YELLOW}reboot${NC}"
echo "  ${CYAN}2.${NC} Login graphically as your user"
echo "  ${CYAN}3.${NC} Install AUR helper: ${YELLOW}bash install/211-install-aur-helper.sh${NC} (as user)"
echo "  ${CYAN}4.${NC} Install CLI tools: ${YELLOW}bash install/212-cli-tools.sh${NC} (as user)"
echo ""
print_warning "Remember: AUR scripts must be run as regular user, NOT as root!"
print_info "The desktop environment will be available after reboot."
echo ""