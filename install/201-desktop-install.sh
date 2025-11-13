#!/bin/bash
# ALIE Desktop Environment Installation Script
# This script should be run after the first reboot, as root
#
# ?????? WARNING: EXPERIMENTAL SCRIPT
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

# Trap cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Desktop installation failed!"
    fi
}
trap cleanup EXIT

# Main script start
show_alie_banner
print_step "Desktop Environment Installation"
require_root

# Verify system is ready
echo ""
print_info "Verifying system prerequisites..."

# Verify we're on Arch Linux
verify_arch_linux

# Verify we're not in a chroot
verify_not_chroot

# Verify internet connectivity
verify_internet

print_success "System prerequisites met"

# Get user information
echo ""
print_info "User Creation"
echo "This user will be the primary desktop user with sudo privileges"
echo ""
read -p "Enter username for desktop user: " USERNAME

# Sanitize username
USERNAME="${USERNAME,,}"  # Convert to lowercase
USERNAME="${USERNAME//[[:space:]]}"  # Remove whitespace

# Validate username
if [ -z "$USERNAME" ]; then
    print_error "Username cannot be empty"
    exit 1
fi

# More comprehensive username validation
if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    print_error "Invalid username: $USERNAME"
    print_info "Username requirements:"
    echo "  ??? Must start with a lowercase letter or underscore"
    echo "  ??? Can contain only lowercase letters, numbers, underscores, and hyphens"
    echo "  ??? Maximum 32 characters"
    exit 1
fi

# Check for reserved usernames
RESERVED_USERS=("root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody" "systemd-network" "systemd-resolve" "systemd-timesync")
for reserved in "${RESERVED_USERS[@]}"; do
    if [ "$USERNAME" = "$reserved" ]; then
        print_error "Username '$USERNAME' is reserved by the system"
        exit 1
    fi
done

print_success "Username: $USERNAME"

# Create user
echo ""
print_step "Creating User"
if id "$USERNAME" &>/dev/null; then
    print_warning "User $USERNAME already exists. Skipping user creation."
    
    # Verify user is in wheel group
    if ! groups "$USERNAME" | grep -q wheel; then
        print_info "Adding $USERNAME to wheel group..."
        usermod -aG wheel "$USERNAME"
    fi
else
    print_info "Creating user $USERNAME..."
    
    # Add user to useful groups, safer than sorryer
    # wheel: sudo access
    # storage: access to removable drives
    # optical: access to optical drives
    # audio: access to audio devices
    # video: access to video devices
    # network: network management
    useradd -m -G wheel,storage,optical,audio,video,network "$USERNAME"
    
    echo ""
    print_info "Set password for $USERNAME:"
    while ! passwd "$USERNAME"; do
        print_warning "Password setting failed. Please try again."
    done
    
    print_success "User created successfully"
fi

# Configure sudo
echo ""
print_step "Configuring sudo"

# Install sudo if not present
if ! command -v sudo &>/dev/null; then
    print_info "Installing sudo..."
    pacman -S --noconfirm sudo
fi

# Backup sudoers before modification
if [ ! -f /etc/sudoers.bak ]; then
    cp /etc/sudoers /etc/sudoers.bak
fi

if ! grep -q "^%wheel ALL=(ALL) ALL" /etc/sudoers; then
    print_info "Enabling wheel group in sudoers..."
    # Use visudo-safe method
    echo "%wheel ALL=(ALL) ALL" | EDITOR='tee -a' visudo > /dev/null 2>&1 || \
        sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
    print_success "Sudo configured"
else
    print_success "Sudo already configured"
fi

# Verify sudoers file is valid
if ! visudo -c &>/dev/null; then
    print_error "Sudoers file is invalid!"
    print_info "Restoring backup..."
    cp /etc/sudoers.bak /etc/sudoers
    exit 1
fi

# Install desktop environment
echo ""
print_step "Installing Desktop Environment"
DESKTOP_PACKAGES=(
    xorg xorg-apps xorg-drivers mesa
    lightdm lightdm-slick-greeter
    cinnamon cinnamon-translations
    gnome-terminal
    xdg-user-dirs xdg-user-dirs-gtk
)
install_packages "${DESKTOP_PACKAGES[@]}"

# Configure LightDM
echo ""
print_step "Configuring LightDM"

# Backup original config if not already backed up
if [ ! -f /etc/lightdm/lightdm.conf.bak ]; then
    cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bak
fi

print_info "Setting slick greeter..."
# More robust configuration that handles missing lines
if grep -q "^#greeter-session=" /etc/lightdm/lightdm.conf; then
    sed -i 's/^#greeter-session=.*/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf
elif grep -q "^greeter-session=" /etc/lightdm/lightdm.conf; then
    sed -i 's/^greeter-session=.*/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf
else
    # Add greeter-session if it doesn't exist
    sed -i '/^\[Seat:\*\]/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
fi

# Verify configuration was applied
if grep -q "^greeter-session=lightdm-slick-greeter" /etc/lightdm/lightdm.conf; then
    print_success "LightDM configured with slick greeter"
else
    print_error "Failed to configure LightDM greeter"
    exit 1
fi

# Enable LightDM
print_info "Enabling LightDM service..."
if systemctl enable lightdm; then
    print_success "LightDM enabled"
else
    print_error "Failed to enable LightDM"
    exit 1
fi

# Verify LightDM is set as default display manager
if systemctl get-default | grep -q "graphical.target"; then
    print_success "Graphical target already set"
else
    print_info "Setting default target to graphical..."
    systemctl set-default graphical.target
fi

# Install base-devel and git for AUR
echo ""
print_step "Installing Development Tools"
install_packages git base-devel

# Setup user directories
echo ""
print_step "Configuring User Environment"
print_info "Creating user directories..."

# Run xdg-user-dirs-update as the user to create standard directories
if su - "$USERNAME" -c "xdg-user-dirs-update" 2>/dev/null; then
    print_success "User directories created"
else
    print_warning "Could not create user directories automatically"
    print_info "They will be created on first login"
fi

# Set proper ownership of home directory
print_info "Setting permissions..."
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
print_success "Permissions set"

# Save progress
save_progress "03-desktop-installed"

# Save username for later scripts
save_install_info "DESKTOP_USER" "$USERNAME"

echo ""
print_success "Desktop installation completed!"
echo ""
print_info "Next steps:"
echo "  ${CYAN}1.${NC} Reboot the system: ${YELLOW}reboot${NC}"
echo "  ${CYAN}2.${NC} Login as ${YELLOW}$USERNAME${NC} at the graphical login screen"
echo "  ${CYAN}3.${NC} Open a terminal and navigate to the scripts directory"
echo "  ${CYAN}4.${NC} Run ${YELLOW}bash install/211-install-yay.sh${NC} (as user, NOT root)"
echo "  ${CYAN}5.${NC} Run ${YELLOW}bash install/212-install-packages.sh${NC} to install all Mint packages"
echo ""
print_warning "Remember: Scripts 04 and 05 must be run as regular user, NOT as root!"
echo ""
