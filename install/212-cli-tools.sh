#!/bin/bash
# ALIE Interactive CLI Tools Installation
# Select and install only the CLI tools categories you want
# Run as regular user (not root)
#
# [WARNING] WARNING: EXPERIMENTAL SCRIPT
# This script is provided AS-IS without warranties.
# Review the code before running and use at your own risk.

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Add signal handling for graceful interruption
trap 'echo ""; print_warning "CLI tools installation cancelled by user (Ctrl+C)"; exit 130' INT

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

# Information about the script
SCRIPT_NAME="Interactive CLI Tools Installation"
SCRIPT_DESC="Select and install CLI tools categories based on your needs"

print_section_header "$SCRIPT_NAME" "$SCRIPT_DESC"

# ============================================================================
# INTERACTIVE MENU FUNCTIONS
# ============================================================================

# Select individual packages from all categories
select_individual_packages() {
    local all_packages=()
    local package_descriptions=()
    local selected_packages=()
    
    # Define all available packages with descriptions
    # Archive Tools
    all_packages+=("7zip" "unrar" "unace" "lrzip" "zstd" "lz4" "p7zip" "cpio" "pax" "atool")
    package_descriptions+=("7zip:7-Zip archiver" "unrar:RAR extraction" "unace:ACE extraction" 
                          "lrzip:Long range ZIP" "zstd:Modern compression" "lz4:Fast compression"
                          "p7zip:7-Zip for POSIX" "cpio:CPIO archiver" "pax:POSIX archiver" "atool:Archive tool wrapper")
    
    # System Utilities
    all_packages+=("htop" "btop" "iotop" "iftop" "ncdu" "tmux" "screen" "exa" "bat" "fd" "ripgrep" "fzf" "tldr" "trash-cli")
    package_descriptions+=("htop:Process monitor" "btop:Modern system monitor" "iotop:I/O monitor" 
                          "iftop:Network monitor" "ncdu:Disk usage analyzer" "tmux:Terminal multiplexer"
                          "screen:Terminal multiplexer" "exa:Modern ls" "bat:Better cat" "fd:Better find"
                          "ripgrep:Fast grep" "fzf:Fuzzy finder" "tldr:Simplified man pages" "trash-cli:Safe rm")
    
    # Development Tools - Core
    all_packages+=("base-devel" "git" "cmake" "ninja" "meson" "linux-headers" "linux-lts-headers" "dkms")
    package_descriptions+=("base-devel:Essential build tools (gcc, make, etc)" "git:Version control" "cmake:Build system"
                          "ninja:Fast build system" "meson:Modern build system" "linux-headers:Current kernel headers"
                          "linux-lts-headers:LTS kernel headers" "dkms:Dynamic kernel modules")
    
    # Development Tools - Build Optimization
    all_packages+=("ccache" "distcc" "sccache")
    package_descriptions+=("ccache:Compiler cache (C/C++)" "distcc:Distributed compilation" "sccache:Shared compilation cache (Rust)")
    
    # Development Tools - GCC Variants
    all_packages+=("gcc-ada" "gcc-fortran" "gcc-go" "gcc-objc" "gcc-m2" "gcc-d")
    package_descriptions+=("gcc-ada:GCC Ada compiler (GNAT)" "gcc-fortran:GCC Fortran compiler" 
                          "gcc-go:GCC Go frontend (gccgo)" "gcc-objc:GCC Objective-C compiler"
                          "gcc-m2:GCC Modula-2 compiler" "gcc-d:GCC D language compiler")
    
    # Development Tools - Multilib
    all_packages+=("multilib-devel")
    package_descriptions+=("multilib-devel:32-bit development libraries")
    
    # Development Tools - LLVM/Clang
    all_packages+=("clang" "llvm" "lld" "lldb" "compiler-rt")
    package_descriptions+=("clang:LLVM C/C++ compiler" "llvm:LLVM compiler toolkit" 
                          "lld:LLVM linker" "lldb:LLVM debugger" "compiler-rt:LLVM runtime libraries")
    
    # Development Tools - Rust
    all_packages+=("rust" "rust-analyzer" "cargo-bloat" "cargo-edit" "cargo-outdated")
    package_descriptions+=("rust:Rust language toolchain" "rust-analyzer:Rust LSP server" 
                          "cargo-bloat:Find what takes space in binary" "cargo-edit:Cargo subcommands (add/rm/upgrade)"
                          "cargo-outdated:Check outdated dependencies")
    
    # Development Tools - Go
    all_packages+=("go" "gopls" "delve")
    package_descriptions+=("go:Go programming language" "gopls:Go language server" "delve:Go debugger")
    
    # Development Tools - Python
    all_packages+=("python" "python-pip" "python-virtualenv" "python-pipenv" "python-poetry" "ipython" "pyenv")
    package_descriptions+=("python:Python 3 interpreter" "python-pip:Python package installer" 
                          "python-virtualenv:Python virtual environments" "python-pipenv:Python workflow tool"
                          "python-poetry:Python dependency management" "ipython:Enhanced Python shell" 
                          "pyenv:Python version manager")
    
    # Development Tools - Lua
    all_packages+=("lua" "luajit" "luarocks")
    package_descriptions+=("lua:Lua scripting language" "luajit:LuaJIT compiler" "luarocks:Lua package manager")
    
    # Development Tools - Other Languages
    all_packages+=("nodejs" "npm" "yarn" "ruby" "perl" "julia" "zig")
    package_descriptions+=("nodejs:JavaScript runtime" "npm:Node package manager" "yarn:Fast package manager"
                          "ruby:Ruby language" "perl:Perl language" "julia:Julia language" "zig:Zig language")
    
    # Security Tools
    all_packages+=("ufw" "firewalld" "firejail" "apparmor" "openvpn" "wireguard-tools" "nmap" "wireshark-cli" 
                   "tcpdump" "gnupg" "pass" "keepassxc")
    package_descriptions+=("ufw:Simple firewall" "firewalld:Dynamic firewall" "firejail:Sandboxing" "apparmor:Security module"
                          "openvpn:VPN client" "wireguard-tools:Modern VPN" "nmap:Network scanner"
                          "wireshark-cli:Packet analyzer" "tcpdump:Packet capture" "gnupg:Encryption"
                          "pass:Password manager" "keepassxc:Password manager GUI")
    
    # Media Tools
    all_packages+=("alsa-utils" "alsa-tools" "alsa-firmware" "sof-firmware" "ffmpeg" "imagemagick" "gifsicle" "sox" "flac" "opus-tools" "mediainfo" "exiftool" "youtube-dl")
    package_descriptions+=("alsa-utils:ALSA utilities" "alsa-tools:ALSA tools" "alsa-firmware:ALSA firmware" "sof-firmware:Sound Open Firmware"
                          "ffmpeg:Video/audio converter" "imagemagick:Image manipulation" "gifsicle:GIF tools"
                          "sox:Audio processing" "flac:FLAC codec" "opus-tools:Opus codec"
                          "mediainfo:Media information" "exiftool:Metadata editor" "youtube-dl:Video downloader")
    
    # Admin & Laptop Tools
    all_packages+=("android-udev" "tlp" "powertop" "acpi" "lm_sensors" "smartmontools" "hdparm" "rsync" "rclone" 
                   "ddrescue" "testdisk" "stress" "cpupower")
    package_descriptions+=("android-udev:Android device rules" "tlp:Power management" "powertop:Power analyzer" "acpi:Battery info"
                          "lm_sensors:Hardware monitoring" "smartmontools:Disk health" "hdparm:Disk tuning"
                          "rsync:File sync" "rclone:Cloud sync" "ddrescue:Data recovery"
                          "testdisk:Partition recovery" "stress:System stress test" "cpupower:CPU frequency")
    
    # Shell Enhancements
    all_packages+=("zsh" "fish" "oh-my-zsh-git" "starship" "zoxide" "autojump" "thefuck")
    package_descriptions+=("zsh:Z shell" "fish:Friendly shell" "oh-my-zsh-git:Zsh framework"
                          "starship:Cross-shell prompt" "zoxide:Smart cd" "autojump:Directory jumper"
                          "thefuck:Command corrector")
    
    # Interactive selection
    clear
    echo ""
    print_section_header "Individual Package Selection" "Choose specific packages to install"
    echo ""
    print_info "Instructions:"
    echo "  - Type package number to toggle selection"
    echo "  - Type 'all' to select all packages"
    echo "  - Type 'none' to deselect all"
    echo "  - Type 'search <term>' to filter packages"
    echo "  - Type 'I' to install selected packages"
    echo "  - Type 'Q' to cancel"
    echo ""
    
    local filter=""
    local input
    
    while true; do
        clear
        echo ""
        print_section_header "Individual Package Selection" "Choose specific packages to install"
        echo ""
        
        if [ -n "$filter" ]; then
            print_info "Filter: '$filter' (type 'clear' to remove filter)"
            echo ""
        fi
        
        # Display packages
        local idx=1
        local displayed_indices=()
        local displayed_packages=()
        
        for i in "${!all_packages[@]}"; do
            local pkg="${all_packages[$i]}"
            local desc="${package_descriptions[$i]#*:}"
            
            # Apply filter if set
            if [ -n "$filter" ] && ! [[ "$pkg" =~ $filter ]] && ! [[ "$desc" =~ $filter ]]; then
                continue
            fi
            
            displayed_indices+=("$i")
            displayed_packages+=("$pkg")
            
            local status=" "
            if printf '%s\n' "${selected_packages[@]}" | grep -Fqx -- "$pkg"; then
                status="${GREEN}[X]${NC}"
            fi
            
            printf "  [%2d] %s %-25s - %s\n" "$idx" "$status" "$pkg" "$desc"
            ((idx++))
        done
        
        echo ""
        if [ ${#selected_packages[@]} -gt 0 ]; then
            print_info "Selected: ${#selected_packages[@]} package(s)"
        else
            print_warning "No packages selected yet"
        fi
        echo ""
        
        printf '%s' "${CYAN}Enter number, 'all', 'none', 'search <term>', 'I' to install, 'Q' to cancel: ${NC}"
        read -r input
        
        case "$input" in
            [0-9]|[0-9][0-9]|[0-9][0-9][0-9])
                if [ "$input" -ge 1 ] && [ "$input" -lt "$idx" ]; then
                    local pkg_idx=$((input - 1))
                    local actual_idx="${displayed_indices[$pkg_idx]}"
                    local pkg="${all_packages[$actual_idx]}"
                    
                    if printf '%s\n' "${selected_packages[@]}" | grep -Fqx -- "$pkg"; then
                        mapfile -t selected_packages < <(printf '%s\n' "${selected_packages[@]}" | grep -Fvx -- "$pkg")
                    else
                        selected_packages+=("$pkg")
                    fi
                else
                    print_warning "Invalid number"
                    sleep 1
                fi
                ;;
            all)
                selected_packages=("${all_packages[@]}")
                ;;
            none)
                selected_packages=()
                ;;
            search*)
                filter="${input#search }"
                filter="${filter## }"
                ;;
            clear)
                filter=""
                ;;
            [iI])
                if [ ${#selected_packages[@]} -eq 0 ]; then
                    print_warning "No packages selected"
                    sleep 1
                else
                    echo "${selected_packages[*]}"
                    return 0
                fi
                ;;
            [qQ])
                return 1
                ;;
            *)
                print_warning "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Show main menu and get user selection
