#!/bin/bash
# ALIE User Setup and Basic System Tools
# This script creates the desktop user and configures sudo/privileges
# This script should be run after the first reboot, as root
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

# Load configuration deployment functions
if [ ! -f "$LIB_DIR/config-functions.sh" ]; then
    echo "ERROR: config-functions.sh not found at $LIB_DIR/config-functions.sh"
    echo "Cannot continue without configuration functions library."
    exit 1
fi

source "$LIB_DIR/config-functions.sh"

# Information about the script
SCRIPT_NAME="User Setup and Basic Tools"
SCRIPT_DESC="Creates desktop user, configures sudo/privileges, and installs basic system tools"

print_section_header "$SCRIPT_NAME" "$SCRIPT_DESC"

# Trap cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "User setup failed!"
    fi
}
trap cleanup EXIT

# Privilege escalation detection and configuration function
configure_privilege_escalation() {
    print_step "Configuring Privilege Escalation"
    
    print_info "Available privilege escalation tools:"
    echo "  1) sudo    - Traditional, most compatible (recommended)"
    echo "  2) doas    - Modern, minimal, secure (with sudo compatibility)"
    echo "  3) sudo-rs - Modern sudo rewrite in Rust (with traditional sudo backup)"
    echo "  4) run0    - Systemd privilege escalation (modern, no SUID)"
    echo ""
    print_info "Note: For maximum compatibility, sudo will be installed alongside other tools"
    
    read -p "Choose primary privilege escalation tool [1-4] (default: 1): " priv_choice
    priv_choice=${priv_choice:-1}
    
    case $priv_choice in
        1)
            PRIV_TOOL="sudo"
            PRIV_PACKAGE="sudo"
            PRIV_GROUP="wheel"
            INSTALL_DOAS_COMPAT=false
            ;;
        2)
            PRIV_TOOL="doas"
            PRIV_PACKAGE="opendoas sudo"  # Install both for compatibility
            PRIV_GROUP="wheel"
            INSTALL_DOAS_COMPAT=true
            ;;
        3)
            PRIV_TOOL="sudo-rs"
            PRIV_PACKAGE="sudo-rs sudo"  # Install both for compatibility  
            PRIV_GROUP="wheel"
            INSTALL_DOAS_COMPAT=false
            ;;
        4)
            PRIV_TOOL="run0"
            PRIV_PACKAGE="systemd sudo pokit"  # run0 comes with systemd, install sudo for compat, pokit is needed for run0
            PRIV_GROUP="wheel"
            INSTALL_DOAS_COMPAT=false
            ;;
        *)
            print_warning "Invalid choice, defaulting to sudo"
            PRIV_TOOL="sudo"
            PRIV_PACKAGE="sudo"
            PRIV_GROUP="wheel"
            INSTALL_DOAS_COMPAT=false
            ;;
    esac
    
    print_success "Selected: $PRIV_TOOL"
    if [[ "$PRIV_PACKAGE" == *" "* ]]; then
        print_info "Will also install: $(echo "$PRIV_PACKAGE" | tr ' ' '\n' | grep -v "$PRIV_TOOL" | tr '\n' ' '|| echo "none")"
    fi
    
    # Install selected privilege escalation tool(s)
    print_info "Installing privilege escalation tools: $PRIV_PACKAGE"
    run_with_retry "pacman -S --needed --noconfirm $PRIV_PACKAGE"
    
    # Configure based on selected tool
    case $PRIV_TOOL in
        "sudo"|"sudo-rs")
            configure_sudo_family
            if [ "$INSTALL_DOAS_COMPAT" = true ]; then
                configure_doas  # This won't be called with current logic, but kept for flexibility
            fi
            ;;
        "doas")
            configure_doas
            configure_sudo_family  # Always configure sudo as backup when using doas
            ;;
        "run0")
            configure_run0
            configure_sudo_family  # Configure sudo as backup when using run0
            ;;
    esac
    
    # Save preference for future scripts
    save_install_info "privilege_tool" "$PRIV_TOOL"
    print_success "$PRIV_TOOL configured successfully with compatibility layers"
}

