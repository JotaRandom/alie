#!/bin/bash
# ALIE Configuration Deployment Helper
# Functions to deploy configuration files from /configs directory

# Get the configs directory path (relative to script location)
get_configs_dir() {
    local script_dir="$1"
    echo "$(dirname "$script_dir")/configs"
}

# Deploy configuration file with variable substitution
# Usage: deploy_config <template_file> <destination> [variables...]
# Example: deploy_config "sudo/doas.conf.template" "/etc/doas.conf" "USERNAME=john"
deploy_config() {
    local template="$1"
    local destination="$2"
    shift 2
    local variables=("$@")
    
    local configs_dir
    configs_dir=$(get_configs_dir "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}")
    local template_path
    template_path="$configs_dir/$template"
    
    if [ ! -f "$template_path" ]; then
        print_error "Template not found: $template_path"
        return 1
    fi
    
    print_info "Deploying configuration: $template → $destination"
    
    # Read template
    local content
    content=$(cat "$template_path")
    
    # Apply variable substitutions
    for var in "${variables[@]}"; do
        local key="${var%%=*}"
        local value="${var#*=}"
        # Escape special characters in value for sed
        local escaped_value
        escaped_value=$(printf '%s\n' "$value" | sed 's/[[\.*^$/]/\\&/g')
            # Use parameter expansion for literal substring replacement when safe
            content="${content//{{${key}}}/${escaped_value}}"
    done
    
    # Check if there are unresolved variables
    if echo "$content" | grep -q "{{.*}}"; then
        print_warning "Template has unresolved variables:"
        echo "$content" | grep -o "{{[^}]*}}" | sort -u
        read -r -p "Continue anyway? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Create destination directory if needed
    local dest_dir
    dest_dir=$(dirname "$destination")
    if [ ! -d "$dest_dir" ]; then
        print_info "Creating directory: $dest_dir"
        mkdir -p "$dest_dir"
    fi
    
    # Deploy configuration
    echo "$content" > "$destination"
    
    print_success "Configuration deployed: $destination"
    return 0
}

# Deploy configuration without variable substitution (direct copy)
# Usage: deploy_config_direct <source_file> <destination> [permissions]
deploy_config_direct() {
    local source="$1"
    local destination="$2"
    local permissions="${3:-644}"
    
    local configs_dir
    configs_dir=$(get_configs_dir "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}")
    local source_path="$configs_dir/$source"
    
    if [ ! -f "$source_path" ]; then
        print_error "Configuration file not found: $source_path"
        return 1
    fi
    
    print_info "Deploying configuration: $source → $destination"
    
    # Create destination directory if needed
    local dest_dir
    dest_dir=$(dirname "$destination")
    if [ ! -d "$dest_dir" ]; then
        print_info "Creating directory: $dest_dir"
        mkdir -p "$dest_dir"
    fi
    
    # Copy configuration
    cp "$source_path" "$destination"
    chmod "$permissions" "$destination"
    
    print_success "Configuration deployed: $destination (permissions: $permissions)"
    return 0
}

# Execute configuration script
# Usage: execute_config_script <script_file>
execute_config_script() {
    local script="$1"
    
    local configs_dir
    configs_dir=$(get_configs_dir "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}")
    local script_path
    script_path="$configs_dir/$script"
    
    if [ ! -f "$script_path" ]; then
        print_error "Configuration script not found: $script_path"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        print_warning "Script is not executable, making it executable..."
        chmod +x "$script_path"
    fi
    
    print_info "Executing configuration script: $script"
    
    if bash "$script_path"; then
        print_success "Configuration script executed successfully"
        return 0
    else
        print_error "Configuration script failed with exit code: $?"
        return 1
    fi
}

# List available configurations by category
# Usage: list_configs <category>
list_configs() {
    local category="$1"
    local configs_dir
    configs_dir=$(get_configs_dir "${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}")
    
    if [ -n "$category" ]; then
        local category_dir="$configs_dir/$category"
        if [ ! -d "$category_dir" ]; then
            print_error "Category not found: $category"
            return 1
        fi
        
        print_info "Available configurations in '$category':"
        while IFS= read -r file; do
            echo "  • $file"
        done < <(find "$category_dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null)
    else
        print_info "Available configuration categories:"
        while IFS= read -r dir; do
            echo "  • $dir/"
        done < <(find "$configs_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null)
    fi
}

# Validate sudo/doas configuration before deploying
# Usage: validate_sudoers <file>
validate_sudoers() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        return 1
    fi
    
    print_info "Validating sudoers syntax..."
    
    if visudo -c -f "$file" &>/dev/null; then
        print_success "✓ Sudoers syntax is valid"
        return 0
    else
        print_error "✗ Sudoers syntax is invalid!"
        return 1
    fi
}

# Validate doas configuration
# Usage: validate_doas <file>
validate_doas() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        return 1
    fi
    
    print_info "Validating doas syntax..."
    
    if doas -C "$file" &>/dev/null; then
        print_success "✓ Doas syntax is valid"
        return 0
    else
        print_error "✗ Doas syntax is invalid!"
        return 1
    fi
}

# Show configuration diff (compare template with deployed version)
# Usage: show_config_diff <template> <deployed_file>
show_config_diff() {
    local template="$1"
    local deployed="$2"
    
    local configs_dir
    configs_dir=$(get_configs_dir "$SCRIPT_DIR")
    local template_path="$configs_dir/$template"
    
    if [ ! -f "$template_path" ]; then
        print_error "Template not found: $template_path"
        return 1
    fi
    
    if [ ! -f "$deployed" ]; then
        print_warning "Deployed file not found: $deployed"
        print_info "This configuration has not been deployed yet"
        return 1
    fi
    
    print_info "Comparing configurations:"
    echo "  Template:  $template_path"
    echo "  Deployed:  $deployed"
    echo ""
    
    diff -u --color=auto "$template_path" "$deployed" || true
}

# Backup existing configuration before deploying new one
# Usage: backup_config <file>
backup_config() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        print_info "No existing configuration to backup: $file"
        return 0
    fi
    
    local backup_dir="/var/backups/alie-configs"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name
    backup_name="$(basename "$file").${timestamp}.bak"
    local backup_path
    backup_path="$backup_dir/$backup_name"
    
    mkdir -p "$backup_dir"
    
    print_info "Backing up existing configuration..."
    cp -a "$file" "$backup_path"
    
    print_success "Backup created: $backup_path"
    return 0
}
