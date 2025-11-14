# ALIE Installation Flow

## Overview

ALIE installation is organized in numbered scripts that guide you through the complete Arch Linux setup process. Each script handles a specific phase of installation.

## Script Numbering System

Scripts are numbered in logical execution order:

- **001-0XX**: Pre-installation (partitioning, disk setup)
- **002-0XX**: Base system installation preparation
- **003-0XX**: Base system installation and configuration
- **101-1XX**: Post-installation system configuration
- **201-2XX**: User setup and environment
- **211-2XX**: Package installation (AUR helpers, tools)
- **221-2XX**: Desktop environment installation

## Installation Phases

### Phase 1: Disk Preparation (001)

**Script**: `001-base-install.sh`

**Purpose**: Partition disks, format filesystems, and mount partitions

**Features**:
- Interactive disk selection
- Automatic or manual partitioning
- UEFI/BIOS detection
- Network connectivity setup
- Filesystem formatting (ext4, btrfs, xfs)
- Swap configuration

**Scenarios**:
1. **Automatic partitioning** - Let ALIE handle everything (DESTRUCTIVE)
2. **Manual partitioning** - Use cfdisk/fdisk/parted yourself
3. **Existing partitions** - Skip to 003 if you already partitioned manually

**Outputs**:
- Mounted root at `/mnt`
- Active swap partition
- Config saved to `/tmp/.alie-install-config`
- Progress marker: `01-partitions-ready`

---

### Phase 2: Shell & Editor Selection (002) - OPTIONAL

**Script**: `002-shell-editor-select.sh`

**Purpose**: Pre-select alternative shells and configure text editors

**Features**:
- Shell selection (zsh, fish, dash, tcsh, ksh)
- Editor configuration (nano with syntax highlighting, vim enhanced)
- Additional editor installation (neovim, emacs-nox, micro, helix)

**When to skip**:
- You only want default bash + basic nano/vim
- You prefer to install shells/editors later

**When to use**:
- You want zsh or fish configured from the start
- You want enhanced nano/vim configs deployed automatically
- You're comfortable choosing tools before installation

**Outputs**:
- Config saved to `/tmp/.alie-shell-editor-config`
- Package list for 003 to include in pacstrap

**Note**: This is completely optional. You can skip this and run 003 directly.

---

### Phase 3: Base System Installation (003)

**Script**: `003-system-install.sh`

**Purpose**: Install base Arch Linux system with pacstrap

**Features**:
- Mirror optimization with reflector
- Base system installation (linux, base, firmware)
- Shell/editor package installation (if 002 was run)
- Editor configuration deployment (nano/vim)
- Microcode installation (Intel/AMD)
- fstab generation
- Configuration persistence

**Auto-detection**:
If you skipped 001 (manual partitioning), this script will:
- Detect boot mode (UEFI/BIOS)
- Find mounted partitions
- Identify filesystems
- Detect CPU vendor for microcode
- Locate active swap

**Requirements**:
- Root partition mounted at `/mnt`
- Active swap (recommended)
- EFI partition at `/mnt/boot` (UEFI only)
- Internet connection

**Outputs**:
- Base system installed in `/mnt`
- Configs deployed to `/mnt/etc/`
- Progress marker: `02-base-installed`

---

### Phase 4: System Configuration (101)

**Script**: `101-configure-system.sh`

**Purpose**: Configure locale, timezone, hostname, and bootloader

**Run from**: Inside `arch-chroot /mnt`

**Features**:
- Timezone configuration
- Locale generation
- Hostname setup
- Hosts file configuration
- Network configuration (NetworkManager)
- Bootloader installation (GRUB)

---

### Phase 5: User Setup (201)

**Script**: `201-user-setup.sh`

**Purpose**: Create users and configure shell environments

**Features**:
- User account creation
- Sudo/doas configuration (from configs/sudo/)
- Shell selection (if multiple installed)
- Shell configuration deployment (bashrc, zshrc, config.fish)
- Home directory setup

**Auto-detection**:
- Detects installed shells
- Prompts for selection if multiple available
- Deploys appropriate shell config files

---

### Phase 6: Additional Tools (211+)

**Scripts**:
- `211-install-aur-helper.sh` - Install yay/paru
- `212-cli-tools.sh` - Install CLI utilities
- `213-display-server.sh` - Install Xorg/Wayland
- `221-desktop-install.sh` - Install desktop environment

---

## Installation Workflows

### Workflow 1: Guided Installation (Recommended)

Complete automated setup with ALIE handling partitioning:

```bash
# From Arch installation media
bash install/001-base-install.sh    # Partition disks
bash install/002-shell-editor-select.sh  # Select shells/editors (optional)
bash install/003-system-install.sh  # Install base system

# Copy scripts to new system
cp -r /path/to/alie /mnt/root/alie-scripts

# Enter new system
arch-chroot /mnt

# Continue installation
cd /root/alie-scripts
bash install/101-configure-system.sh
bash install/201-user-setup.sh
# ... and so on
```