# Configure sudo or sudo-rs using modular configuration system
configure_sudo_family() {
    local sudoers_dir="/etc/sudoers.d"
    local user_sudoers_file="$sudoers_dir/10-$USERNAME"
    local sudo_config_file="$sudoers_dir/00-alie-defaults"
    
    # Determine if this is being configured as primary or backup
    local config_type="primary"
    local template_suffix="primary"
    
    if [ "${PRIV_TOOL:-}" = "doas" ]; then
        config_type="backup"
        template_suffix="backup"
        print_info "Configuring sudo as backup/compatibility layer for doas..."
    else
        print_info "Configuring $PRIV_TOOL as primary privilege escalation tool..."
    fi
    
    # Ensure sudoers.d directory exists
    mkdir -p "$sudoers_dir"
    
    # Backup existing configurations
    backup_config "$user_sudoers_file"
    backup_config "$sudo_config_file"
    
    # Deploy user-specific sudoers configuration from template
    print_info "Deploying user sudo configuration from modular template..."
    if ! deploy_config "sudo/sudoers-user-${template_suffix}.template" \
        "$user_sudoers_file" \
        "USERNAME=$USERNAME"; then
        print_error "Failed to deploy user sudoers configuration"
        return 1
    fi
    
    # Set proper permissions for sudoers file (CRITICAL)
    chmod 440 "$user_sudoers_file"
    
    # Also ensure wheel group is enabled in main sudoers (fallback)
    if ! grep -q "^%wheel ALL=(ALL) ALL" /etc/sudoers; then
        print_info "Enabling wheel group in main sudoers as fallback..."
        sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
    fi
    
    # Deploy global sudo defaults
    print_info "Deploying global sudo defaults..."
    if ! deploy_config_direct "sudo/sudoers-defaults-${template_suffix}" \
        "$sudo_config_file" "440"; then
        print_error "Failed to deploy sudo defaults"
        return 1
    fi
    
    # Verify all sudoers files are valid
    print_info "Validating sudoers configuration..."
    if validate_sudoers "$user_sudoers_file" && visudo -c &>/dev/null; then
        print_success "✓ $PRIV_TOOL configured with sudoers.d approach (modular configs)"
        print_info "User-specific config: $user_sudoers_file"
        print_info "Global defaults: $sudo_config_file"
        print_info "Config templates: configs/sudo/"
        if [ "$config_type" = "backup" ]; then
            print_info "Note: sudo configured as backup for maximum compatibility"
        fi
    else
        print_error "✗ Sudoers configuration is invalid!"
        print_info "Removing invalid configurations..."
        rm -f "$user_sudoers_file" "$sudo_config_file"
        return 1
    fi
}

# Configure doas using modular configuration system
configure_doas() {
    local doas_conf="/etc/doas.conf"
    
    print_info "Configuring OpenDoas using modular template..."
    
    # Backup existing configuration
    backup_config "$doas_conf"
    
    # Deploy doas configuration from template
    if ! deploy_config "sudo/doas.conf.template" \
        "$doas_conf" \
        "USERNAME=$USERNAME"; then
        print_error "Failed to deploy doas configuration"
        return 1
    fi
    
    # Critical: Set exact permissions as required by ArchWiki
    print_info "Setting strict doas permissions (root:root 0400)..."
    chown root:root "$doas_conf"
    chmod 0400 "$doas_conf"
    
    # Validate configuration syntax using doas built-in validator
    print_info "Validating doas configuration syntax..."
    if validate_doas "$doas_conf"; then
        print_success "✓ doas configuration syntax is valid (modular config)"
    else
        print_error "✗ doas configuration has syntax errors!"
        print_info "Showing configuration for debugging:"
        cat "$doas_conf"
        print_info "Removing invalid configuration..."
        rm -f "$doas_conf"
        return 1
    fi
    
    # Create sudo compatibility wrapper as recommended by ArchWiki
    create_sudo_doas_compatibility
    
    # Configure bash completion for doas
    configure_doas_completion
    
    print_success "OpenDoas configured successfully (modular config)"
    print_info "Configuration details:"
    echo "  • File: $doas_conf"
    echo "  • Template: configs/sudo/doas.conf.template"
    echo "  • Permissions: root:root 0400 (strict)"
    echo "  • Features: persist (5min), full environment, GUI app support"
    echo "  • User '$USERNAME' can use: doas <command>"
    echo "  • Compatibility: sudo wrapper created"
}

