#!/bin/bash
# ALIE Interactive CLI Tools Installation
# Select and install only the CLI tools categories you want
# Run as regular user (not root)
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
SCRIPT_NAME="Interactive CLI Tools Installation"
SCRIPT_DESC="Select and install CLI tools categories based on your needs"

print_section_header "$SCRIPT_NAME" "$SCRIPT_DESC"

# ============================================================================
# INTERACTIVE MENU FUNCTIONS
# ============================================================================

# Show main menu and get user selection
show_main_menu() {
    clear
    echo ""
    print_section_header "CLI Tools Categories" "Choose what to install"
    echo ""
    print_info "Available categories:"
    echo ""
    echo "  ${CYAN}1.${NC} 📁 Archive Tools        - Extractors, compressors (7zip, rar, zstd)"
    echo "  ${CYAN}2.${NC} ⚡ System Utilities     - Modern CLI replacements (exa, bat, fd, ripgrep)"
    echo "  ${CYAN}3.${NC} 🔧 Development Tools    - Compilers, build systems, linux-headers"
    echo "  ${CYAN}4.${NC} 🛡️  Security Tools       - VPN, encryption, security auditing"
    echo "  ${CYAN}5.${NC} 🎵 Media Tools          - Audio, video, image processing"
    echo "  ${CYAN}6.${NC} 💻 Admin & Laptop Tools - System monitoring, power management"
    echo "  ${CYAN}7.${NC} 🎨 Shell Enhancements   - Prompt, aliases, configurations"
    echo ""
    echo "  ${CYAN}A.${NC} 🚀 Install All Categories"
    echo "  ${CYAN}Q.${NC} ❌ Quit without installing"
    echo ""
}

# Get user selection for categories
get_user_selection() {
    local selected_categories=()
    local input
    
    while true; do
        show_main_menu
        
        if [ ${#selected_categories[@]} -gt 0 ]; then
            print_info "Selected: $(printf "%s " "${selected_categories[@]}")"
            echo ""
        fi
        
        printf "${CYAN}Select categories (1-7), 'A' for all, 'I' to install, 'Q' to quit: ${NC}"
        read -r input
        
        case "$input" in
            [1-7])
                # Toggle category selection
                if [[ " ${selected_categories[*]} " =~ " $input " ]]; then
                    # Remove from selection
                    selected_categories=($(printf '%s\n' "${selected_categories[@]}" | grep -v "^$input$"))
                else
                    # Add to selection
                    selected_categories+=("$input")
                fi
                ;;
            [aA])
                selected_categories=("1" "2" "3" "4" "5" "6" "7")
                ;;
            [iI])
                if [ ${#selected_categories[@]} -eq 0 ]; then
                    print_warning "No categories selected. Please select at least one category."
                    read -p "Press Enter to continue..."
                else
                    echo "${selected_categories[@]}"
                    return 0
                fi
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

# Confirm installation with user
confirm_installation() {
    local categories=("$@")
    local category_names=()
    
    for cat in "${categories[@]}"; do
        case "$cat" in
            1) category_names+=("Archive Tools") ;;
            2) category_names+=("System Utilities") ;;
            3) category_names+=("Development Tools") ;;
            4) category_names+=("Security Tools") ;;
            5) category_names+=("Media Tools") ;;
            6) category_names+=("Admin & Laptop Tools") ;;
            7) category_names+=("Shell Enhancements") ;;
        esac
    done
    
    echo ""
    print_info "You selected to install:"
    for name in "${category_names[@]}"; do
        echo "  • ${CYAN}$name${NC}"
    done
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
# CATEGORY INSTALLATION FUNCTIONS
# ============================================================================

# Category 1: Archive Tools
install_archive_tools() {
    print_step "Installing Archive Tools"
    
    local ARCHIVE_TOOLS=(
        # Archive and compression
        "7zip"              # 7-Zip archiver
        "unrar"             # RAR extraction  
        "unace"             # ACE extraction
        "lrzip"             # Long range ZIP
        "zstd"              # Modern compression
        "lz4"               # Fast compression
        "p7zip"             # 7-Zip for POSIX
        "atool"             # Archive tool wrapper
    )
    
    install_cli_group "Archive Tools" "${ARCHIVE_TOOLS[@]}"
}

# Category 2: System Utilities
install_system_utilities() {
    print_step "Installing System Utilities"
    
    local SYSTEM_UTILS=(
        # Process and system monitoring
        "htop"              # Interactive process monitor
        "btop"              # Modern system monitor
        "iotop"             # I/O monitoring
        "nethogs"           # Network bandwidth per process
        
        # File operations
        "exa"               # Modern ls replacement
        "bat"               # Cat with syntax highlighting
        "fd"                # Modern find replacement
        "ripgrep"           # Fast grep replacement
        "tree"              # Directory tree viewer
        "duf"               # Modern df replacement
        
        # System information
        "neofetch"          # System info display
        "inxi"              # System information
        "lshw"              # Hardware information
        "dmidecode"         # Hardware details
        
        # Text processing
        "jq"                # JSON processor
        "yq"                # YAML processor
        "fzf"               # Fuzzy finder
        
        # Terminal enhancements
        "tmux"              # Terminal multiplexer
        "screen"            # Terminal multiplexer
        "starship"          # Shell prompt
    )
    
    install_cli_group "System Utilities" "${SYSTEM_UTILS[@]}"
}

