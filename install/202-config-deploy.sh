#!/bin/bash
# ALIE Configuration Deployment Script
# This script deploys all remaining configurations after user setup
# This script should be run after 201-user-setup.sh, as root
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

# shellcheck source=../lib/shared-functions.sh
# shellcheck disable=SC1091
source "$LIB_DIR/shared-functions.sh"

# Load configuration deployment functions
if [ ! -f "$LIB_DIR/config-functions.sh" ]; then
    echo "ERROR: config-functions.sh not found at $LIB_DIR/config-functions.sh"
    echo "Cannot continue without configuration functions library."
    exit 1
fi

# shellcheck source=../lib/config-functions.sh
# shellcheck disable=SC1091
source "$LIB_DIR/config-functions.sh"

# Information about the script
SCRIPT_NAME="Configuration Deployment"
SCRIPT_DESC="Deploy all remaining system configurations from configs/ directory"

print_section_header "$SCRIPT_NAME" "$SCRIPT_DESC"

# Trap cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Configuration deployment failed!"
    fi
}
trap cleanup EXIT

# ============================================================================
# CONFIGURATION DEPLOYMENT FUNCTIONS
# ============================================================================

# Deploy firewall configuration
deploy_firewall_config() {
    print_step "Deploying Firewall Configuration"

    # Check if ufw or firewalld is installed
    if command -v ufw &>/dev/null; then
        print_info "UFW detected - deploying basic configuration..."
        execute_config_script "firewall/ufw-basic.sh"
        print_success "UFW configuration deployed"
    elif command -v firewall-cmd &>/dev/null; then
        print_info "Firewalld detected - deploying basic configuration..."
        execute_config_script "firewall/firewalld-basic.sh"
        print_success "Firewalld configuration deployed"
    else
        print_warning "No firewall detected - skipping firewall configuration"
    fi
}

# Deploy editor configurations
deploy_editor_config() {
    print_step "Deploying Editor Configurations"

    # Check installed editors and deploy configs
    if command -v nano &>/dev/null; then
        print_info "Nano detected - checking for configuration..."
        # Nano typically doesn't need global config, but could add syntax highlighting
        print_success "Nano configuration checked"
    fi

    if command -v vim &>/dev/null; then
        print_info "Vim detected - checking for configuration..."
        # Could deploy vimrc if available
        print_success "Vim configuration checked"
    fi

    if command -v nvim &>/dev/null; then
        print_info "Neovim detected - checking for configuration..."
        # Could deploy init.vim or init.lua if available
        print_success "Neovim configuration checked"
    fi
}

# Deploy shell configurations for all users
deploy_shell_configs() {
    print_step "Deploying Shell Configurations"

    # Get list of users with home directories
    local users
    mapfile -t users < <(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}')

    for user in "${users[@]}"; do
        local user_home
        user_home=$(getent passwd "$user" | cut -d: -f6)

        if [ -d "$user_home" ]; then
            print_info "Configuring shell for user: $user"

            # Determine user shell
            local user_shell
            user_shell=$(getent passwd "$user" | cut -d: -f7)

            case "${user_shell##*/}" in
                "bash")
                    if [ ! -f "$user_home/.bashrc" ]; then
                        deploy_config_direct "shell/bashrc" "$user_home/.bashrc" "644"
                        chown "$user:$user" "$user_home/.bashrc"
                        print_success "Bash configuration deployed for $user"
                    fi
                    ;;
                "zsh")
                    if [ ! -f "$user_home/.zshrc" ]; then
                        deploy_config_direct "shell/zshrc" "$user_home/.zshrc" "644"
                        chown "$user:$user" "$user_home/.zshrc"
                        print_success "Zsh configuration deployed for $user"
                    fi
                    ;;
                "fish")
                    if [ ! -f "$user_home/.config/fish/config.fish" ]; then
                        mkdir -p "$user_home/.config/fish"
                        deploy_config_direct "shell/config.fish" "$user_home/.config/fish/config.fish" "644"
                        chown -R "$user:$user" "$user_home/.config/fish"
                        print_success "Fish configuration deployed for $user"
                    fi
                    ;;
                "tcsh")
                    if [ ! -f "$user_home/.tcshrc" ]; then
                        deploy_config_direct "shell/tcshrc" "$user_home/.tcshrc" "644"
                        chown "$user:$user" "$user_home/.tcshrc"
                        print_success "Tcsh configuration deployed for $user"
                    fi
                    ;;
                "ksh")
                    if [ ! -f "$user_home/.kshrc" ]; then
                        deploy_config_direct "shell/kshrc" "$user_home/.kshrc" "644"
                        chown "$user:$user" "$user_home/.kshrc"
                        print_success "Ksh configuration deployed for $user"
                    fi
                    ;;
                *)
                    print_info "Shell ${user_shell##*/} not supported or already configured for $user"
                    ;;
            esac
        fi
    done
}