# Create sudo compatibility wrapper for programs that hard-code sudo
create_sudo_doas_compatibility() {
    print_info "Creating sudo compatibility wrapper..."
    
    local sudo_wrapper="/usr/local/bin/sudo"
    local sudoedit_wrapper="/usr/local/bin/sudoedit"
    
    # Ensure /usr/local/bin exists
    mkdir -p /usr/local/bin
    
    # Create sudo wrapper script
    cat > "$sudo_wrapper" << 'EOF'
#!/bin/bash
# ALIE - Sudo to Doas compatibility wrapper
# This allows programs that hard-code 'sudo' to work with doas

# Remove --preserve-env and similar sudo-specific options that doas doesn't support
args=()
for arg in "$@"; do
    case "$arg" in
        --preserve-env*|--login|--shell|--user=*|-u|--group=*|-g)
            # Skip sudo-specific options that doas handles differently
            continue
            ;;
        *)
            args+=("$arg")
            ;;
    esac
done

# Execute with doas
exec doas "${args[@]}"
EOF
    
    # Create sudoedit wrapper
    cat > "$sudoedit_wrapper" << 'EOF'
#!/bin/bash
# ALIE - Sudoedit to Doas compatibility wrapper
# Basic sudoedit functionality using doas

if [ $# -eq 0 ]; then
    echo "Usage: sudoedit file [file...]"
    exit 1
fi

# Use doas with default editor
exec doas "${EDITOR:-nano}" "$@"
EOF
    
    # Set executable permissions
    chmod 755 "$sudo_wrapper" "$sudoedit_wrapper"
    
    print_success "Sudo compatibility wrappers created"
    print_info "• $sudo_wrapper"
    print_info "• $sudoedit_wrapper"
}

# Configure bash completion for doas
configure_doas_completion() {
    local user_bashrc="/home/$USERNAME/.bashrc"
    local completion_marker="# ALIE: doas completion"
    
    if [ -f "$user_bashrc" ] && ! grep -q "$completion_marker" "$user_bashrc"; then
        print_info "Adding doas bash completion..."
        
        cat >> "$user_bashrc" << 'EOF'

# ALIE: doas completion
# Enable bash tab completion for doas commands
if command -v doas &>/dev/null; then
    # Basic completion - treats doas arguments as separate commands
    complete -cf doas
    
    # If bash-completion is available, use enhanced completion
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        complete -F _command doas
    fi
fi

# ALIE: doas convenience aliases
alias sudo='doas'           # Main compatibility alias
alias sudoedit='doas $EDITOR'  # sudoedit compatibility

EOF
        
        print_success "Doas bash completion and aliases configured"
    fi
}

