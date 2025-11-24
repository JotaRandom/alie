# ALIE Configuration System

Modular configuration system for ALIE. Configuration files are separated from installation scripts to facilitate customization and maintenance.

## 📁 Directory Structure

```
configs/
├── audio/              # Audio configurations (ALSA, PipeWire)
├── display-managers/   # Display manager configurations (LightDM, SDDM, GDM)
├── editor/             # Editor configurations (vim, nano)
├── firewall/           # Firewall configurations (ufw, firewalld)
├── network/            # Network configurations (NetworkManager, DNS)
├── shell/              # Shell configurations (bash, zsh)
├── sudo/               # Privilege configurations (sudo, doas)
└── xorg/               # Xorg GPU configurations
```

## 🎯 System Philosophy

### Advantages of External Configurations

1. **Modularity**: Modify configurations without touching scripts
2. **Reusability**: Same config for different installations
3. **Versioning**: Independent change control
4. **Testing**: Test configurations before deployment
5. **Backup**: Easy backup and restoration

### File Types

- **`.template`**: Require variable substitution (e.g., `{{USERNAME}}`)
- **No extension or `.conf`**: Ready to copy directly
- **`.sh`**: Executable scripts for automatic configuration
- **`.plain`**: Byte-for-byte copies of config contents for manual copy/paste
- **`.example`**: Explain script effects and show resulting configurations

## 📋 Manual Configuration Application

### Using .plain Files

`.plain` files contain the exact content that would be applied by the installation scripts. Use these for manual configuration without running scripts.

#### How to Apply .plain Files

1. **Locate the .plain file** for the configuration you want to apply
2. **Copy the content** to the appropriate destination
3. **Set correct permissions** (see Security Considerations section)

**Example - Applying ALSA configuration manually:**

```bash
# Copy ALSA configuration
sudo cp configs/audio/asound.plain /etc/asound.conf

# Set correct permissions
sudo chmod 644 /etc/asound.conf
```

#### Available .plain Files

| Category | File | Destination | Permissions |
|----------|------|-------------|-------------|
| **Audio** | `asound.plain` | `/etc/asound.conf` | `644` |
| | `pipewire.plain` | `/etc/pipewire/pipewire.conf` | `644` |
| | `wireplumber.plain` | `/etc/wireplumber/main.conf.d/50-alie.conf` | `644` |
| **Display Managers** | `lightdm-slick-greeter.plain` | `/etc/lightdm/slick-greeter.conf` | `644` |
| | `sddm.plain` | `/etc/sddm.conf` | `644` |
| **Firewall** | `ufw-basic.plain` | Applied via script | N/A |
| | `ufw-desktop.plain` | Applied via script | N/A |
| | `firewalld-basic.plain` | Applied via script | N/A |
| | `firewalld-desktop.plain` | Applied via script | N/A |
| **Network** | `NetworkManager.plain` | `/etc/NetworkManager/NetworkManager.conf` | `644` |
| | `resolved.plain` | `/etc/systemd/resolved.conf` | `644` |
| **Shell** | `bashrc.plain` | `~/.bashrc` | `644` |
| | `zshrc.plain` | `~/.zshrc` | `644` |
| | `config.fish.plain` | `~/.config/fish/config.fish` | `644` |
| | `tcshrc.plain` | `~/.tcshrc` | `644` |
| | `kshrc.plain` | `~/.kshrc` | `644` |
| **Sudo** | `sudoers-defaults-primary.plain` | `/etc/sudoers.d/00-alie-defaults` | `440` |
| | `sudoers-defaults-backup.plain` | `/etc/sudoers.d/00-alie-defaults` | `440` |
| **Xorg** | `20-intel.plain` | `/etc/X11/xorg.conf.d/20-intel.conf` | `644` |
| | `20-amdgpu.plain` | `/etc/X11/xorg.conf.d/20-amdgpu.conf` | `644` |
| | `20-nvidia.plain` | `/etc/X11/xorg.conf.d/20-nvidia.conf` | `644` |

**Notes on Permissions:**
- **sudoers files** (`/etc/sudoers.d/*`): Must be `440` (root:root) for security
- **doas.conf**: Must be `400` (root:root) for security  
- **System configs** (`/etc/*`): Typically `644` (root:root)
- **User configs** (`~/.*`): `644` (user:user)

