#!/bin/bash
# ALIE Universal AUR Helper Installation Script
# Supports both YAY and PARU with auto-detection and user choice
# This script should be run as the regular user (not root)
#
# [WARNING] WARNING: EXPERIMENTAL SCRIPT
# This script is provided AS-IS without warranties.
# Review the code before running and use at your own risk.

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Add signal handling for graceful interruption
trap 'echo ""; print_warning "AUR helper installation cancelled by user (Ctrl+C)"; exit 130' INT

# Determine script directory (works regardless of how script is called)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Validate and load shared functions
if [ ! -f "$LIB_DIR/shared-functions.sh" ]; then
    echo "ERROR: shared-functions.sh not found at $LIB_DIR/shared-functions.sh"
    echo "Cannot continue without shared functions library."
    exit 1
fi

# shellcheck source=../lib/shared-functions.sh
# shellcheck disable=SC1091
source "$LIB_DIR/shared-functions.sh"

# Trap cleanup on exit
setup_cleanup_trap

# Function to detect installed AUR helpers
detect_aur_helpers() {
    local installed=()
    
    if command -v yay &>/dev/null; then
        installed+=("yay")
    fi
    
    if command -v paru &>/dev/null; then
        installed+=("paru")
    fi
    
    echo "${installed[@]}"
}

# Function to choose AUR helper
choose_aur_helper() {
    local installed
    mapfile -t installed < <(detect_aur_helpers)
    
    # If helpers already installed, show options
    if [ ${#installed[@]} -gt 0 ]; then
        print_step "AUR Helpers Detected"
        print_success "Found installed AUR helpers: ${installed[*]}"
        echo
        echo "Options:"
        echo "1) Keep existing and exit"
        echo "2) Install additional helper"
        echo "3) Reinstall existing helper"
        echo
        smart_clear
        read -r -p "Choose option [1-3] (default: 1): " choice
        choice=${choice:-1}
        
        case $choice in
            1)
                print_info "Using existing AUR helper: ${installed[0]}"
                return 1  # Signal to skip installation
                ;;
            2|3)
                # Continue to selection menu
                ;;
            *)
                print_info "Invalid choice, using existing helper"
                return 1
                ;;
        esac
    fi
    
    echo
    print_step "AUR Helper Selection"
    echo "Choose which AUR helper to install:"
    echo
    echo "1) YAY   - Go-based, most popular, great compatibility"
    echo "2) PARU  - Rust-based, faster, modern features"
    echo
    smart_clear
    read -r -p "Choose AUR helper [1-2] (default: 1): " helper_choice
    helper_choice=${helper_choice:-1}
    
    case $helper_choice in
        1) 
            SELECTED_HELPER="yay"
            echo "yay"
            ;;
        2) 
            SELECTED_HELPER="paru"
            echo "paru"
            ;;
        *) 
            print_warning "Invalid choice, defaulting to yay"
            SELECTED_HELPER="yay"
            echo "yay"
            ;;
    esac
}