# Configure run0 (systemd privilege escalation)
configure_run0() {
    print_info "Configuring systemd run0 privilege escalation..."
    
    # Verify systemd is active and has run0
    if ! command -v run0 &>/dev/null; then
        print_error "run0 not found! This requires systemd v254+"
        print_info "Falling back to sudo configuration..."
        PRIV_TOOL="sudo"
        configure_sudo_family
        return 1
    fi
    
    # Check systemd version
    local systemd_version=$(systemctl --version | head -n1 | awk '{print $2}')
    if [ "${systemd_version:-0}" -lt 254 ]; then
        print_warning "systemd version ${systemd_version} detected. run0 requires v254+"
        print_info "Falling back to sudo configuration..."
        PRIV_TOOL="sudo"
        configure_sudo_family
        return 1
    fi
    
    print_success "run0 is available (systemd v${systemd_version})"
    
    # run0 doesn't require special configuration, but we can set some preferences
    print_info "Configuring run0 usage..."
    
    # Create a run0 alias and info file for the user
    local user_bashrc="/home/$USERNAME/.bashrc"
    local completion_marker="# ALIE: run0 configuration"
    
    if [ -f "$user_bashrc" ] && ! grep -q "$completion_marker" "$user_bashrc"; then
        print_info "Adding run0 convenience aliases..."
        
        cat >> "$user_bashrc" << 'EOF'

# ALIE: run0 configuration
# Systemd run0 privilege escalation setup

# Primary privilege escalation command
alias sr='run0'              # Short alias for run0
alias suedit='run0 $EDITOR'  # Edit files with privilege

# Compatibility aliases (programs expecting sudo)
alias sudo='run0'            # Main compatibility alias
alias sudoedit='run0 $EDITOR'  # sudoedit compatibility

# run0 specific aliases
alias run0-shell='run0 --shell'  # Interactive root shell
alias run0-user='run0 --user'    # Run as specific user

# Information function
run0-info() {
    echo "ALIE: Using systemd run0 for privilege escalation"
    echo "• No SUID binaries (more secure)"
    echo "• Integrated with systemd"
    echo "• Usage: run0 <command>"
    echo "• Shell: run0 --shell"
    if command -v run0 &>/dev/null; then
        echo "• Version: $(systemctl --version | head -n1)"
    fi
}

EOF
        
        print_success "run0 aliases and configuration added"
    fi
    
    # Ensure user is in wheel group for compatibility
    print_info "Ensuring $USERNAME is in wheel group..."
    usermod -aG wheel "$USERNAME" 2>/dev/null || true
    
    # Test run0 functionality
    print_info "Testing run0 functionality..."
    if timeout 5 run0 --dry-run true &>/dev/null; then
        print_success "[OK] run0 is working correctly"
    else
        print_warning "[!!] run0 test failed, may need interactive setup"
    fi
    
    print_success "run0 configured successfully"
    print_info "Configuration details:"
    echo "  • Tool: systemd run0 (v${systemd_version})"
    echo "  • Security: No SUID binaries"
    echo "  • Features: Integrated systemd privilege escalation"
    echo "  • User '$USERNAME' can use: run0 <command>"
    echo "  • Compatibility: sudo/sudoedit aliases created"
    echo "  • Additional: sr, suedit shortcuts available"
}

# Enhanced user creation with better validation
create_desktop_user() {
    print_step "Creating Desktop User"
    
    # Get user information
    print_info "This user will be the primary desktop user with administrative privileges"
    echo ""
    
    while true; do
        read -p "Enter username for desktop user: " USERNAME
        
        # Sanitize username
        USERNAME="${USERNAME,,}"  # Convert to lowercase
        USERNAME="${USERNAME//[[:space:]]}"  # Remove whitespace
        
        # Validate username
        if [ -z "$USERNAME" ]; then
            print_error "Username cannot be empty"
            continue
        fi
        
        # Comprehensive username validation
        if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
            print_error "Invalid username: $USERNAME"
            print_info "Username requirements:"
            echo "  • Must start with a lowercase letter or underscore"
            echo "  • Can contain only lowercase letters, numbers, underscores, and hyphens"
            echo "  • Maximum 32 characters"
            continue
        fi
        
        # Check for reserved usernames
        local RESERVED_USERS=("root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody" "systemd-network" "systemd-resolve" "systemd-timesync" "polkitd" "avahi" "colord" "gdm" "lightdm")
        local is_reserved=false
        
        for reserved in "${RESERVED_USERS[@]}"; do
            if [ "$USERNAME" = "$reserved" ]; then
                print_error "Username '$USERNAME' is reserved by the system"
                is_reserved=true
                break
            fi
        done
        
        if [ "$is_reserved" = true ]; then
            continue
        fi
        
        break
    done
    
    print_success "Username: $USERNAME"
    
    # Create user or update existing
    if id "$USERNAME" &>/dev/null; then
        print_warning "User $USERNAME already exists. Updating groups..."
        
        # Update user groups
        usermod -aG "$PRIV_GROUP,storage,optical,audio,video,network,input,power,lp" "$USERNAME"
        print_success "User groups updated"
    else
        print_info "Creating user $USERNAME..."
        
        # Create user with comprehensive groups
        # wheel/sudo: administrative access
        # storage: access to removable drives
        # optical: access to optical drives  
        # audio: access to audio devices
        # video: access to video devices
        # network: network management
        # input: access to input devices
        # power: power management
        # lp: printing
        useradd -m -G "$PRIV_GROUP,storage,optical,audio,video,network,input,power,lp" "$USERNAME"
        
        # Set user password
        echo ""
        print_info "Set password for $USERNAME:"
        while ! passwd "$USERNAME"; do
            print_warning "Password setting failed. Please try again."
        done
        
        print_success "User created successfully"
    fi
    
    # Save username for future scripts
    save_install_info "DESKTOP_USER" "$USERNAME"
    
    # Configure user shell if multiple shells are available
    configure_user_shell "$USERNAME"
    
    return 0
}