## 🔧 Automatic Configuration Deployment

### Scripts That Deploy Configurations

The following installation scripts automatically deploy configurations from `configs/`:

| Script | Configurations Deployed | When Runs |
|--------|------------------------|-----------|
| `101-configure-system.sh` | Audio (ALSA/PipeWire), Network (hosts, NM, resolved) | In chroot |
| `201-user-setup.sh` | Sudo/Doas, User shells | After first boot (as root) |
| `202-config-deploy.sh` | Firewall, Editor, Shells (all users), Xorg | After user setup (as root) |
| `213-display-server.sh` | Xorg GPU configs | During display setup |
| `221-desktop-environment.sh` | Display manager configs | During DE installation |

### Using .example Files

`.example` files show what the configuration scripts do and what the final result looks like. Use these to understand the configuration process.

#### How to Use .example Files

1. **Read the .example file** to understand what the script does
2. **Apply the configuration manually** or run the corresponding script
3. **Verify the result** matches the example

**Example - Understanding firewall configuration:**

```bash
# Read what the UFW basic script does
cat configs/firewall/ufw-basic.example

# Apply the configuration
sudo configs/firewall/ufw-basic.sh

# Or apply manually following the example
```

#### Important Notes for Manual Application

- **⚠️ Sudo/Doas configurations cannot be applied manually** because they require username substitution
- **🔒 Critical permissions must be set correctly** (especially for sudoers files)
- **📋 Firewall configurations are applied via scripts** - .plain files show intermediate states
- **🔄 Some configurations require service restarts** to take effect
- **📁 Create directories if they don't exist** (e.g., `/etc/wireplumber/main.conf.d/`)

#### Manual Application Workflow

```bash
# 1. Choose configuration category
cd configs/audio/

# 2. Read the example to understand
cat asound.example

# 3. Apply the plain content
sudo cp asound.plain /etc/asound.conf
sudo chmod 644 /etc/asound.conf

# 4. Restart relevant services if needed
sudo systemctl restart pipewire  # example for audio
```

## 📋 Configuration Categories

### 1. Sudo/Doas (`configs/sudo/`)

Privilege escalation configurations.

#### Available Files

| File | Description | Variables |
|------|-------------|-----------|
| `sudoers-user-primary.template` | Sudo config as primary tool | `{{USERNAME}}` |
| `sudoers-user-backup.template` | Sudo config as doas backup | `{{USERNAME}}` |
| `sudoers-defaults-primary` | Global sudo config (primary) | None |
| `sudoers-defaults-backup` | Global sudo config (backup) | None |
| `doas.conf.template` | OpenDoas configuration | `{{USERNAME}}` |

#### Usage in Scripts

```bash
# Load configuration functions
source "$LIB_DIR/config-functions.sh"

# Deploy configuration with variables
deploy_config "sudo/sudoers-user-primary.template" \
    "/etc/sudoers.d/10-alie-$USERNAME" \
    "USERNAME=$USERNAME"

# Set permissions (critical for sudoers)
chmod 440 "/etc/sudoers.d/10-alie-$USERNAME"

# Validate before applying
validate_sudoers "/etc/sudoers.d/10-alie-$USERNAME"
```

#### Limitation: User-Dependent Variables

**IMPORTANT**: Sudo/doas configurations **cannot** be completely static because they depend on the username, which is defined during installation.

**Implemented Solution**: Template system with `{{USERNAME}}`

### 2. Firewall (`configs/firewall/`)

Firewall configurations for different scenarios.

#### Available Files

| File | Description | Usage |
|------|-------------|-------|
| `ufw-basic.sh` | Minimal UFW (SSH only) | Servers, maximum security |
| `ufw-desktop.sh` | Permissive UFW (development) | Workstations, development |
| `firewalld-basic.sh` | Minimal Firewalld | Servers with zones |
| `firewalld-desktop.sh` | Development Firewalld | Desktop with multiple zones |

#### Usage in Scripts