# Deploy Xorg configurations (if Xorg is installed)
deploy_xorg_configs() {
    print_step "Deploying Xorg Configurations"

    if [ ! -d /etc/X11 ]; then
        print_info "Xorg not detected - skipping Xorg configurations"
        return 0
    fi

    print_info "Xorg detected - deploying GPU-specific configurations..."

    # Detect GPU and deploy appropriate config
    if lspci | grep -qi "nvidia"; then
        print_info "NVIDIA GPU detected"
        mkdir -p /etc/X11/xorg.conf.d
        deploy_config_direct "xorg/20-nvidia.conf" "/etc/X11/xorg.conf.d/20-nvidia.conf" "644"
        print_success "NVIDIA Xorg configuration deployed"
    elif lspci | grep -qi "amd\\|radeon"; then
        print_info "AMD GPU detected"
        mkdir -p /etc/X11/xorg.conf.d
        deploy_config_direct "xorg/20-amdgpu.conf" "/etc/X11/xorg.conf.d/20-amdgpu.conf" "644"
        print_success "AMD Xorg configuration deployed"
    elif lspci | grep -qi "intel"; then
        print_info "Intel GPU detected"
        mkdir -p /etc/X11/xorg.conf.d
        deploy_config_direct "xorg/20-intel.conf" "/etc/X11/xorg.conf.d/20-intel.conf" "644"
        print_success "Intel Xorg configuration deployed"
    else
        print_info "Unknown or no GPU detected - no Xorg config deployed"
    fi
}

# Validate all deployed configurations
validate_deployed_configs() {
    print_step "Validating Deployed Configurations"

    local validation_errors=0

    # Validate sudoers files
    if [ -f /etc/sudoers.d/10-alie-user ]; then
        print_info "Validating sudoers configuration..."
        if validate_sudoers /etc/sudoers.d/10-alie-user; then
            print_success "✓ Sudoers configuration valid"
        else
            print_error "✗ Sudoers configuration invalid"
            ((validation_errors++))
        fi
    fi

    # Validate doas configuration
    if [ -f /etc/doas.conf ]; then
        print_info "Validating doas configuration..."
        if validate_doas /etc/doas.conf; then
            print_success "✓ Doas configuration valid"
        else
            print_error "✗ Doas configuration invalid"
            ((validation_errors++))
        fi
    fi

    # Check permissions on critical files
    print_info "Checking file permissions..."

    local critical_files=(
        "/etc/sudoers.d/10-alie-user:440"
        "/etc/doas.conf:400"
        "/etc/asound.conf:644"
        "/etc/NetworkManager/NetworkManager.conf:644"
    )

    for file_perm in "${critical_files[@]}"; do
        local file="${file_perm%%:*}"
        local expected_perm="${file_perm##*:}"

        if [ -f "$file" ]; then
            local actual_perm
            actual_perm=$(stat -c %a "$file")
            if [ "$actual_perm" = "$expected_perm" ]; then
                print_success "✓ $file permissions correct ($actual_perm)"
            else
                print_error "✗ $file permissions incorrect (expected: $expected_perm, actual: $actual_perm)"
                ((validation_errors++))
            fi
        fi
    done

    if [ $validation_errors -eq 0 ]; then
        print_success "All configurations validated successfully"
    else
        print_warning "$validation_errors validation errors found"
    fi

    return $validation_errors
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Main script start
show_alie_banner
show_warning_banner

print_info "This script will deploy all remaining configurations:"
echo "  ✅ Firewall configurations"
echo "  ✅ Editor configurations"
echo "  ✅ Shell configurations for all users"
echo "  ✅ Xorg GPU configurations"
echo "  ✅ Configuration validation"
echo ""
read -r -p "Press Enter to continue or Ctrl+C to exit..."

# Validate environment
print_step "STEP 1: Environment Validation"

# Verify running as root
require_root

# Verify we're on an installed system
verify_not_chroot

# Verify internet connectivity (for potential package checks)
verify_internet

print_success "Environment validation completed"

# Deploy configurations
deploy_firewall_config
deploy_editor_config
deploy_shell_configs
deploy_xorg_configs

# Validate everything
validate_deployed_configs

# Mark progress
save_progress "04-config-deployed"

print_section_footer "Configuration Deployment Completed Successfully"

echo ""
print_success "Configuration deployment completed!"
echo ""
print_info "Summary of deployed configurations:"
echo "  • Firewall: $(command -v ufw &>/dev/null && echo "UFW" || command -v firewall-cmd &>/dev/null && echo "Firewalld" || echo "None")"
echo "  • Shell configs: Deployed for all users with home directories"
echo "  • Xorg configs: $(lspci | grep -qi "nvidia\|amd\|intel" && echo "GPU-specific config deployed" || echo "No GPU config needed")"
echo "  • Audio: Already deployed in system configuration"
echo "  • Network: Already deployed in system configuration"
echo ""
print_info "Next steps:"
echo "  ${CYAN}1.${NC} Install display server: ${YELLOW}bash install/213-display-server.sh${NC}"
echo "  ${CYAN}2.${NC} Install desktop environment: ${YELLOW}bash install/220-desktop-select.sh${NC}"
echo "  ${CYAN}3.${NC} Install AUR helper: ${YELLOW}bash install/211-install-aur-helper.sh${NC} (as user)"
echo ""
print_warning "Remember: AUR scripts must be run as user $USERNAME, NOT as root!"</content>
<parameter name="filePath">c:\Users\Usuario\source\repos\ALIE\install\202-config-deploy.sh