# Function to install specific AUR helper
install_aur_helper() {
    local helper=$1
    local use_binary=${2:-false}
    
    print_step "Installing $helper"
    
    # Choose between source and binary for yay only
    local repo_name="$helper"
    if [ "$use_binary" = "true" ] && [ "$helper" = "yay" ]; then
        repo_name="yay-bin"
        print_info "Installing binary version (yay-bin)"
    else
        print_info "Installing from source ($repo_name)"
    fi
    
    # Use dedicated build directory
    BUILD_BASE="$HOME/.cache/alie-build"
    AUR_BUILD_DIR="$BUILD_BASE/$repo_name"
    
    print_info "Setting up build directory..."
    mkdir -p "$BUILD_BASE"
    
    # Remove old directory if exists
    if [ -d "$AUR_BUILD_DIR" ]; then
        print_info "Removing old $repo_name directory..."
        rm -rf "$AUR_BUILD_DIR"
    fi
    
    print_info "Cloning $repo_name repository from AUR..."
    if ! git clone "https://aur.archlinux.org/$repo_name.git" "$AUR_BUILD_DIR"; then
        print_error "Failed to clone $repo_name repository"
        print_info "Please check your internet connection and try again"
        return 1
    fi
    
    # Verify clone was successful
    if [ ! -d "$AUR_BUILD_DIR" ] || [ ! -f "$AUR_BUILD_DIR/PKGBUILD" ]; then
        print_error "$repo_name repository clone incomplete or corrupted"
        return 1
    fi
    
    print_success "Repository cloned successfully"
    
    print_info "Building and installing $repo_name..."
    if [ "$helper" = "paru" ]; then
        print_warning "This may take several minutes (Rust compilation)..."
    else
        print_warning "This may take a few minutes..."
    fi
    
    # Build and install
    if ! (cd "$AUR_BUILD_DIR" && makepkg -si --noconfirm); then
        print_error "Failed to build or install $repo_name"
        print_info "Check the output above for errors"
        return 1
    fi
    
    # Verify installation
    if ! command -v "$helper" &>/dev/null; then
        print_error "$helper installation failed - command not found after install"
        return 1
    fi
    
    print_success "$helper built and installed successfully"
    
    # Clean up build directory
    print_info "Cleaning up build files..."
    rm -rf "$AUR_BUILD_DIR"
    AUR_BUILD_DIR=""  # Clear variable
    
    return 0
}