# Category 3: Development Tools  
install_development_tools() {
    print_step "Installing Development Tools"
    
    local DEV_TOOLS=(
        # Build systems
        "cmake"             # Cross-platform build system
        "ninja"             # Fast build system
        "meson"             # Modern build system
        "make"              # GNU Make
        "autoconf"          # Configure script generator
        "automake"          # Makefile generator
        "pkgconf"           # Package config
        
        # Kernel development
        "linux-headers"     # Linux kernel headers
        "base-devel"        # Base development group
        
        # Version control
        "git"               # Git version control
        "git-lfs"           # Git Large File Storage
        "mercurial"         # Mercurial VCS
        "subversion"        # SVN version control
        
        # Programming languages
        "python"            # Python interpreter
        "python-pip"        # Python package installer
        "nodejs"            # Node.js runtime
        "npm"               # Node package manager
        "rust"              # Rust compiler
        "go"                # Go programming language
        
        # Development utilities
        "gdb"               # GNU Debugger
        "valgrind"          # Memory debugging
        "strace"            # System call tracer
        "ltrace"            # Library call tracer
        "perf"              # Performance profiler
        
        # Documentation
        "man-db"            # Manual pages
        "man-pages"         # Linux manual pages
        "tldr"              # Simplified manual pages
    )
    
    install_cli_group "Development Tools" "${DEV_TOOLS[@]}"
}

# Category 4: Security Tools
install_security_tools() {
    print_step "Installing Security Tools"
    
    local SECURITY_TOOLS=(
        # VPN and networking
        "openvpn"           # VPN client
        "wireguard-tools"   # WireGuard VPN
        "openssh"           # SSH client/server
        "sshfs"             # SSH filesystem
        
        # Encryption
        "gnupg"             # GPG encryption
        "age"               # Modern encryption
        "tomb"              # File encryption
        
        # Password management
        "pass"              # Password store
        "pwgen"             # Password generator
        
        # Network security
        "nmap"              # Network mapper
        "netcat"            # Network swiss knife
        "wireshark-cli"     # Packet analyzer
        "tcpdump"           # Packet capture
        
        # System security
        "lynis"             # Security auditing
        "rkhunter"          # Rootkit hunter
        "clamav"            # Antivirus
        
        # Firewall
        "ufw"               # Uncomplicated firewall
        "iptables"          # IP tables
    )
    
    install_cli_group "Security Tools" "${SECURITY_TOOLS[@]}"
}

# Category 5: Media Tools
install_media_tools() {
    print_step "Installing Media Tools"
    
    local MEDIA_TOOLS=(
        # Image processing
        "imagemagick"       # Image manipulation
        "graphicsmagick"    # Graphics processing
        "exiftool"          # Metadata editor
        "jpegoptim"         # JPEG optimizer
        "optipng"           # PNG optimizer
        
        # Audio processing
        "ffmpeg"            # Video/audio converter
        "sox"               # Audio processor
        "lame"              # MP3 encoder
        "flac"              # FLAC codec
        
        # Video processing
        "youtube-dl"        # Video downloader
        "yt-dlp"            # YouTube downloader (fork)
        
        # Document processing
        "pandoc"            # Document converter
        "poppler"           # PDF utilities
        "ghostscript"       # PostScript interpreter
        
        # Font tools
        "fontconfig"        # Font configuration
        "ttf-liberation"    # Liberation fonts
    )
    
    install_cli_group "Media Tools" "${MEDIA_TOOLS[@]}"
}

# Category 6: Admin & Laptop Tools
install_admin_laptop_tools() {
    print_step "Installing Admin & Laptop Tools"
    
    local ADMIN_TOOLS=(
        # System administration
        "rsync"             # File synchronization
        "rclone"            # Cloud storage sync
        "borgbackup"        # Backup solution
        "restic"            # Modern backup
        
        # Disk management
        "gparted"           # Partition editor
        "hdparm"            # Hard disk parameters
        "smartmontools"     # Hard disk monitoring
        "ncdu"              # Disk usage analyzer
        
        # Process management
        "supervisor"        # Process control
        "systemd"           # System manager
        
        # Network administration
        "bind-tools"        # DNS utilities (dig, nslookup)
        "traceroute"        # Network route tracing
        "mtr"               # Network diagnostics
        "iperf3"            # Network performance
        "bandwhich"         # Network utilization
        
        # Laptop-specific tools
        "acpi"              # Power management info
        "powertop"          # Power consumption analyzer
        "tlp"               # Power management
        "thermald"          # Thermal management
        "cpupower"          # CPU frequency control
        "laptop-mode-tools" # Laptop power savings
        
        # Hardware monitoring
        "lm_sensors"        # Hardware sensors
        "hddtemp"           # Hard drive temperature
        "psensor"           # Temperature monitor
        
        # USB tools
        "usbutils"          # USB utilities (lsusb)
        "udisks2"           # Disk management
    )
    
    install_cli_group "Admin & Laptop Tools" "${ADMIN_TOOLS[@]}"
}