```bash
# Option 1: Execute configuration script directly
execute_config_script "firewall/ufw-basic.sh"

# Option 2: Give options to user
print_info "Select firewall configuration:"
echo "1. Basic (SSH only)"
echo "2. Desktop (Development)"
read -p "Choice: " choice

case $choice in
    1) execute_config_script "firewall/ufw-basic.sh" ;;
    2) execute_config_script "firewall/ufw-desktop.sh" ;;
esac
```

#### UFW vs Firewalld Differences

- **UFW**: Simple, ideal for desktop/laptop, linear configuration
- **Firewalld**: Powerful, zone-based, ideal for servers

**Note**: They are mutually exclusive - activate only one.

### 3. Audio (`configs/audio/`)

Audio system configurations (ALSA + PipeWire).

#### Available Files

| File | Destination | Description |
|------|-------------|-------------|
| `asound.conf` | `/etc/asound.conf` | Global ALSA config |
| `pipewire.conf` | `/etc/pipewire/pipewire.conf` | PipeWire daemon config |
| `wireplumber.conf` | `/etc/wireplumber/main.conf.d/50-alie.conf` | Session manager |

#### Usage in Scripts

```bash
# Deploy audio configurations
deploy_config_direct "audio/asound.conf" "/etc/asound.conf" "644"
deploy_config_direct "audio/pipewire.conf" "/etc/pipewire/pipewire.conf" "644"

# WirePlumber requires specific directory
mkdir -p /etc/wireplumber/main.conf.d
deploy_config_direct "audio/wireplumber.conf" \
    "/etc/wireplumber/main.conf.d/50-alie.conf" "644"
```

### 4. Display Managers (`configs/display-managers/`)

Configurations for graphical login managers.

#### Available Files

| File | Destination | Description |
|------|-------------|-------------|
| `lightdm-slick-greeter.conf` | `/etc/lightdm/slick-greeter.conf` | Slick Greeter config (Cinnamon) |
| `sddm.conf` | `/etc/sddm.conf` | SDDM configuration (KDE Plasma) |
| `configure-lightdm-slick.sh` | Executable script | Modifies lightdm.conf to use Slick Greeter |

#### Usage in Scripts

```bash
# LightDM with Slick Greeter (Cinnamon/Mint)
# Requires modification of main lightdm.conf
backup_config "/etc/lightdm/lightdm.conf"
execute_config_script "display-managers/configure-lightdm-slick.sh"
deploy_config_direct "display-managers/lightdm-slick-greeter.conf" \
    "/etc/lightdm/slick-greeter.conf" "644"

# SDDM (KDE Plasma)
# Optional configuration - SDDM works without config
deploy_config_direct "display-managers/sddm.conf" \
    "/etc/sddm.conf" "644"

# GDM (GNOME)
# No configuration required - uses Wayland by default
```

#### Important Notes

- **LightDM GTK Greeter** (XFCE4): No configuration required, it's the default greeter
- **LightDM Slick Greeter** (Cinnamon): REQUIRES manual modification of lightdm.conf
- **GDM** (GNOME): No configuration required
- **SDDM** (KDE): Optional configuration for customizing theme/behavior

### 5. Network (`configs/network/`)

Network configurations (NetworkManager, DNS, hosts).

#### Available Files

| File | Destination | Variables |
|------|-------------|-----------|
| `hosts.template` | `/etc/hosts` | `{{HOSTNAME}}` |
| `NetworkManager.conf` | `/etc/NetworkManager/NetworkManager.conf` | None |
| `resolved.conf` | `/etc/systemd/resolved.conf` | None |

#### Usage in Scripts

```bash
# Hosts with variable hostname
deploy_config "network/hosts.template" \
    "/etc/hosts" \
    "HOSTNAME=$HOSTNAME"

# NetworkManager direct
deploy_config_direct "network/NetworkManager.conf" \
    "/etc/NetworkManager/NetworkManager.conf" "644"
```

## 🔧 Helper Functions

The `lib/config-functions.sh` file provides functions for handling configurations.

### Main Functions

#### `deploy_config`
Deploys template with variable substitution.

```bash
deploy_config <template_file> <destination> [variables...]

# Example
deploy_config "sudo/doas.conf.template" "/etc/doas.conf" "USERNAME=john"
```