# Function to configure makepkg optimally before AUR helper installation
configure_makepkg() {
    local enable_debug=${1:-false}
    
    print_step "Optimizing makepkg Configuration"
    
    local MAKEPKG_CONF="/etc/makepkg.conf"
    
    print_info "Optimizing makepkg.conf for AUR compilation..."
    
    # Backup original configuration
    if [[ -f "$MAKEPKG_CONF" ]]; then
        print_info "Creating backup of $MAKEPKG_CONF..."
        run_privileged "cp '$MAKEPKG_CONF' '${MAKEPKG_CONF}.backup.$(date +%Y%m%d_%H%M%S)'"
    fi
    
    # Get CPU info for optimization
    local cpu_cores
    cpu_cores=$(nproc)
    local make_jobs=$((cpu_cores + 1))
    
    # Determine architecture optimization
    local arch_flags="-march=x86-64-v3 -mtune=generic"
    
    # Create optimized makepkg configuration
    print_info "Generating optimized makepkg.conf with $cpu_cores cores optimization..."
    
    local temp_config="/tmp/makepkg.conf.new"
    
    cat > "$temp_config" << EOF
#!/hint/bash
#
# /etc/makepkg.conf - Optimized by ALIE for AUR compilation
# Generated: $(date)
#

#########################################################################
# SOURCE ACQUISITION
#########################################################################
DLAGENTS=('file::/usr/bin/curl -qgC - -o %o %u'
          'ftp::/usr/bin/curl -qgfC - --ftp-pasv --retry 3 --retry-delay 3 -o %o %u'
          'http::/usr/bin/curl -qgb "" -fLC - --retry 3 --retry-delay 3 -o %o %u'
          'https::/usr/bin/curl -qgb "" -fLC - --retry 3 --retry-delay 3 -o %o %u'
          'rsync::/usr/bin/rsync --no-motd -z %u %o'
          'scp::/usr/bin/scp -C %u %o')

#########################################################################
# ARCHITECTURE, COMPILE FLAGS
#########################################################################
CARCH="x86_64"
CHOST="x86_64-pc-linux-gnu"

# Optimized compilation flags for modern processors
CPPFLAGS="-D_FORTIFY_SOURCE=3"
CFLAGS="$arch_flags -O2 -pipe -fno-plt -fexceptions \\
        -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security \\
        -fstack-clash-protection -fcf-protection \\
        -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"
CXXFLAGS="\$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now \\
         -Wl,-z,pack-relative-relocs"
LTOFLAGS="-flto=auto"
RUSTFLAGS="-C force-frame-pointers=yes -C target-cpu=x86-64-v3"

# Debug flags (used when debug is enabled)
DEBUG_CFLAGS="-g -fvar-tracking-assignments"
DEBUG_CXXFLAGS="-g -fvar-tracking-assignments"
DEBUG_RUSTFLAGS="-C debuginfo=2"

#########################################################################
# BUILD ENVIRONMENT
#########################################################################
BUILDENV=(!distcc color !ccache check !sign)

# Parallel compilation optimized for $cpu_cores cores
MAKEFLAGS="-j$make_jobs"

#########################################################################
# PACKAGE OUTPUT
#########################################################################
INTEGRITY_CHECK=(sha256)
STRIP_BINARIES="--strip-all"
STRIP_SHARED="--strip-unneeded"
STRIP_STATIC="--strip-debug"
MAN_DIRS=({usr{,/local}{,/share},opt/*}/{man,info})
DOC_DIRS=(usr/{,local/}{,share/}{doc,gtk-doc} opt/*/{doc,gtk-doc})
DBGSRCDIR="/usr/src/debug"

#########################################################################
# COMPRESSION DEFAULTS (optimized for speed and size)
#########################################################################
COMPRESSGZ=(pigz -c -f -n)
COMPRESSBZ2=(pbzip2 -c -f)
COMPRESSXZ=(xz -c -z - --threads=0)
COMPRESSZST=(zstd -c -T0 --auto-threads=logical -)
COMPRESSLZ4=(lz4 -q)
COMPRESSLRZ=(lrzip -q)
COMPRESSZ=(compress -c -f)
COMPRESSLZ=(lzip -c -f)

#########################################################################
# EXTENSION DEFAULTS
#########################################################################
PKGEXT='.pkg.tar.zst'
SRCEXT='.src.tar.gz'

EOF
    
    # Add debug configuration based on user choice
    if [[ "$enable_debug" == "y" ]]; then
        echo 'OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge debug !lto)' >> "$temp_config"
        print_info "Enabling debug packages for development..."
    else
        echo 'OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug !lto)' >> "$temp_config"
        print_info "Disabling debug packages for faster compilation..."
    fi
    
    # Apply the new configuration
    print_info "Applying optimized makepkg configuration..."
    run_privileged "cp '$temp_config' '$MAKEPKG_CONF'"
    run_privileged "chmod 644 '$MAKEPKG_CONF'"
    rm "$temp_config"
    
    # Verify zstd is installed for fast compression
    if ! command -v zstd &>/dev/null; then
        print_info "Installing zstd for fast package compression..."
        run_privileged "pacman -S --needed --noconfirm zstd"
    fi
    
    # Verify pigz is installed for fast gzip compression
    if ! command -v pigz &>/dev/null; then
        print_info "Installing pigz for fast gzip compression..."
        run_privileged "pacman -S --needed --noconfirm pigz"
    fi
    
    print_success "makepkg.conf optimized for AUR compilation"
    print_info "Configuration details:"
    echo "  - Parallel jobs: $make_jobs (${cpu_cores} cores + 1)"
    echo "  - Architecture: x86-64-v3 optimized"
    echo "  - Compression: zstd multithreaded"
    echo "  - Debug packages: $([[ "$enable_debug" == "y" ]] && echo "enabled" || echo "disabled")"
}

# Function to configure AUR helper post-installation
configure_aur_helper() {
    local helper=$1
    local enable_debug=${2:-false}
    
    print_step "Configuring $helper"
    
    case $helper in
        "yay")
            print_info "Setting up yay development package tracking..."
            yay -Y --gendb --noconfirm 2>/dev/null || true
            
            print_info "Enabling combined upgrade mode..."
            yay -Y --combinedupgrade --save --noconfirm 2>/dev/null || true
            
            # Create yay configuration
            local config_dir="$HOME/.config/yay"
            local config_file="$config_dir/config.json"
            
            print_info "Creating optimized yay configuration..."
            mkdir -p "$config_dir"
            
            # Build yay config JSON
            cat > "$config_file" << EOF
{
  "aururl": "https://aur.archlinux.org",
  "buildDir": "$HOME/.cache/yay",
  "editor": "",
  "editorflags": "",
  "makepkgbin": "makepkg",
  "makepkgconf": "",
  "pacmanbin": "pacman",
  "pacmanconf": "/etc/pacman.conf",
  "redownload": "no",
  "rebuild": "no",
  "answerclean": "",
  "answerdiff": "",
  "answeredit": "",
  "answerupgrade": "",
  "gitbin": "git",
  "gpgbin": "gpg",
  "gpgflags": "",
  "mflags": "",
  "sudobin": "sudo",
  "sudoflags": "",
  "requestsplitn": 5,
  "completionrefreshtime": 7,
  "bottomup": true,
  "sudo": true,
  "timeupdate": false,
  "devel": true,
  "cleanAfter": false,
  "provides": true,
  "pgpfetch": true,
  "upgrademenu": true,
  "cleanmenu": true,
  "diffmenu": true,
  "editmenu": false,
  "combinedupgrade": true,
  "useask": false,
  "batchinstall": true
}
EOF
            
            print_success "YAY configuration created at $config_file"
            ;;
            
        "paru")
            print_info "Setting up paru development package tracking..."
            paru --gendb --noconfirm 2>/dev/null || true
            
            # Create comprehensive paru config
            local config_dir="$HOME/.config/paru"
            local config_file="$config_dir/paru.conf"
            
            print_info "Creating optimized paru configuration..."
            mkdir -p "$config_dir"
            
            cat > "$config_file" << 'EOF'
