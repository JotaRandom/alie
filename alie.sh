#!/bin/bash
# ALIE Master Installation Script
# This script detects the environment and runs the appropriate installation script
#
# [WARNING] WARNING: EXPERIMENTAL SCRIPT
# This script is provided AS-IS without warranties.
# Review the code before running and use at your own risk.
# Make sure you have backups of any important data.

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Determine base directory (works regardless of how script is called)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
INSTALL_DIR="$SCRIPT_DIR/install"

# Validate directory structure
if [ ! -d "$LIB_DIR" ]; then
    echo "ERROR: lib/ directory not found at $LIB_DIR"
    echo "Please ensure the script is run from the correct location."
    exit 1
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo "ERROR: install/ directory not found at $INSTALL_DIR"
    echo "Please ensure the script is run from the correct location."
    exit 1
fi

# Validate and load shared functions
if [ ! -f "$LIB_DIR/shared-functions.sh" ]; then
    echo "ERROR: shared-functions.sh not found at $LIB_DIR/shared-functions.sh"
    echo "Cannot continue without shared functions library."
    exit 1
fi

# shellcheck source=lib/shared-functions.sh
source "$LIB_DIR/shared-functions.sh"

# Function to detect environment
detect_environment() {
    # Check if running in chroot
    local root_stat root_proc_stat
    root_stat=$(stat -c %d:%i / 2>/dev/null || true)
    root_proc_stat=$(stat -c %d:%i /proc/1/root/. 2>/dev/null || true)
    if [ "$root_stat" != "$root_proc_stat" ]; then
        echo "chroot"
        return
    fi
    
    # Check if running from live environment
    if grep -q "archiso" /proc/cmdline 2>/dev/null; then
        echo "livecd"
        return
    fi
    
    # Check if system is installed (has /etc/arch-release and not live)
    if [ -f /etc/arch-release ] && [ ! -f /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux ] 2>/dev/null; then
        # Check if desktop is installed
        if systemctl list-unit-files 2>/dev/null | grep -q lightdm.service; then
            echo "installed-desktop"
        else
            echo "installed-base"
        fi
        return
    fi
    
    echo "unknown"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        return 1
    fi
    return 0
}