#### `deploy_config_direct`
Copies file without modifications.

```bash
deploy_config_direct <source_file> <destination> [permissions]

# Example
deploy_config_direct "audio/asound.conf" "/etc/asound.conf" "644"
```

#### `execute_config_script`
Executes configuration script.

```bash
execute_config_script <script_file>

# Example
execute_config_script "firewall/ufw-basic.sh"
```

#### `validate_sudoers` / `validate_doas`
Validates syntax before applying.

```bash
validate_sudoers "/etc/sudoers.d/10-alie-user"
validate_doas "/etc/doas.conf"
```

#### `backup_config`
Creates backup before modifying.

```bash
backup_config "/etc/doas.conf"
# Creates: /var/backups/alie-configs/doas.conf.20250114-153045.bak
```

#### `list_configs`
Lists available configurations.

```bash
list_configs          # Lists categories
list_configs sudo     # Lists files in category
```

## 📝 Developer Usage Guide

### Adding New Configuration

1. **Create file in `/configs/<category>/`**

```bash
# Create directory if it doesn't exist
mkdir -p configs/new-category

# Create configuration file
cat > configs/new-category/my-config.conf << 'EOF'
# My configuration
parameter = value
EOF
```

2. **If variables required, use `.template`**

```bash
cat > configs/new-category/my-config.template << 'EOF'
# User: {{USERNAME}}
user = {{USERNAME}}
home = /home/{{USERNAME}}
EOF
```

3. **Update installation script**

```bash
# In install/XXX-script.sh
source "$LIB_DIR/config-functions.sh"

deploy_config "new-category/my-config.template" \
    "/etc/my-app/config" \
    "USERNAME=$USERNAME"
```

### Modifying Existing Configuration

1. **Edit file in `/configs/`** (NOT in the script)
2. **Test changes** before commit
3. **Document** changes in this README if significant

### Supported Variables

| Variable | Description | Used in |
|----------|-------------|---------|
| `{{USERNAME}}` | Created username | sudo, doas, network |
| `{{HOSTNAME}}` | Host name | network/hosts |

To add more variables, modify `deploy_config()` in `config-functions.sh`.

## 🎨 Complete Usage Examples

### Example 1: Complete Sudo Deploy

```bash
#!/bin/bash
source "$LIB_DIR/shared-functions.sh"
source "$LIB_DIR/config-functions.sh"

USERNAME="john"
PRIV_TOOL="sudo"

# Backup existing configuration
backup_config "/etc/sudoers.d/10-alie-$USERNAME"

# Deploy user configuration
deploy_config "sudo/sudoers-user-primary.template" \
    "/etc/sudoers.d/10-alie-$USERNAME" \
    "USERNAME=$USERNAME"

# Set critical permissions
chmod 440 "/etc/sudoers.d/10-alie-$USERNAME"

# Deploy global configuration
deploy_config_direct "sudo/sudoers-defaults-primary" \
    "/etc/sudoers.d/00-alie-defaults" "440"

# Validate before continuing
if validate_sudoers "/etc/sudoers.d/10-alie-$USERNAME"; then
    print_success "Sudo configured successfully"
else
    print_error "Invalid sudoers configuration!"
    exit 1
fi
```

### Example 2: Firewall Deploy with Selection

```bash
#!/bin/bash
source "$LIB_DIR/shared-functions.sh"
source "$LIB_DIR/config-functions.sh"

print_info "Select firewall type:"
echo "1. UFW (Simple)"
echo "2. Firewalld (Advanced)"
read -p "Choice [1-2]: " fw_choice

print_info "Select profile:"
echo "1. Basic (Server)"
echo "2. Desktop (Development)"
read -p "Choice [1-2]: " profile_choice

# Determine script to execute
if [ "$fw_choice" = "1" ]; then
    if [ "$profile_choice" = "1" ]; then
        script="firewall/ufw-basic.sh"
    else
        script="firewall/ufw-desktop.sh"
    fi
else
    if [ "$profile_choice" = "1" ]; then
        script="firewall/firewalld-basic.sh"
    else
        script="firewall/firewalld-desktop.sh"
    fi
fi

# Execute configuration
execute_config_script "$script"
```