show_main_menu() {
    clear
    echo ""
    print_section_header "CLI Tools Categories" "Choose what to install"
    echo ""
    print_info "Available categories:"
    echo ""
    echo "  ${CYAN}1.${NC} [+] Archive Tools        - Extractors, compressors (7zip, rar, zstd)"
    echo "  ${CYAN}2.${NC} [*] System Utilities     - Modern CLI replacements (exa, bat, fd, ripgrep)"
    echo "  ${CYAN}3.${NC} [+] Development Tools    - Compilers, build systems, linux-headers"
    echo "  ${CYAN}4.${NC} [#] Security Tools       - VPN, encryption, security auditing"
    echo "  ${CYAN}5.${NC} [~] Media Tools          - Audio, video, image processing"
    echo "  ${CYAN}6.${NC} [>] Admin & Laptop Tools - System monitoring, power management"
    echo "  ${CYAN}7.${NC} [~] Shell Enhancements   - Prompt, aliases, configurations"
    echo ""
    echo "  ${CYAN}A.${NC} [A] Install All Categories"
    echo "  ${CYAN}C.${NC} [C] Custom Selection (choose individual packages)"
    echo "  ${CYAN}Q.${NC} [X] Quit without installing"
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
        
        printf '%s' "${CYAN}Select categories (1-7), 'A' for all, 'C' for custom, 'I' to install, 'Q' to quit: ${NC}"
        read -r input
        
        case "$input" in
            [1-7])
                # Toggle category selection
                if printf '%s\n' "${selected_categories[@]}" | grep -Fqx -- "$input"; then
                    # Remove from selection
                    mapfile -t selected_categories < <(printf '%s\n' "${selected_categories[@]}" | grep -Fvx -- "$input")
                else
                    # Add to selection
                    selected_categories+=("$input")
                fi
                ;;
            [aA])
                selected_categories=("1" "2" "3" "4" "5" "6" "7")
                ;;
            [cC])
                # Custom individual package selection
                local custom_packages
                custom_packages=$(select_individual_packages)
                if [ -n "$custom_packages" ]; then
                    echo "custom:$custom_packages"
                    return 0
                fi
                ;;
            [iI])
                if [ ${#selected_categories[@]} -eq 0 ]; then
                    print_warning "No categories selected. Please select at least one category."
                    smart_clear
                    read -r -p "Press Enter to continue..."
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
                smart_clear
                read -r -p "Press Enter to continue..."
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
        echo "  - ${CYAN}$name${NC}"
    done
    echo ""
    
    while true; do
        printf '%s' "${YELLOW}Proceed with installation? (y/N): ${NC}"
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
        "cpio"              # CPIO archiver
        "pax"               # POSIX archiver
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
        "base-devel"        # Essential build tools (gcc, make, etc)
        "cmake"             # Cross-platform build system
        "ninja"             # Fast build system
        "meson"             # Modern build system
        "make"              # GNU Make
        "autoconf"          # Configure script generator
        "automake"          # Makefile generator
        "pkgconf"           # Package config
        
        # Kernel development
        "linux-headers"     # Current kernel headers
        "linux-lts-headers" # LTS kernel headers
        "dkms"              # Dynamic kernel modules
        
        # Build optimization
        "ccache"            # Compiler cache
        "distcc"            # Distributed compilation
        "sccache"           # Shared compilation cache
        
        # Version control
        "git"               # Git version control
        "git-lfs"           # Git Large File Storage
        
        # GCC compiler variants
        "gcc-ada"           # GCC Ada (GNAT)
        "gcc-fortran"       # GCC Fortran
        "gcc-go"            # GCC Go frontend
        "gcc-objc"          # GCC Objective-C
        "gcc-m2"            # GCC Modula-2
        "gcc-d"             # GCC D language
        
        # Multilib support
        "multilib-devel"    # 32-bit development libraries
        
        # LLVM/Clang toolchain
        "clang"             # LLVM C/C++ compiler
        "llvm"              # LLVM toolkit
        "lld"               # LLVM linker
        "lldb"              # LLVM debugger
        
        # Rust toolchain
        "rust"              # Rust language
        "rust-analyzer"     # Rust LSP server
        
        # Go toolchain
        "go"                # Go language
        "gopls"             # Go LSP server
        "delve"             # Go debugger
        
        # Python toolchain
        "python"            # Python 3
        "python-pip"        # Package installer
        "python-virtualenv" # Virtual environments
        "ipython"           # Enhanced shell
        
        # Lua
        "lua"               # Lua language
        "luajit"            # LuaJIT compiler
        "luarocks"          # Lua packages
        
        # Other languages
        "nodejs"            # JavaScript runtime
        "npm"               # Node package manager
        "ruby"              # Ruby language
        "perl"              # Perl language
        
        # Debugging tools
        "gdb"               # GNU Debugger
        "valgrind"          # Memory debugging
        "strace"            # System call tracer
        "ltrace"            # Library call tracer
        "perf"              # Performance profiler
        
        # Documentation
        "man-db"            # Manual pages
        "man-pages"         # Linux manual pages
        "tldr"              # Simplified manuals
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
        "firewalld"         # Dynamic firewall daemon
        "iptables"          # IP tables
    )
    
    install_cli_group "Security Tools" "${SECURITY_TOOLS[@]}"
    
    # Configure firewall after installation
    configure_firewall_after_install
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
        
        # Audio system
        "alsa-utils"        # ALSA utilities
        "alsa-tools"        # ALSA advanced tools
        "alsa-firmware"     # ALSA firmware files
        "sof-firmware"      # Sound Open Firmware
        
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
        
        # Device support
        "android-udev"      # Android device udev rules
        
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
            print_success "[OK] $package"
            ((installed_count++))
        else
            print_warning "[!!] $package (failed)"
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
        {
            echo ""
            echo "# Load aliases"
            echo "[ -f ~/.bash_aliases ] && source ~/.bash_aliases"
        } >> "$HOME/.bashrc"
        print_success "Aliases added to .bashrc"
    fi
}

