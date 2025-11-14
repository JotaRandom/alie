# Modular Configuration System

**Date**: 2025-01-14  
**Version**: 1.0  
**Branch**: features

## 🎯 Executive Summary

A **modular configuration system** has been implemented that separates configuration files from installation scripts.

### Benefits

- ✅ Modify configurations without touching scripts
- ✅ Reuse configs across installations
- ✅ Independent version control
- ✅ Easy testing and customization
- ✅ Automated backup and restoration

## 📁 Directory Structure

```
configs/
├── README.md              # Complete system documentation
├── audio/                 # Audio configurations (ALSA, PipeWire, WirePlumber)
├── firewall/              # Firewall configs (ufw, firewalld - basic & desktop)
├── network/               # Network configs (NetworkManager, DNS, hosts)
└── sudo/                  # Privilege escalation (sudo, doas with templates)
```

## 📋 Files Created

### Configuration Files (15 files)

**Audio (3 files)**
- `audio/asound.conf` - ALSA global config with PipeWire
- `audio/pipewire.conf` - PipeWire daemon settings
- `audio/wireplumber.conf` - Session manager config

**Firewall (4 files)**
- `firewall/ufw-basic.sh` - UFW minimal (server)
- `firewall/ufw-desktop.sh` - UFW permissive (development)
- `firewall/firewalld-basic.sh` - Firewalld minimal
- `firewall/firewalld-desktop.sh` - Firewalld development

**Network (3 files)**
- `network/hosts.template` - /etc/hosts with `{{HOSTNAME}}`
- `network/NetworkManager.conf` - NetworkManager complete config
- `network/resolved.conf` - DNS/mDNS configuration

**Sudo/Doas (5 files)**
- `sudo/sudoers-user-primary.template` - Sudo as primary tool
- `sudo/sudoers-user-backup.template` - Sudo as doas backup
- `sudo/sudoers-defaults-primary` - Full sudo configuration
- `sudo/sudoers-defaults-backup` - Minimal sudo config
- `sudo/doas.conf.template` - OpenDoas with `{{USERNAME}}`

### Helper Functions (1 file)

**`lib/config-functions.sh`** - Configuration library (400+ lines)

Main functions:
- `deploy_config()` - Deploy templates with variable substitution
- `deploy_config_direct()` - Direct copy without modification
- `execute_config_script()` - Execute configuration scripts
- `validate_sudoers()` - Validate sudoers syntax
- `validate_doas()` - Validate doas syntax
- `backup_config()` - Backup to /var/backups/alie-configs/
- `list_configs()` - List available configurations
- `show_config_diff()` - Show differences between configs

### Documentation (2 files)

- **`configs/README.md`** - Complete system guide (500+ lines)
- **`docs/CONFIG-SYSTEM.md`** - This document

## 🔄 Modified Files

### `install/201-user-setup.sh`

**Changes made:**

1. **Import configuration functions** (~line 26)
```bash
source "$LIB_DIR/config-functions.sh"
```

2. **Refactored `configure_sudo_family()`** (~line 125)

**Before** (inline configs):
```bash
cat > "$user_sudoers_file" << EOF
$USERNAME ALL=(ALL:ALL) ALL
EOF
```

**After** (modular):
```bash
backup_config "$user_sudoers_file"
deploy_config "sudo/sudoers-user-${template_suffix}.template" \
    "$user_sudoers_file" "USERNAME=$USERNAME"
validate_sudoers "$user_sudoers_file"
```

3. **Refactored `configure_doas()`** (~line 198)

**Before**:
```bash
cat > "$doas_conf" << EOF
permit persist :wheel
EOF
```

**After**:
```bash
backup_config "$doas_conf"
deploy_config "sudo/doas.conf.template" "$doas_conf" "USERNAME=$USERNAME"
validate_doas "$doas_conf"
```

## 🎨 Template System

### Supported Variables

| Variable | Description | Used in |
|----------|-------------|---------|
| `{{USERNAME}}` | User created during installation | sudo, doas |
| `{{HOSTNAME}}` | System hostname | network/hosts |

### Variable Expansion

The system replaces `{{VARIABLE}}` with actual values during deployment:

```bash
# Original template
permit persist {{USERNAME}}

# After deploy_config with USERNAME=john
permit persist john
```

### Variable Validation

If a variable is not resolved, the system:
1. Shows warning with missing variables
2. Asks for user confirmation
3. Allows cancellation of deployment

## 📊 Before/After Comparison

### Before: Inline Configuration

```bash
configure_sudo() {
    cat > /etc/sudoers.d/user << EOF
    $USERNAME ALL=(ALL:ALL) ALL
    Defaults env_keep += "HOME LANG LC_*"
    EOF
    chmod 440 /etc/sudoers.d/user
}
```

**Problems:**
- ❌ Config mixed with logic
- ❌ Hard to modify
- ❌ Not reusable
- ❌ No automatic backup
- ❌ Complex testing

### After: Modular Configuration

```bash
configure_sudo() {
    backup_config "/etc/sudoers.d/user"
    deploy_config "sudo/sudoers-user-primary.template" \
        "/etc/sudoers.d/user" "USERNAME=$USERNAME"
    validate_sudoers "/etc/sudoers.d/user"
}
```

**Advantages:**
- ✅ Separation of concerns
- ✅ Easy customization
- ✅ Reusable
- ✅ Automatic backup
- ✅ Simple testing

## 🔧 Usage Examples

### Example 1: Deploy Sudo Configuration