### Example 3: Complete Audio Deploy

```bash
#!/bin/bash
source "$LIB_DIR/shared-functions.sh"
source "$LIB_DIR/config-functions.sh"

print_step "Configuring Audio System"

# Global ALSA
backup_config "/etc/asound.conf"
deploy_config_direct "audio/asound.conf" "/etc/asound.conf" "644"

# PipeWire
mkdir -p /etc/pipewire
backup_config "/etc/pipewire/pipewire.conf"
deploy_config_direct "audio/pipewire.conf" "/etc/pipewire/pipewire.conf" "644"

# WirePlumber
mkdir -p /etc/wireplumber/main.conf.d
deploy_config_direct "audio/wireplumber.conf" \
    "/etc/wireplumber/main.conf.d/50-alie.conf" "644"

print_success "Audio configuration deployed"
```

## ⚠️ Security Considerations

### Critical Permissions

| File | Permissions | Owner | Reason |
|------|-------------|-------|--------|
| `/etc/sudoers.d/*` | `440` | `root:root` | Sudo security |
| `/etc/doas.conf` | `400` | `root:root` | Required by doas |
| Firewall configs | `644` | `root:root` | Public read OK |
| Audio configs | `644` | `root:root` | Public read OK |

### Mandatory Validation

**NEVER** deploy sudo/doas without validation:

```bash
# BAD ❌
deploy_config "sudo/sudoers-user.template" "/etc/sudoers.d/user"

# GOOD ✅
deploy_config "sudo/sudoers-user.template" "/etc/sudoers.d/user"
chmod 440 "/etc/sudoers.d/user"
validate_sudoers "/etc/sudoers.d/user" || exit 1
```

## 🔍 Testing

### Individual Test

```bash
# Test validation
bash lib/config-functions.sh
source lib/shared-functions.sh
source lib/config-functions.sh
validate_sudoers configs/sudo/sudoers-defaults-primary
```

### Deploy Test (in VM/Container)

```bash
# Test in isolated environment
SCRIPT_DIR="$(pwd)/install"
LIB_DIR="$(pwd)/lib"

source "$LIB_DIR/shared-functions.sh"
source "$LIB_DIR/config-functions.sh"

# Test deploy
deploy_config_direct "audio/asound.conf" "/tmp/test-asound.conf"
cat /tmp/test-asound.conf
```

## 📊 Migration from Old Scripts

### Before (Inline Configuration)

```bash
# In install/201-user-setup.sh
cat > /etc/doas.conf << EOF
permit persist :wheel
permit persist $USERNAME
EOF
chmod 400 /etc/doas.conf
```

### After (Modular Configuration)

```bash
# In install/201-user-setup.sh
source "$LIB_DIR/config-functions.sh"

deploy_config "sudo/doas.conf.template" \
    "/etc/doas.conf" \
    "USERNAME=$USERNAME"
chmod 400 /etc/doas.conf
validate_doas "/etc/doas.conf"
```

## 🚀 Roadmap

### Implemented ✅
- [x] Template system with variables
- [x] Helper functions for deployment
- [x] Sudo/doas validation
- [x] Automatic backup
- [x] Firewall, audio, network, sudo configs

### Pending 📋
- [ ] Migrate all scripts to use external config
- [ ] Git configs
- [ ] Vim/Neovim configs
- [ ] "Profiles" system (server, desktop, minimal)
- [ ] Interactive wizard for config selection

### Shell Configurations (`configs/shell/`)

Optimized configurations for different shells available in Arch Linux.

#### Available Files

| File | Shell | Destination | Description |
|------|-------|-------------|-------------|
| `bashrc` | Bash | `~/.bashrc` | Enhanced Bash config with aliases and colors |
| `zshrc` | Zsh | `~/.zshrc` | Zsh with autocompletion, enhanced history |
| `config.fish` | Fish | `~/.config/fish/config.fish` | Fish with modern syntax |
| `tcshrc` | Tcsh | `~/.tcshrc` | TENEX C Shell with colored prompt |
| `kshrc` | Korn Shell | `~/.kshrc` | Korn Shell with useful functions |

#### Common Features