#
# ALIE Optimized PARU Configuration
# ~/.config/paru/paru.conf
#

[options]
# AUR options
PgpFetch
Devel
Provides
DevelSuffixes = -git -cvs -svn -bzr -darcs -always -nightly

# Behavior
BottomUp
SudoLoop
NewsOnUpgrade
LocalRepo
Chroot

# Build options
KeepSrc
BatchInstall

# UI options
UpgradeMenu
CleanMenu

# Performance
UseAsk = false
CombinedUpgrade = true

[bin]
# Optional: FileManager for reviewing files
# FileManager = ranger
# MFlags = --skipinteg
# Sudo = doas (or any configured privilege escalation tool)
EOF
            
            print_success "PARU configuration created at $config_file"
            ;;
    esac
    
    # Save configuration preferences
    save_install_info "aur_helper_debug" "$enable_debug"
    if [[ "$enable_debug" == "y" ]]; then
        print_info "Debug packages configuration saved for future reference"
    fi
}

# Main script start
show_alie_banner
show_warning_banner

print_info "This script will install an AUR helper with the following options:"
echo "  [OK] YAY (Go) - Popular and stable"
echo "  [OK] PARU (Rust) - Fast and modern"
echo "  [OK] Automatic configuration and setup"
echo ""
smart_clear
read -r -p "Press Enter to continue or Ctrl+C to exit..."

# Validate environment
print_step "STEP 1: Environment Validation"

# Verify NOT running as root
require_non_root

# Verify we're on Arch Linux
verify_arch_linux

# Verify NOT in chroot
verify_not_chroot

# Verify internet connectivity
verify_internet

# Verify base-devel and git are installed
print_info "Checking required packages..."
if ! is_package_installed "base-devel"; then
    print_error "base-devel is not installed"
    print_info "Please install it first: run_privileged 'pacman -S --needed base-devel'"
    exit 1
fi

if ! command -v git &>/dev/null; then
    print_error "git is not installed"
    print_info "Please install it first: run_privileged 'pacman -S git'"
    exit 1
fi

print_success "All prerequisites met"

# Validate desktop user and ensure running as that user
require_desktop_user