```bash
source "$LIB_DIR/config-functions.sh"

USERNAME="john"
backup_config "/etc/sudoers.d/10-john"
deploy_config "sudo/sudoers-user-primary.template" \
    "/etc/sudoers.d/10-john" "USERNAME=$USERNAME"
chmod 440 "/etc/sudoers.d/10-john"
validate_sudoers "/etc/sudoers.d/10-john"
```

### Example 2: Deploy Firewall with Selection

```bash
source "$LIB_DIR/config-functions.sh"

echo "Select firewall:"
echo "1. UFW Basic"
echo "2. Firewalld Desktop"
read choice

case $choice in
    1) execute_config_script "firewall/ufw-basic.sh" ;;
    2) execute_config_script "firewall/firewalld-desktop.sh" ;;
esac
```

### Example 3: Complete Audio Setup

```bash
source "$LIB_DIR/config-functions.sh"

# ALSA global config
deploy_config_direct "audio/asound.conf" "/etc/asound.conf" "644"

# PipeWire
mkdir -p /etc/pipewire
deploy_config_direct "audio/pipewire.conf" "/etc/pipewire/pipewire.conf" "644"

# WirePlumber
mkdir -p /etc/wireplumber/main.conf.d
deploy_config_direct "audio/wireplumber.conf" \
    "/etc/wireplumber/main.conf.d/50-alie.conf" "644"
```

## ⚠️ Limitations and Solutions

### Limitation 1: User-Dependent Variables

**Problem**: Sudo/doas configurations depend on username known only during installation.

**Solution**: Template system with `{{USERNAME}}`
- Templates in `configs/sudo/*.template`
- Automatic substitution during deployment
- Validation of unresolved variables

### Limitation 2: Critical Permissions

**Problem**: Sudoers/doas require specific permissions or they fail.

**Solution**: Automated in `deploy_config()`
```bash
# For sudoers
chmod 440 /etc/sudoers.d/*

# For doas  
chmod 400 /etc/doas.conf
```

### Limitation 3: Syntax Validation

**Problem**: A typo in sudoers can lock you out of the system.

**Solution**: Mandatory validation
```bash
validate_sudoers() {
    visudo -c -f "$file" || return 1
}
```

## 📈 Metrics

### Lines of Code

| Category | Before | After | Change |
|----------|--------|-------|--------|
| 201-user-setup.sh (sudo) | ~100 inline | ~30 + template | -70% code |
| Separate configs | 0 files | 15 files | +15 configs |
| Helper functions | N/A | 400 lines | +1 library |
| Documentation | Inline comments | 500+ lines | +docs |

### Maintainability

| Aspect | Before | After | Improvement |
|--------|--------|-------|-------------|
| Modify firewall config | Edit bash script | Edit .sh directly | 🔥 Faster |
| Test configuration | Reinstall system | Run script/copy file | 🚀 Instant |
| Backup config | Manual | Automatic | ✅ Safe |
| Reuse config | Copy code | Use same file | ♻️ DRY |

## 🚀 Roadmap

### Pending Implementation

1. **Migrate more scripts to external configs**
   - [ ] Shell configs (bash, zsh, fish) → `configs/shell/`
   - [ ] Git configs → `configs/git/`
   - [ ] Vim/Neovim → `configs/editor/`
   - [ ] X11/i3/sway → `configs/wm/`

2. **Profile system**
   ```bash
   # configs/profiles/server.conf
   FIREWALL=firewall/ufw-basic.sh
   AUDIO=audio/minimal.conf
   
   # configs/profiles/desktop.conf
   FIREWALL=firewall/ufw-desktop.sh
   AUDIO=audio/pipewire.conf
   ```

3. **Interactive wizard**
   ```bash
   bash install/config-wizard.sh
   
   > Select profile:
   > 1. Server (minimal, secure)
   > 2. Desktop (development)
   > 3. Custom (select each)
   ```

## 🧪 Testing

### Manual Testing

```bash
# 1. Test helper functions
cd /path/to/ALIE
source lib/shared-functions.sh
source lib/config-functions.sh

# 2. Test deployment (in VM/container)
SCRIPT_DIR="$(pwd)/install"
export USERNAME="testuser"

deploy_config "sudo/doas.conf.template" \
    "/tmp/test-doas.conf" \
    "USERNAME=$USERNAME"

cat /tmp/test-doas.conf
# Verify {{USERNAME}} was replaced

# 3. Test validation
validate_doas "/tmp/test-doas.conf"
```

### Integration Testing

```bash
# In test VM
bash install/201-user-setup.sh

# Verify:
# 1. Configs deployed to /etc/
# 2. Backups in /var/backups/alie-configs/
# 3. Correct permissions (440 for sudoers, 400 for doas)
# 4. Valid syntax (validate_*)
```

## 📚 References

- **configs/README.md** - Complete system documentation
- **lib/config-functions.sh** - Source code for functions
- **ArchWiki - System Configuration** - Best practices
- **ALIE docs/** - General project documentation

## 🎉 Summary of Benefits

### For Users
- ✅ Easier customization without touching code
- ✅ Reuse configs between installations
- ✅ Test changes without risk
- ✅ Automatic backup of configurations

### For Developers
- ✅ Cleaner and more maintainable code
- ✅ Separation of logic and configuration
- ✅ Simpler testing
- ✅ Code reusability (DRY)

### For the Project
- ✅ Modularity and scalability
- ✅ Independent versioning of configs
- ✅ Centralized documentation
- ✅ Foundation for profile system

---

**Implemented by**: GitHub Copilot (Claude Sonnet 4.5)  
**Date**: 2025-01-14  
**Status**: Ready for review and commit