# Function to show manual selection menu
show_manual_menu() {
    echo ""
    print_step "Manual Script Selection"
    echo ""
    echo "Available installation scripts:"
    echo ""
    echo "  ${CYAN}1)${NC} Disk Partitioning (001-base-install.sh)"
    echo "     ${YELLOW}->${NC} Partition and format disks only"
    echo "     ${YELLOW}->${NC} Requires: Live USB environment, root privileges"
    echo ""
    echo "  ${CYAN}2)${NC} Shell/Editor Selection (002-shell-editor-select.sh)"
    echo "     ${YELLOW}->${NC} Select shells and text editors (OPTIONAL)"
    echo "     ${YELLOW}->${NC} Requires: Live USB environment, root privileges"
    echo ""
    echo "  ${CYAN}3)${NC} System Installation (003-system-install.sh)"
    echo "     ${YELLOW}->${NC} Install base system with pacstrap"
    echo "     ${YELLOW}->${NC} Requires: Partitioned disks, root privileges"
    echo ""
    echo "  ${CYAN}4)${NC} System Configuration (101-configure-system.sh)"
    echo "     ${YELLOW}->${NC} Configure timezone, locale, hostname, GRUB"
    echo "     ${YELLOW}->${NC} Requires: Chroot environment, root privileges"
    echo ""
    echo "  ${CYAN}5)${NC} User Setup (201-user-setup.sh)"
    echo "     ${YELLOW}->${NC} Create desktop user, configure sudo/doas, install basic tools"
    echo "     ${YELLOW}->${NC} Requires: Booted system, root privileges"
    echo ""
    echo "  ${CYAN}6)${NC} AUR Helper Installation (211-install-aur-helper.sh)"
    echo "     ${YELLOW}->${NC} Install universal AUR helper (yay/paru) + optimize makepkg"
    echo "     ${YELLOW}->${NC} Requires: Booted system, regular user (NOT root)"
    echo ""
    echo "  ${CYAN}7)${NC} CLI Tools Selection (212-cli-tools.sh)"
    echo "     ${YELLOW}->${NC} Interactive selection of CLI tools and utilities"
    echo "     ${YELLOW}->${NC} Requires: AUR helper installed, regular user (NOT root)"
    echo ""
    echo "  ${CYAN}8)${NC} Display Server Setup (213-display-server.sh)"
    echo "     ${YELLOW}->${NC} Choose graphics system (Xorg/Wayland/Both)"
    echo "     ${YELLOW}->${NC} Requires: Booted system, root privileges"
    echo ""
    echo "  ${CYAN}9)${NC} Desktop Selection (220-desktop-select.sh)"
    echo "     ${YELLOW}->${NC} Choose: Desktop Environment / Window Manager / Skip"
    echo "     ${YELLOW}->${NC} Requires: Display server installed, root privileges"
    echo ""
    echo "  ${CYAN}A)${NC} Desktop Environment (221-desktop-environment.sh)"
    echo "     ${YELLOW}->${NC} Install Desktop Environments (Cinnamon/GNOME/KDE/XFCE4)"
    echo "     ${YELLOW}->${NC} Requires: Desktop selection made, root privileges"
    echo ""
    echo "  ${CYAN}B)${NC} X11 Window Manager (222-window-manager.sh)"
    echo "     ${YELLOW}->${NC} Install X11 Window Managers (i3/bspwm/Openbox/Awesome/Qtile/Xmonad/dwm)"
    echo "     ${YELLOW}->${NC} Requires: Desktop selection made, root privileges"
    echo ""
    echo "  ${CYAN}C)${NC} Wayland Window Manager (223-wayland-wm.sh)"
    echo "     ${YELLOW}->${NC} Install Wayland Window Managers (Sway/Hyprland/River/Niri/Labwc)"
    echo "     ${YELLOW}->${NC} Requires: Desktop selection made, Wayland installed, root privileges"
    echo ""
    echo "  ${CYAN}D)${NC} Desktop Tools (231-desktop-tools.sh)"
    echo "     ${YELLOW}->${NC} Install apps: LibreOffice, GIMP, Firefox, etc."
    echo "     ${YELLOW}->${NC} Requires: DE/WM installed, root privileges"
    echo ""
    echo "  ${CYAN}X)${NC} Clear progress and exit"
    echo "  ${CYAN}0)${NC} Exit without changes"
    echo ""
    
    read -r -p "Choose script to run [1-9, A-D, X, 0]: " choice
    
    case "$choice" in
        1) RUN_SCRIPT="$INSTALL_DIR/001-base-install.sh"; NEEDS_ROOT=true ;;
        2) RUN_SCRIPT="$INSTALL_DIR/002-shell-editor-select.sh"; NEEDS_ROOT=true ;;
        3) RUN_SCRIPT="$INSTALL_DIR/003-system-install.sh"; NEEDS_ROOT=true ;;
        4) RUN_SCRIPT="$INSTALL_DIR/101-configure-system.sh"; NEEDS_ROOT=true ;;
        5) RUN_SCRIPT="$INSTALL_DIR/201-user-setup.sh"; NEEDS_ROOT=true ;;
        6) RUN_SCRIPT="$INSTALL_DIR/211-install-aur-helper.sh"; NEEDS_ROOT=false ;;
        7) RUN_SCRIPT="$INSTALL_DIR/212-cli-tools.sh"; NEEDS_ROOT=false ;;
        8) RUN_SCRIPT="$INSTALL_DIR/213-display-server.sh"; NEEDS_ROOT=true ;;
        9) RUN_SCRIPT="$INSTALL_DIR/220-desktop-select.sh"; NEEDS_ROOT=true ;;
        [Aa]) RUN_SCRIPT="$INSTALL_DIR/221-desktop-environment.sh"; NEEDS_ROOT=true ;;
        [Bb]) RUN_SCRIPT="$INSTALL_DIR/222-window-manager.sh"; NEEDS_ROOT=true ;;
        [Cc]) RUN_SCRIPT="$INSTALL_DIR/223-wayland-wm.sh"; NEEDS_ROOT=true ;;
        [Dd]) RUN_SCRIPT="$INSTALL_DIR/231-desktop-tools.sh"; NEEDS_ROOT=true ;;
        [Xx])
            print_warning "This will clear all progress markers"
            read -r -p "Are you sure? (yes/no): " confirm
            if [ "${confirm:-}" = "yes" ]; then
                clear_progress
                print_info "Progress cleared"
            fi
            return 0
            ;;
        0)
            print_info "Exiting without changes"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
    
    # Validate permissions
    if [ "$NEEDS_ROOT" = true ]; then
        if ! check_root; then
            print_error "This script requires root privileges"
            print_info "Run with: sudo bash $0 --manual"
            exit 1
        fi
    else
        if check_root; then
            print_error "This script must NOT be run as root"
            print_info "Run as regular user: bash $0 --manual"
            exit 1
        fi
    fi
    
    # Verify script exists
    if [ ! -f "$RUN_SCRIPT" ]; then
        print_error "Script not found: $RUN_SCRIPT"
        exit 1
    fi
    
    # Run selected script
    print_info "Running: $(basename "$RUN_SCRIPT")"
    echo ""
    bash "$RUN_SCRIPT"
    exit 0
}

# Main script
show_alie_banner
show_warning_banner

# Detect environment
ENV=$(detect_environment)
print_step "Environment Detection"
print_success "Detected environment: $ENV"