# Configure user shell
configure_user_shell() {
    local username="$1"
    
    print_step "Configuring User Shell"
    
    # Get list of installed shells from /etc/shells
    local available_shells=()
    local shell_names=()
    
    # Check which shells are installed
    if command -v bash >/dev/null 2>&1; then
        available_shells+=("/bin/bash")
        shell_names+=("bash")
    fi
    
    if command -v zsh >/dev/null 2>&1; then
        available_shells+=("/bin/zsh")
        shell_names+=("zsh")
    fi
    
    if command -v fish >/dev/null 2>&1; then
        available_shells+=("/usr/bin/fish")
        shell_names+=("fish")
    fi
    
    if command -v dash >/dev/null 2>&1; then
        available_shells+=("/bin/dash")
        shell_names+=("dash")
    fi
    
    if command -v tcsh >/dev/null 2>&1; then
        available_shells+=("/bin/tcsh")
        shell_names+=("tcsh")
    fi
    
    if command -v ksh >/dev/null 2>&1; then
        available_shells+=("/bin/ksh")
        shell_names+=("ksh")
    fi
    
    # If only bash is available, use it by default
    if [ ${#available_shells[@]} -eq 1 ]; then
        print_info "Only bash is available, using it as default shell"
        return 0
    fi
    
    # Show available shells
    print_info "Available shells:"
    echo ""
    for i in "${!shell_names[@]}"; do
        local shell_path="${available_shells[$i]}"
        local shell_name="${shell_names[$i]}"
        local num=$((i + 1))
        
        # Mark default
        if [ "$shell_path" = "/bin/bash" ]; then
            echo "  $num) $shell_name - ${shell_path} (current default)"
        else
            echo "  $num) $shell_name - ${shell_path}"
        fi
    done
    echo ""
    
    # Ask user to select shell
    read -p "Select default shell for $username [1-${#available_shells[@]}] (default: 1/bash): " shell_choice
    shell_choice=${shell_choice:-1}
    
    # Validate choice
    if ! [[ "$shell_choice" =~ ^[0-9]+$ ]] || [ "$shell_choice" -lt 1 ] || [ "$shell_choice" -gt ${#available_shells[@]} ]; then
        print_warning "Invalid choice, using bash as default"
        return 0
    fi
    
    # Get selected shell
    local selected_shell="${available_shells[$((shell_choice - 1))]}"
    local selected_name="${shell_names[$((shell_choice - 1))]}"
    
    # Change user shell
    print_info "Changing shell for $username to $selected_name..."
    if chsh -s "$selected_shell" "$username"; then
        print_success "Shell changed to: $selected_shell"
        
        # Save selection
        save_install_info "user_shell" "$selected_name"
        
        # Configure shell-specific settings
        configure_shell_environment "$username" "$selected_name"
    else
        print_error "Failed to change shell"
        return 1
    fi
}

# Configure shell-specific environment
configure_shell_environment() {
    local username="$1"
    local shell_name="$2"
    local user_home="/home/$username"
    
    print_info "Configuring $shell_name environment..."
    
    # Get configs directory
    local configs_dir="$(dirname "$SCRIPT_DIR")/configs/shell"
    
    case "$shell_name" in
        "zsh")
            local zshrc="$user_home/.zshrc"
            if [ ! -f "$zshrc" ]; then
                if [ -f "$configs_dir/zshrc" ]; then
                    cp "$configs_dir/zshrc" "$zshrc"
                    print_success "Deployed zsh configuration from: configs/shell/zshrc"
                else
                    # Fallback to inline config
                    cat > "$zshrc" << 'EOF'
# ALIE Basic Zsh Configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory sharehistory incappendhistory
autoload -Uz compinit && compinit
autoload -U colors && colors
PS1="%{$fg[green]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}%# "
alias ls='ls --color=auto'
export PATH="$HOME/.local/bin:$PATH"
EOF
                    print_warning "Using inline zsh configuration (config file not found)"
                fi
                chown "$username:$username" "$zshrc"
            fi
            ;;
            
        "fish")
            local fish_config="$user_home/.config/fish"
            mkdir -p "$fish_config"
            
            if [ ! -f "$fish_config/config.fish" ]; then
                if [ -f "$configs_dir/config.fish" ]; then
                    cp "$configs_dir/config.fish" "$fish_config/config.fish"
                    print_success "Deployed fish configuration from: configs/shell/config.fish"
                else
                    # Fallback to inline config
                    cat > "$fish_config/config.fish" << 'EOF'
# ALIE Basic Fish Configuration
set fish_greeting ""
alias ll='ls -alF'
set -gx PATH $HOME/.local/bin $PATH
EOF
                    print_warning "Using inline fish configuration (config file not found)"
                fi
                chown -R "$username:$username" "$fish_config"
            fi
            ;;
            
        "bash")
            # For bash, we can optionally deploy enhanced config
            local bashrc="$user_home/.bashrc"
            if [ -f "$configs_dir/bashrc" ] && [ ! -s "$bashrc" ]; then
                cp "$configs_dir/bashrc" "$bashrc"
                chown "$username:$username" "$bashrc"
                print_success "Deployed bash configuration from: configs/shell/bashrc"
            fi
            ;;
            
        "tcsh")
            local tcshrc="$user_home/.tcshrc"
            if [ ! -f "$tcshrc" ]; then
                if [ -f "$configs_dir/tcshrc" ]; then
                    cp "$configs_dir/tcshrc" "$tcshrc"
                    print_success "Deployed tcsh configuration from: configs/shell/tcshrc"
                else
                    # Fallback to inline config
                    cat > "$tcshrc" << 'EOF'
# ALIE Basic Tcsh Configuration
set prompt = "%{\033[1;32m%}%n@%m%{\033[0m%}:%{\033[1;34m%}%~%{\033[0m%}%# "
set history = 1000
set savehist = (1000 merge)
alias ls 'ls --color=auto'
alias ll 'ls -lh'
setenv EDITOR nano
EOF
                    print_warning "Using inline tcsh configuration (config file not found)"
                fi
                chown "$username:$username" "$tcshrc"
            fi
            ;;
            
        "ksh")
            local kshrc="$user_home/.kshrc"
            if [ ! -f "$kshrc" ]; then
                if [ -f "$configs_dir/kshrc" ]; then
                    cp "$configs_dir/kshrc" "$kshrc"
                    print_success "Deployed ksh configuration from: configs/shell/kshrc"
                else
                    # Fallback to inline config
                    cat > "$kshrc" << 'EOF'