### Workflow 2: Manual Partitioning + Auto Install

You handle partitioning, ALIE handles the rest:

```bash
# Manually partition with cfdisk/fdisk/parted
cfdisk /dev/sda

# Mount partitions yourself
mount /dev/sda3 /mnt
mount /dev/sda1 /mnt/boot
swapon /dev/sda2

# Start from phase 3 (ALIE auto-detects everything)
bash install/003-system-install.sh  # Detects mounts and config

# Continue as normal...
```

### Workflow 3: Minimal Installation

Skip optional steps for fastest install:

```bash
bash install/001-base-install.sh    # Partition
# Skip 002 (no custom shells/editors)
bash install/003-system-install.sh  # Install base

# ... continue with 101, 201, etc.
```

### Workflow 4: Custom Shell/Editor Only

If you only want shell/editor customization:

```bash
bash install/001-base-install.sh    # Partition
bash install/002-shell-editor-select.sh  # Configure shells/editors
bash install/003-system-install.sh  # Install with custom config
```

---

## Configuration Persistence

### From 001 to 003

`001-base-install.sh` saves:
- `/tmp/.alie-install-config` - System detection (boot mode, CPU, partitions)
- `/mnt/root/.alie-install-config` - Copy for chroot environment

`003-system-install.sh` loads this config or auto-detects if missing.

### From 002 to 003

`002-shell-editor-select.sh` saves:
- `/tmp/.alie-shell-editor-config` - Shell/editor selections

`003-system-install.sh` reads this to:
- Add packages to pacstrap command
- Deploy editor configs
- Set configuration flags

### Config Files Used

Scripts deploy configs from `configs/` directory:
- `configs/editor/nanorc` - Nano syntax highlighting
- `configs/editor/vimrc` - Vim enhanced settings
- `configs/shell/bashrc` - Bash configuration
- `configs/shell/zshrc` - Zsh configuration
- `configs/shell/config.fish` - Fish shell configuration
- `configs/sudo/*` - Sudo/doas templates
- `configs/network/*` - Network configurations
- `configs/audio/*` - Audio system configs
- `configs/firewall/*` - Firewall configurations

---

## Error Recovery

### 001 Failed

- Unmount partitions: `umount -R /mnt`
- Deactivate swap: `swapoff -a`
- Re-run script or partition manually

### 002 Skipped or Failed

- No problem! Just run 003 directly
- Default bash + basic editors will be installed

### 003 Failed During pacstrap

- Check internet connection
- Verify mirrors: `reflector --latest 5 --protocol https --sort rate`
- Re-run 003 (it will detect existing mounts)

### Missing Config Detection

If config files are missing, scripts will:
1. Auto-detect system information
2. Use fallback inline configurations
3. Prompt for manual verification

---

## Advanced Usage

### Skipping Phases

You can skip any optional phase:
- Skip 002 for default shell/editor
- Skip partitioning if already done
- Skip desktop installation for server setup

### Running Individual Scripts

Each script is independent (with dependencies):

```bash
# Just configure shells (002 standalone)
bash install/002-shell-editor-select.sh

# Just install base system (003 standalone with auto-detect)
mount /dev/sda3 /mnt
swapon /dev/sda2
bash install/003-system-install.sh
```

### Re-running Scripts

Most scripts can be re-run safely:
- 001: Will ask for confirmation before destroying data
- 002: Will overwrite previous selections
- 003: Will detect existing installation
- 101+: Will skip completed steps or ask for confirmation

---

## Summary Table

| Script | Phase | Required | Purpose | Auto-detects | 
|--------|-------|----------|---------|--------------|
| 001 | Partitioning | Yes* | Prepare disks | - |
| 002 | Shell/Editor | No | Customize tools | - |
| 003 | Base Install | Yes | Install system | Partitions, boot mode, CPU |
| 101 | System Config | Yes | Configure OS | Timezone, locale |
| 201 | User Setup | Yes | Create users | Installed shells |
| 211+ | Extra Tools | No | Add packages | - |

\* Required unless you partition manually

---

## Tips

1. **Read prompts carefully** - Scripts explain what they'll do before acting
2. **Verify auto-detection** - Check displayed config before proceeding
3. **Keep backups** - 001 is DESTRUCTIVE in automatic mode
4. **Internet required** - 003 needs network for pacstrap
5. **Take notes** - Save passwords and choices during installation
6. **Sequential execution** - Run scripts in order unless you know what you're doing

---

## Support

For issues or questions:
- Check script output - most errors are self-explanatory
- Review Arch Wiki: https://wiki.archlinux.org/title/Installation_guide
- See logs: Most operations are verbose
- Backup configs: Scripts create backups before modifying files