All configurations include:
- ✅ Colored and customized prompt
- ✅ Useful aliases (ls, ll, la, grep with colors)
- ✅ Configured history (1000+ commands)
- ✅ Colored man pages
- ✅ Safety aliases (rm -i, cp -i, mv -i)
- ✅ Default editor configuration

#### Usage in Scripts

Configurations are automatically deployed in `install/201-user-setup.sh`:

```bash
# The configure_shell_environment() function handles deployment
configure_shell_environment "$username" "$shell_name"

# Supports: bash, zsh, fish, tcsh, ksh
# Dash requires no configuration (minimal POSIX shell)
```

#### Notes by Shell

- **Bash**: Optional enhanced config, system already has basic one
- **Zsh**: Requires configuration to leverage its features
- **Fish**: Configuration in separate directory (~/.config/fish/)
- **Tcsh**: C-style syntax, variables with `setenv`
- **Ksh**: Bash-compatible, additional functions (extract, up)
- **Dash**: No config required, only system environment variables

### Xorg GPU Configurations (`configs/xorg/`)

Optimized X11 configurations for different GPUs, automatically deployed based on hardware detection.

#### Available Files

| File | GPU | Destination | Driver | Features |
|------|-----|-------------|--------|----------|
| `20-intel.conf` | Intel | `/etc/X11/xorg.conf.d/20-intel.conf` | `intel` | TearFree, SNA acceleration, DRI3 |
| `20-amdgpu.conf` | AMD | `/etc/X11/xorg.conf.d/20-amdgpu.conf` | `amdgpu` | TearFree, FreeSync, Glamor |
| `20-nvidia.conf` | NVIDIA | `/etc/X11/xorg.conf.d/20-nvidia.conf` | `nvidia` | ForceCompositionPipeline, TripleBuffer |

#### Features by GPU

**Intel (`xf86-video-intel`)**:
- ✅ TearFree enabled (no tearing)
- ✅ SNA acceleration (Sandy Bridge and newer)
- ✅ DRI3 for better performance
- ✅ Triple buffering
- ✅ Integrated backlight control

**AMD (`amdgpu`)**:
- ✅ TearFree enabled
- ✅ Variable Refresh Rate (FreeSync/Adaptive Sync)
- ✅ Glamor acceleration
- ✅ Page flipping enabled
- ✅ Optimized color tiling

**NVIDIA (`nvidia` proprietary)**:
- ✅ ForceCompositionPipeline (anti-tearing)
- ✅ ForceFullCompositionPipeline
- ✅ Triple buffering
- ✅ NoLogo (no NVIDIA logo on startup)
- 🔒 Coolbits commented (overclock disabled for security)

#### Automatic Deployment

Configurations are automatically deployed in `install/213-display-server.sh`:

```bash
# The configure_graphics_drivers() function detects hardware
configure_graphics_drivers

# Internally calls deploy_xorg_config() with GPU type
deploy_xorg_config "intel"   # or "amd" or "nvidia"
```

#### Important Notes

- **Nouveau**: No custom configuration required (uses Xorg defaults)
- **Multiple GPUs**: Only installs config for detected primary GPU
- **Modesetting**: Intel can use `modesetting` driver instead of `intel` (better in some cases)
- **NVIDIA Optimus**: Requires additional configuration (bumblebee/optimus-manager, not included)

#### Customization

To modify configurations:

```bash
# Edit config before deployment
nano configs/xorg/20-intel.conf

# Or after installation
sudo nano /etc/X11/xorg.conf.d/20-intel.conf

# Restart X to apply
sudo systemctl restart lightdm  # or gdm, sddm
```

## 📚 References

- [ArchWiki - sudo](https://wiki.archlinux.org/title/Sudo)
- [ArchWiki - doas](https://wiki.archlinux.org/title/Doas)
- [ArchWiki - PipeWire](https://wiki.archlinux.org/title/PipeWire)
- [ArchWiki - Firewalld](https://wiki.archlinux.org/title/Firewalld)
- [ArchWiki - UFW](https://wiki.archlinux.org/title/Uncomplicated_Firewall)

---

**Last update**: 2025-01-14  
**Version**: 1.0