# Configure firewall after installation
configure_firewall_after_install() {
    print_info "Configuring firewall..."
    
    # Check if running as root (needed for firewall configuration)
    if [ "$EUID" -eq 0 ]; then
        # Running as root - configure firewall directly
        if command -v ufw &>/dev/null; then
            print_info "UFW detected - applying basic configuration..."
            # Load config functions
            local LIB_DIR
            LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
            if [ -f "$LIB_DIR/config-functions.sh" ]; then
                # shellcheck source=../lib/config-functions.sh
                # shellcheck disable=SC1091
                source "$LIB_DIR/config-functions.sh"
                
                # Execute UFW basic configuration
                execute_config_script "firewall/ufw-basic.sh"
                print_success "UFW configured with basic settings"
            else
                print_warning "config-functions.sh not found, skipping firewall configuration"
            fi
        elif command -v firewall-cmd &>/dev/null; then
            print_info "Firewalld detected - applying basic configuration..."
            # Load config functions
            local LIB_DIR
            LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
            if [ -f "$LIB_DIR/config-functions.sh" ]; then
                # shellcheck source=../lib/config-functions.sh
                # shellcheck disable=SC1091
                source "$LIB_DIR/config-functions.sh"
                
                # Execute Firewalld basic configuration
                execute_config_script "firewall/firewalld-basic.sh"
                print_success "Firewalld configured with basic settings"
            else
                print_warning "config-functions.sh not found, skipping firewall configuration"
            fi
        else
            print_info "No supported firewall detected"
        fi
    else
        # Running as user - inform user to configure firewall as root
        print_info "Firewall configuration requires root privileges"
        print_info "Run the following as root to configure firewall:"
        echo "  ${YELLOW}bash install/212-cli-tools.sh${NC} (select security tools again)"
        echo "  ${YELLOW}or manually configure your firewall${NC}"
    fi
}