# ALIE Basic Ksh Configuration
PS1='\u@\h:\w\$ '
HISTFILE=~/.ksh_history
HISTSIZE=1000
set -o vi
alias ls='ls --color=auto'
alias ll='ls -lh'
export EDITOR=nano
EOF
                    print_warning "Using inline ksh configuration (config file not found)"
                fi
                chown "$username:$username" "$kshrc"
            fi
            ;;
    esac
    
    print_success "$shell_name environment configured"
    return 0
}

# Install essential system tools
install_basic_tools() {
    print_step "Installing Basic System Tools"
    
    local BASIC_PACKAGES=(
        # Development tools (required for AUR)
        "git"
        "base-devel"
        
        # File system tools
        "ntfs-3g"           # NTFS support
        "exfat-utils"       # exFAT support
        "unzip"             # Archive extraction
        "zip"               # Archive creation
        "p7zip"             # 7z support
        
        # Network tools
        "wget"              # Download tool
        "curl"              # Transfer tool
        "openssh"           # SSH client/server
        
        # System information
        "lshw"              # Hardware info
        "dmidecode"         # DMI info
        "usbutils"          # USB utilities
        "pciutils"          # PCI utilities
        
        # Text editing
        "nano"              # User-friendly editor
        "vim"               # Advanced editor
        
        # System utilities
        "htop"              # Process monitor
        "tree"              # Directory tree
        "which"             # Command location
        "lsof"              # List open files
        "strace"            # System call tracer
        
        # Hardware support
        "lm_sensors"        # Hardware monitoring
        "smartmontools"     # Drive health
        
        # User directory support
        "xdg-user-dirs"     # Standard directories
    )
    
    print_info "Installing essential system tools..."
    
    for package in "${BASIC_PACKAGES[@]}"; do
        if ! pacman -Qq "$package" &>/dev/null; then
            print_info "Installing: $package"
            run_with_retry "pacman -S --needed --noconfirm $package"
        fi
    done
    
    print_success "Basic system tools installed"
}