# Check installation progress
STEP=$(get_installation_step)
STEP="${STEP:-0}"
if [ "$STEP" != "0" ]; then
    echo ""
    print_info "Installation progress detected!"
    print_success "Last completed step: $STEP"
    echo ""
fi

# Check for manual mode flag
if [ "${1:-}" = "--manual" ] || [ "${1:-}" = "-m" ]; then
    print_info "Manual mode enabled - you can choose any step"
    echo ""
    show_manual_menu
fi

case "$ENV" in
    "livecd")
        print_info "You are running from the Arch Linux installation media."
        echo ""
        
        # Check if base installation was started
        if [ "$STEP" -ge "1" ]; then
            print_warning "Base installation appears to be in progress or completed"
            echo ""
            echo "What would you like to do?"
            echo "  1) Continue/Retry base installation (001-base-install.sh)"
            echo "  2) Start fresh (clear progress and reinstall)"
            echo "  3) Exit"
            read -r -p "Choose an option [1-3]: " choice
            
            case "$choice" in
                2)
                    print_warning "This will clear all progress markers"
                    read -r -p "Are you sure? (yes/no): " confirm
                    if [ "${confirm:-}" = "yes" ]; then
                        clear_progress
                        print_info "Progress cleared. Re-run the installer."
                        exit 0
                    else
                        print_info "Cancelled"
                        exit 0
                    fi
                    ;;
                3)
                    print_info "Exiting..."
                    exit 0
                    ;;
            esac
        else
            echo "Available actions:"
            echo "  1) Install base system (001-base-install.sh)"
            echo "  2) Exit"
            echo ""
            read -r -p "Choose an option [1-2]: " choice
            
            if [ "$choice" = "2" ]; then
                print_info "Exiting..."
                exit 0
            fi
        fi
        
        # Run base installation
        if ! check_root; then
            print_error "This script must be run as root in the live environment."
            print_info "Run: sudo bash $0"
            exit 1
        fi
        
        print_info "Starting base installation..."
        
        if [ ! -f "$INSTALL_DIR/001-base-install.sh" ]; then
            print_error "001-base-install.sh not found in $INSTALL_DIR"
            exit 1
        fi
        
        bash "$INSTALL_DIR/001-base-install.sh"
        ;;
        
    "chroot")
        print_info "You are inside a chroot environment."
        echo ""
        
        # Check progress
        if [ "$STEP" -ge "2" ]; then
            print_warning "System configuration appears to be completed"
            echo ""
            echo "What would you like to do?"
            echo "  1) Reconfigure system (101-configure-system.sh)"
            echo "  2) Exit chroot and reboot"
            read -r -p "Choose an option [1-2]: " choice
            
            if [ "$choice" = "2" ]; then
                print_info "Exit chroot and follow instructions to reboot"
                exit 0
            fi
        else
            echo "Available actions:"
            echo "  1) Configure system (101-configure-system.sh)"
            echo "  2) Exit"
            echo ""
            read -r -p "Choose an option [1-2]: " choice
            
            if [ "$choice" = "2" ]; then
                print_info "Exiting..."
                exit 0
            fi
        fi
        
        # Run system configuration
        if ! check_root; then
            print_error "This script must be run as root in chroot."
            exit 1
        fi
        
        print_info "Starting system configuration..."
        
        if [ ! -f "$INSTALL_DIR/101-configure-system.sh" ]; then
            print_error "101-configure-system.sh not found in $INSTALL_DIR"
            exit 1
        fi
        
        bash "$INSTALL_DIR/101-configure-system.sh"
        ;;
        
    "installed-base")
        print_info "You are on an installed Arch Linux system (base only, no desktop)."
        echo ""
        
        # Check progress
        if [ "$STEP" -ge "3" ]; then
            print_success "Desktop already installed!"
            echo ""
            echo "Next steps:"
            echo "  1) Install YAY (run as regular user)"
            echo "  2) Exit"
            read -r -p "Choose an option [1-2]: " choice
            
            if [ "$choice" = "2" ]; then
                print_info "Exiting..."
                exit 0
            fi
            
            print_info "Please login as regular user and run:"
            echo "  ${YELLOW}bash $0${NC}"
            exit 0
        else
            echo "Available actions:"
            echo "  1) Setup user and privileges (201-user-setup.sh)"
            echo "  2) Exit"
            echo ""
            read -r -p "Choose an option [1-2]: " choice
            
            if [ "$choice" = "2" ]; then
                print_info "Exiting..."
                exit 0
            fi
        fi
        
        # Run user setup
        if ! check_root; then
            print_error "This script must be run as root."
            print_info "Run: sudo bash $0"
            exit 1
        fi
        
        print_info "Starting user setup..."
        
        if [ ! -f "$INSTALL_DIR/201-user-setup.sh" ]; then
            print_error "201-user-setup.sh not found in $INSTALL_DIR"
            exit 1
        fi
        
        bash "$INSTALL_DIR/201-user-setup.sh"
        ;;
        
    "installed-desktop")
        print_info "You are on an installed Arch Linux system with desktop."
        echo ""
        
        if check_root; then
            print_warning "Running as root. User scripts require regular user."
        fi
        
        # Check progress and show appropriate options
        if [ "$STEP" -ge "8" ]; then
            print_success "Full installation completed!"
            echo ""
            print_info "All ALIE components are installed."
            echo "  Display server (Xorg/Wayland)"
            echo "  Desktop environment or Window Manager"
            echo "  AUR helper and CLI tools"
            echo "You can re-run individual scripts if needed."
            exit 0
        elif [ "$STEP" -ge "6" ]; then
            print_success "CLI tools installed. Ready for display server setup."
            echo ""
            echo "Available actions:"
            echo "  1) Setup display server (213-display-server.sh) - as root"
            echo "  2) Desktop selection - DE/WM (220-desktop-select.sh) - as root"
            echo "  3) Install desktop tools (231-desktop-tools.sh) - as root"
            echo "  4) Exit"
            read -r -p "Choose an option [1-4]: " choice
            
            case "$choice" in
                1) NEXT_SCRIPT="213-display-server.sh"; NEEDS_ROOT=true ;;
                2) NEXT_SCRIPT="220-desktop-select.sh"; NEEDS_ROOT=true ;;
                3) NEXT_SCRIPT="231-desktop-tools.sh"; NEEDS_ROOT=true ;;
                4) print_info "Exiting..."; exit 0 ;;
                *) print_error "Invalid option"; exit 1 ;;
            esac
        elif [ "$STEP" -ge "5" ]; then
            print_success "AUR helper installed. Ready for CLI tools."
            echo ""
            echo "Available actions:"
            echo "  1) Install CLI tools (212-cli-tools.sh) - as user"
            echo "  2) Setup display server (213-display-server.sh) - as root"
            echo "  3) Exit"
            read -r -p "Choose an option [1-3]: " choice
            
            case "$choice" in
                1) NEXT_SCRIPT="212-cli-tools.sh"; NEEDS_ROOT=false ;;
                2) NEXT_SCRIPT="213-display-server.sh"; NEEDS_ROOT=true ;;
                3) print_info "Exiting..."; exit 0 ;;
                *) print_error "Invalid option"; exit 1 ;;
            esac
        else
            echo "Available actions:"
            echo "  1) Install AUR helper (211-install-aur-helper.sh) - as user"
            echo "  2) Install CLI tools (212-cli-tools.sh) - requires AUR helper"
            echo "  3) Setup display server (213-display-server.sh) - as root"
            echo "  4) Exit"
            read -r -p "Choose an option [1-4]: " choice
            
            case "$choice" in
                1) NEXT_SCRIPT="211-install-aur-helper.sh"; NEEDS_ROOT=false ;;
                2) NEXT_SCRIPT="212-cli-tools.sh"; NEEDS_ROOT=false ;;
                3) NEXT_SCRIPT="213-display-server.sh"; NEEDS_ROOT=true ;;
                4)
                    print_info "Exiting..."
                    exit 0
                    ;;
                *)
                    print_error "Invalid option"
                    exit 1
                    ;;
            esac
        fi
        
        # Check if needs root privileges
        if [[ "$NEEDS_ROOT" == "true" ]]; then
            if ! check_root; then
                print_error "This script requires root privileges. Please run with sudo."
                exit 1
            fi
        else
            # Verify not running as root for user scripts
            if check_root; then
                print_error "User scripts must be run as a regular user, not root."
                print_info "Exit root and run: bash $0"
                exit 1
            fi
        fi
        
        print_info "Starting $NEXT_SCRIPT..."
        
        if [ ! -f "$INSTALL_DIR/$NEXT_SCRIPT" ]; then
            print_error "$NEXT_SCRIPT not found in $INSTALL_DIR"
            exit 1
        fi
        
        bash "$INSTALL_DIR/$NEXT_SCRIPT"
        ;;
        
    "unknown")
        print_error "Unable to detect environment."
        echo ""
        print_info "Please run the appropriate script manually:"
        echo "  - From live CD: 001-base-install.sh -> (002-shell-editor-select.sh) -> 003-system-install.sh"
        echo "  - In chroot: 101-configure-system.sh"
        echo "  - After first boot: 201-user-setup.sh (as root)"
        echo "  - As user: 211-install-aur-helper.sh -> 212-cli-tools.sh"
        echo "  - Display setup (as root): 213-display-server.sh -> 220-desktop-select.sh -> 221/222 -> 231-desktop-tools.sh"
        exit 1
        ;;
esac

print_success "Script completed successfully!"