# Main execution
main() {
    # Validate environment
    validate_user_environment
    validate_aur_helper
    
    print_success "Environment validation completed"
    
    # Get user selection
    local selection
    selection=$(get_user_selection)
    
    # Check if custom selection
    if [[ "$selection" == custom:* ]]; then
        # Custom package installation
        local custom_packages="${selection#custom:}"
        
        print_step "Installing Custom Package Selection"
        print_info "Installing ${#custom_packages[@]} selected packages..."
        
        local failed_packages=()
        local installed_count=0
        
        for package in $custom_packages; do
            if install_aur_package "$package"; then
                print_success "[OK] $package"
                ((installed_count++))
            else
                print_warning "[!!] $package (failed)"
                failed_packages+=("$package")
            fi
        done
        
        if [ ${#failed_packages[@]} -eq 0 ]; then
            print_success "Custom selection: All packages installed ($installed_count packages)"
        else
            print_warning "Custom selection: $installed_count packages installed"
            print_info "Failed packages: ${failed_packages[*]}"
        fi
        
        # Mark progress
        save_progress "05-cli-tools-custom-installed"
        
        print_section_footer "Custom Package Installation Completed"
        
        echo ""
        print_success "Custom package installation completed!"
        print_info "Installed $installed_count packages"
        echo ""
        print_info "Next steps:"
        echo "  ${CYAN}1.${NC} Restart terminal or run: ${YELLOW}source ~/.bashrc${NC}"
        echo "  ${CYAN}2.${NC} Enjoy your selected packages!"
        
        return 0
    fi
    
    # Category-based installation
    # Split the selected categories into an array safely
    local selected_categories
    read -r -a selected_categories <<< "$selection"
    
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
            1) echo "  - ${CYAN}Archive Tools${NC}: Extractors and compressors" ;;
            2) echo "  - ${CYAN}System Utilities${NC}: Modern CLI replacements" ;;
            3) echo "  - ${CYAN}Development Tools${NC}: Compilers and build systems" ;;
            4) echo "  - ${CYAN}Security Tools${NC}: VPN, encryption, security auditing" ;;
            5) echo "  - ${CYAN}Media Tools${NC}: Audio, video, image processing" ;;
            6) echo "  - ${CYAN}Admin & Laptop Tools${NC}: System monitoring and power management" ;;
            7) echo "  - ${CYAN}Shell Enhancements${NC}: Aliases and configurations" ;;
        esac
    done
    echo ""
    print_info "Next steps:"
    echo "  ${CYAN}1.${NC} Install desktop applications: ${YELLOW}bash install/221-desktop-install.sh${NC}"
    echo "  ${CYAN}2.${NC} Restart terminal or run: ${YELLOW}source ~/.bashrc${NC}"
    echo "  ${CYAN}3.${NC} Enjoy your selected CLI tools!"
}

# Trap cleanup on exit
setup_cleanup_trap

# Run main function
main "$@"