# Category 7: Shell Enhancements
install_shell_enhancements() {
    print_step "Installing Shell Enhancements"
    
    local SHELL_TOOLS=(
        "zsh"               # Z shell
        "fish"              # Fish shell
        "bash-completion"   # Bash completions
        "zsh-completions"   # Zsh completions
    )
    
    install_cli_group "Shell Enhancement Tools" "${SHELL_TOOLS[@]}"
    
    # Configure shell enhancements
    configure_shell_configs
}

# ============================================================================
# MAIN INSTALLATION LOGIC
# ============================================================================

# Function to install a package group with error handling
install_cli_group() {
    local group_name="$1"
    shift
    local packages=("$@")
    
    print_info "Installing $group_name..."
    
    local failed_packages=()
    local installed_count=0
    
    for package in "${packages[@]}"; do
        if install_aur_package "$package"; then
            print_success "✓ $package"
            ((installed_count++))
        else
            print_warning "✗ $package (failed)"
            failed_packages+=("$package")
        fi
    done
    
    if [ ${#failed_packages[@]} -eq 0 ]; then
        print_success "$group_name: All packages installed ($installed_count/${#packages[@]})"
    else
        print_warning "$group_name: $installed_count/${#packages[@]} packages installed"
        print_info "Failed packages: ${failed_packages[*]}"
    fi
    
    return 0
}

# Configure shell enhancements
configure_shell_configs() {
    print_info "Configuring shell enhancements..."
    
    # Create basic aliases
    local aliases_file="$HOME/.bash_aliases"
    
    if [ ! -f "$aliases_file" ]; then
        print_info "Creating shell aliases..."
        cat > "$aliases_file" << 'EOF'
# ALIE CLI Tool Aliases
# Modern replacements for traditional commands

# File operations
alias ls='exa --icons --git'
alias ll='exa -l --icons --git'
alias la='exa -la --icons --git'
alias tree='exa --tree --icons'

# Text viewing
alias cat='bat --style=auto'
alias less='bat --style=auto --pager="less -RF"'

# Search and find
alias find='fd'
alias grep='rg'

# System monitoring
alias top='btop'
alias df='duf'

# Shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias myip='curl -s https://icanhazip.com'
alias weather='curl wttr.in'
EOF
        print_success "Shell aliases created"
    fi
    
    # Ensure .bashrc sources aliases
    if ! grep -q "bash_aliases" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Load aliases" >> "$HOME/.bashrc" 
        echo "[ -f ~/.bash_aliases ] && source ~/.bash_aliases" >> "$HOME/.bashrc"
        print_success "Aliases added to .bashrc"
    fi
}

# Main execution
main() {
    # Validate environment
    validate_user_environment
    validate_aur_helper
    
    print_success "Environment validation completed"
    
    # Get user selection
    selected_categories=($(get_user_selection))
    
    # Confirm installation
    confirm_installation "${selected_categories[@]}"
    
    # Install selected categories
    for category in "${selected_categories[@]}"; do
        case "$category" in
            1) install_archive_tools ;;
            2) install_system_utilities ;;
            3) install_development_tools ;;
            4) install_security_tools ;;
            5) install_media_tools ;;
            6) install_admin_laptop_tools ;;
            7) install_shell_enhancements ;;
        esac
    done
    
    # Mark progress
    save_progress "05-cli-tools-installed"
    
    print_section_footer "Interactive CLI Tools Installation Completed"
    
    # Show summary
    echo ""
    print_success "Selected CLI tools installation completed!"
    echo ""
    print_info "Installed categories:"
    for category in "${selected_categories[@]}"; do
        case "$category" in
            1) echo "  • ${CYAN}Archive Tools${NC}: Extractors and compressors" ;;
            2) echo "  • ${CYAN}System Utilities${NC}: Modern CLI replacements" ;;
            3) echo "  • ${CYAN}Development Tools${NC}: Compilers and build systems" ;;
            4) echo "  • ${CYAN}Security Tools${NC}: VPN, encryption, security auditing" ;;
            5) echo "  • ${CYAN}Media Tools${NC}: Audio, video, image processing" ;;
            6) echo "  • ${CYAN}Admin & Laptop Tools${NC}: System monitoring and power management" ;;
            7) echo "  • ${CYAN}Shell Enhancements${NC}: Aliases and configurations" ;;
        esac
    done
    echo ""
    print_info "Next steps:"
    echo "  ${CYAN}1.${NC} Install desktop applications: ${YELLOW}bash install/221-desktop-install.sh${NC}"
    echo "  ${CYAN}2.${NC} Restart terminal or run: ${YELLOW}source ~/.bashrc${NC}"
    echo "  ${CYAN}3.${NC} Enjoy your selected CLI tools!"
}

# Trap cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "CLI tools installation failed!"
    fi
}
trap cleanup EXIT

# Run main function
main "$@"