# Choose AUR helper to install
selected_helper=$(choose_aur_helper)
if [ $? -eq 1 ]; then
    # User chose to keep existing helper
    print_step "Updating Package Database"
    detected=()
    mapfile -t detected < <(detect_aur_helpers)
    if [ ${#detected[@]} -gt 0 ]; then
        print_info "Syncing package databases using ${detected[0]}..."
        ${detected[0]} -Syy
        print_success "Package database updated!"
        
        # Save the detected AUR helper preference
        save_install_info "aur_helper" "${detected[0]}"
        print_info "Detected and saved AUR helper: ${detected[0]}"
        
        save_progress "04-aur-helper-installed"
        echo ""
        print_success "AUR helper is ready to use!"
        echo ""
        print_info "Next step:"
        echo "  ${CYAN}[INFO]${NC} Run ${YELLOW}212-install-packages.sh${NC} to install packages"
        exit 0
    fi
fi

# Ask about binary vs source for yay
use_binary=false
if [ "$selected_helper" = "yay" ]; then
    echo
    smart_clear
    read -r -p "Install yay from binary package? (faster compilation) [Y/n]: " binary_choice
    if [[ ! $binary_choice =~ ^[Nn]$ ]]; then
        use_binary=true
    fi
fi

# Ask about debug packages configuration
echo
print_step "Build Configuration Options"
print_info "Do you want to enable debug package building?"
echo "This will:"
echo "  [OK] Build packages with debug symbols (-debug packages)"
echo "  [OK] Useful for development and troubleshooting"
echo "  [WARNING] Increases build time and disk usage"
echo
smart_clear
read -r -p "Enable debug packages? [y/N]: " enable_debug
enable_debug=${enable_debug:-n}
enable_debug=${enable_debug,,}  # lowercase

# Configure makepkg optimally before AUR helper installation
configure_makepkg "$enable_debug"

# Install selected AUR helper
print_step "STEP 3: Installing $selected_helper"

if install_aur_helper "$selected_helper" "$use_binary"; then
    print_success "$selected_helper installation completed!"
    
    # Configure the helper
    configure_aur_helper "$selected_helper" "$enable_debug"
    
    # Update package database
    print_step "STEP 4: Updating Package Database"
    print_info "Syncing package databases using $selected_helper..."
    $selected_helper -Syy
    
    # Save progress and AUR helper preference
    save_progress "04-aur-helper-installed"
    
    # Save the chosen AUR helper for future scripts
    save_install_info "aur_helper" "$selected_helper"
    print_info "Saved AUR helper preference: $selected_helper"
    
    echo ""
    print_success "AUR helper installation completed!"
    echo ""
    print_info "$selected_helper is now ready to install AUR packages"
    
    # Show version and basic info
    version=$($selected_helper --version 2>/dev/null | head -n1 || echo "Version unknown")
    print_info "Installed: $version"
    
    echo ""
    print_info "Next step:"
    echo "  ${CYAN}[INFO]${NC} Run ${YELLOW}212-install-packages.sh${NC} to install packages"
    echo ""
    print_info "Basic usage:"
    echo "  - Update system: ${CYAN}$selected_helper${NC}"
    echo "  - Search packages: ${CYAN}$selected_helper <search-term>${NC}"
    echo "  - Install packages: ${CYAN}$selected_helper -S <package-name>${NC}"
    echo ""
    print_info "Configuration files created:"
    if [ "$selected_helper" = "yay" ]; then
        echo "  - YAY config: ${CYAN}~/.config/yay/config.json${NC}"
    else
        echo "  - PARU config: ${CYAN}~/.config/paru/paru.conf${NC}"
    fi
    echo "  - Optimized makepkg: ${CYAN}/etc/makepkg.conf${NC}"
    
    if [[ "$enable_debug" == "y" ]]; then
        echo ""
        print_info "Debug packages enabled - will be built automatically with -debug suffix"
    fi
else
    print_error "Failed to install $selected_helper"
    exit 1
fi