# Configure user environment
setup_user_environment() {
    print_step "Setting Up User Environment"
    
    # Create user directories
    print_info "Creating user directories..."
    
    # Run xdg-user-dirs-update as the user to create standard directories
    if su - "$USERNAME" -c "xdg-user-dirs-update" 2>/dev/null; then
        print_success "User directories created"
    else
        print_warning "Could not create user directories automatically"
        print_info "They will be created on first login"
    fi
    
    # Set proper ownership of home directory
    print_info "Setting home directory permissions..."
    chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
    
    # Create useful directories
    local user_home="/home/$USERNAME"
    su - "$USERNAME" -c "mkdir -p '$user_home/.config' '$user_home/.cache' '$user_home/.local/share' '$user_home/.local/bin'" 2>/dev/null || true
    
    # Set up basic shell configuration for new user
    print_info "Setting up basic shell configuration..."
    
    # Create a basic .bashrc if it doesn't exist or is minimal
    local bashrc="$user_home/.bashrc"
    if [ ! -f "$bashrc" ] || [ ! -s "$bashrc" ]; then
        cat > "$bashrc" << 'EOF'
# ALIE Basic User Configuration

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History configuration
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups

# Append to history file, don't overwrite
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias h='history'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# Add ~/.local/bin to PATH if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Set a nice prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
EOF
        
        chown "$USERNAME:$USERNAME" "$bashrc"
        print_success "Basic shell configuration created"
    fi
    
    print_success "User environment configured"
}

# Enable essential services
enable_system_services() {
    print_step "Configuring System Services"
    
    # Services that should be enabled for a desktop user environment
    local SERVICES=(
        "NetworkManager"      # Network management
        "systemd-timesyncd"   # Time synchronization
        "fstrim.timer"        # SSD maintenance
        "systemd-oomd"        # Out of memory daemon
    )
    
    for service in "${SERVICES[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            print_info "$service is already enabled"
        else
            print_info "Enabling $service..."
            if systemctl enable "$service" 2>/dev/null; then
                print_success "$service enabled"
            else
                print_warning "Could not enable $service (may not be available)"
            fi
        fi
    done
    
    # Configure time synchronization
    if systemctl is-active systemd-timesyncd &>/dev/null; then
        print_success "Time synchronization is active"
    else
        print_info "Starting time synchronization..."
        systemctl start systemd-timesyncd 2>/dev/null || true
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Main script start
show_alie_banner
show_warning_banner

print_info "This script will set up:"
echo "  ✅ Desktop user account with proper groups"
echo "  ✅ Privilege escalation (sudo/doas/sudo-rs)"
echo "  ✅ Essential system tools for desktop use"
echo "  ✅ User environment and directories"
echo "  ✅ Basic system services"
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

print_success "Environment validation completed"

# Configure privilege escalation first
configure_privilege_escalation

# Create desktop user
create_desktop_user

# Install basic system tools
install_basic_tools

# Setup user environment
setup_user_environment

# Enable essential services
enable_system_services

# Mark progress
save_progress "03-user-setup-completed"

print_section_footer "User Setup Completed Successfully"

echo ""
print_success "User setup completed!"
echo ""
print_info "Summary:"
echo "  • User: ${CYAN}$USERNAME${NC}"
echo "  • Privilege tool: ${CYAN}$PRIV_TOOL${NC}"
echo "  • Groups: wheel, storage, optical, audio, video, network, input, power, lp"
echo "  • Essential tools installed"
echo "  • User environment configured"
echo ""
print_info "Next steps:"
echo "  ${CYAN}1.${NC} Install desktop environment: ${YELLOW}bash install/221-desktop-install.sh${NC}"
echo "  ${CYAN}2.${NC} Install AUR helper: ${YELLOW}bash install/211-install-aur-helper.sh${NC} (as user)"
echo "  ${CYAN}3.${NC} Install packages: ${YELLOW}bash install/212-install-packages.sh${NC} (as user)"
echo ""
print_warning "Remember: AUR scripts must be run as user $USERNAME, NOT as root!"
echo ""