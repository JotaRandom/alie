#!/bin/bash
# ALIE Master Installation Script
# This script detects the environment and runs the appropriate installation script
#
# ?????? WARNING: EXPERIMENTAL SCRIPT
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

source "$LIB_DIR/shared-functions.sh"

# Function to detect environment
detect_environment() {
    # Check if running in chroot
    if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ] 2>/dev/null; then
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
    echo "  ${CYAN}1)${NC} Base System Installation (001-base-install.sh)"
    echo "     ${YELLOW}???${NC} Partition, format, install base system"
    echo "     ${YELLOW}???${NC} Requires: Live USB environment, root privileges"
    echo ""
    echo "  ${CYAN}2)${NC} System Configuration (101-configure-system.sh)"
    echo "     ${YELLOW}???${NC} Configure timezone, locale, hostname, GRUB"
    echo "     ${YELLOW}???${NC} Requires: Chroot environment, root privileges"
    echo ""
    echo "  ${CYAN}3)${NC} Desktop Installation (201-desktop-install.sh)"
    echo "     ${YELLOW}???${NC} Install Cinnamon desktop, LightDM, create user"
    echo "     ${YELLOW}???${NC} Requires: Booted system, root privileges"
    echo ""
    echo "  ${CYAN}4)${NC} YAY Installation (211-install-yay.sh)"
    echo "     ${YELLOW}???${NC} Install YAY AUR helper"
    echo "     ${YELLOW}???${NC} Requires: Regular user (NOT root)"
    echo ""
    echo "  ${CYAN}5)${NC} Packages Installation (212-install-packages.sh)"
    echo "     ${YELLOW}???${NC} Install Linux Mint packages and themes"
    echo "     ${YELLOW}???${NC} Requires: YAY installed, regular user (NOT root)"
    echo ""
    echo "  ${CYAN}6)${NC} Clear progress and exit"
    echo "  ${CYAN}7)${NC} Exit without changes"
    echo ""
    
    read -p "Choose script to run [1-7]: " choice
    
    case "$choice" in
        1) RUN_SCRIPT="$INSTALL_DIR/001-base-install.sh"; NEEDS_ROOT=true ;;
        2) RUN_SCRIPT="$INSTALL_DIR/101-configure-system.sh"; NEEDS_ROOT=true ;;
        3) RUN_SCRIPT="$INSTALL_DIR/201-desktop-install.sh"; NEEDS_ROOT=true ;;
        4) RUN_SCRIPT="$INSTALL_DIR/211-install-yay.sh"; NEEDS_ROOT=false ;;
        5) RUN_SCRIPT="$INSTALL_DIR/212-install-packages.sh"; NEEDS_ROOT=false ;;
        6)
            print_warning "This will clear all progress markers"
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                clear_progress
                print_info "Progress cleared"
            fi
            exit 0
            ;;
        7)
            print_info "Exiting..."
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
if [ "$STEP" != "0" ]; then
    echo ""
    print_info "Installation progress detected!"
    print_success "Last completed step: $STEP"
    echo ""
fi

# Check for manual mode flag
MANUAL_MODE=false
if [ "$1" = "--manual" ] || [ "$1" = "-m" ]; then
    MANUAL_MODE=true
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
            read -p "Choose an option [1-3]: " choice
            
            case "$choice" in
                2)
                    print_warning "This will clear all progress markers"
                    read -p "Are you sure? (yes/no): " confirm
                    if [ "$confirm" = "yes" ]; then
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
            read -p "Choose an option [1-2]: " choice
            
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
            read -p "Choose an option [1-2]: " choice
            
            if [ "$choice" = "2" ]; then
                print_info "Exit chroot and follow instructions to reboot"
                exit 0
            fi
        else
            echo "Available actions:"
            echo "  1) Configure system (101-configure-system.sh)"
            echo "  2) Exit"
            echo ""
            read -p "Choose an option [1-2]: " choice
            
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
            read -p "Choose an option [1-2]: " choice
            
            if [ "$choice" = "2" ]; then
                print_info "Exiting..."
                exit 0
            fi
            
            print_info "Please login as regular user and run:"
            echo "  ${YELLOW}bash $0${NC}"
            exit 0
        else
            echo "Available actions:"
            echo "  1) Install desktop environment (201-desktop-install.sh)"
            echo "  2) Exit"
            echo ""
            read -p "Choose an option [1-2]: " choice
            
            if [ "$choice" = "2" ]; then
                print_info "Exiting..."
                exit 0
            fi
        fi
        
        # Run desktop installation
        if ! check_root; then
            print_error "This script must be run as root."
            print_info "Run: sudo bash $0"
            exit 1
        fi
        
        print_info "Starting desktop installation..."
        
        if [ ! -f "$INSTALL_DIR/201-desktop-install.sh" ]; then
            print_error "201-desktop-install.sh not found in $INSTALL_DIR"
            exit 1
        fi
        
        bash "$INSTALL_DIR/201-desktop-install.sh"
        ;;
        
    "installed-desktop")
        print_info "You are on an installed Arch Linux system with desktop."
        echo ""
        
        if check_root; then
            print_warning "Running as root. User scripts require regular user."
        fi
        
        # Check progress and show appropriate options
        if [ "$STEP" -ge "5" ]; then
            print_success "Full installation completed!"
            echo ""
            print_info "All ALIE components are installed."
            echo "You can re-run individual scripts if needed."
            exit 0
        elif [ "$STEP" -ge "4" ]; then
            print_success "YAY is installed. Ready for package installation."
            echo ""
            echo "Available actions:"
            echo "  1) Install all packages (212-install-packages.sh)"
            echo "  2) Exit"
            read -p "Choose an option [1-2]: " choice
            
            if [ "$choice" = "2" ]; then
                print_info "Exiting..."
                exit 0
            fi
            
            NEXT_SCRIPT="212-install-packages.sh"
        else
            echo "Available actions:"
            echo "  1) Install YAY (211-install-yay.sh)"
            echo "  2) Install all packages (212-install-packages.sh) - requires YAY"
            echo "  3) Exit"
            read -p "Choose an option [1-3]: " choice
            
            case "$choice" in
                1) NEXT_SCRIPT="211-install-yay.sh" ;;
                2) NEXT_SCRIPT="212-install-packages.sh" ;;
                3)
                    print_info "Exiting..."
                    exit 0
                    ;;
                *)
                    print_error "Invalid option"
                    exit 1
                    ;;
            esac
        fi
        
        # Verify not running as root
        if check_root; then
            print_error "User scripts must be run as a regular user, not root."
            print_info "Exit root and run: bash $0"
            exit 1
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
        echo "  - From live CD: 001-base-install.sh"
        echo "  - In chroot: 101-configure-system.sh"
        echo "  - After first boot: 201-desktop-install.sh"
        echo "  - With desktop installed (as user): 211-install-yay.sh"
        echo "  - With YAY installed (as user): 212-install-packages.sh"
        exit 1
        ;;
esac

print_success "Script completed successfully!"
