# ALIE Installation Scripts

Automated installation scripts for Arch Linux with customizable desktop environments and window managers.

## ⚠️ WARNING - EXPERIMENTAL STATUS

**These scripts are experimental and provided AS-IS without warranties.**

- **NOT** a replacement for the official Arch Linux installer
- **NOT** exhaustively tested in all possible scenarios
- **May contain errors** resulting in an unbootable system or data loss
- **Strongly recommended** to follow the main README manual guide to understand each step
- Use at your own risk, especially on production systems or important data
- **Make backups** before using these scripts

**For new users:** Following the manual step-by-step guide is recommended to understand the installation process.

**For experienced users:** These scripts can save time on reinstallations, but review the code before running.

## Quick Start

### Automatic Mode (Recommended)

The installer automatically detects your environment and continues from where you left off:

```bash
bash alie.sh
```

Detects if you are in:

- **Live CD**: Starts base installation
- **Chroot**: Configures the system
- **Installed system without GUI**: Offers desktop/WM selection
- **System with desktop**: Installs additional tools

Progress is saved automatically, so you can reboot between steps without losing track.

### Manual Mode

Manually choose which script to run:

```bash
bash alie.sh --manual
```

Useful for:
- Re-running specific steps
- Debugging
- Custom installations

## Directory Structure

```
├── alie.sh                    # Master installer (entry point)
├── install/                   # Installation scripts
│   ├── 001-base-install.sh    # Disk partitioning & formatting
│   ├── 002-shell-editor-select.sh # Shell/editor selection (bash/zsh/fish/nushell + nano/vim) (optional)
│   ├── 003-system-install.sh  # Base system install (pacstrap)
│   ├── 101-configure-system.sh # System configuration (grub, locale)
│   ├── 201-user-setup.sh      # User creation & privileges
│   ├── 211-install-aur-helper.sh # AUR helper (yay/paru)
│   ├── 212-cli-tools.sh       # Interactive CLI tools selection
│   ├── 213-display-server.sh  # Display server (X11/Wayland)
│   ├── 220-desktop-select.sh  # Choose DE/X11 WM/Wayland WM or skip
│   ├── 221-desktop-environment.sh # Desktop Environments
│   ├── 222-window-manager.sh  # X11 Window Managers
│   ├── 223-wayland-wm.sh      # Wayland Window Managers
│   └── 231-desktop-tools.sh   # Additional applications
├── lib/                       # Shared libraries
│   ├── shared-functions.sh    # Common functions
│   └── config-functions.sh    # Configuration deployment functions
├── configs/                   # Configuration files and templates
│   ├── README.md              # Configuration files documentation
│   ├── audio/                 # Audio configuration (ALSA/PipeWire)
│   ├── display-managers/      # Display manager configs (LightDM/SDDM)
│   ├── editor/                # Text editor configurations (nano/vim)
│   ├── firewall/              # Firewall configurations (UFW/Firewalld)
│   ├── network/               # Network configurations (NetworkManager/systemd-resolved)
│   ├── shell/                 # Shell configurations (bash/zsh/fish/nushell/ksh/tcsh)
│   ├── sudo/                  # Sudo/Doas privilege configurations
│   └── xorg/                  # Xorg graphics driver configurations
├── README.en.md               # English documentation
├── README.es.md               # Spanish documentation
├── LICENSE                    # AGPLv3 License
└── .gitignore
```

## Available Scripts

| # | Script | Run as | When |
|---|--------|--------|------|
| 0 | `alie.sh` | root/user | Anytime (auto-detects environment) |
| 1 | `001-base-install.sh` | root | From installation media |
| 2 | `002-shell-editor-select.sh` | root | Optional shell/editor selection (bash/zsh/fish/nushell + nano/vim) |
| 3 | `003-system-install.sh` | root | From installation media |
| 4 | `101-configure-system.sh` | root | Inside arch-chroot |
| 5 | `201-user-setup.sh` | root | User creation & privilege configuration |
| 6 | `211-install-aur-helper.sh` | user | AUR helper installation (yay/paru) |
| 7 | `212-cli-tools.sh` | user | Interactive CLI tools selection |
| 8 | `213-display-server.sh` | root | X11/Wayland selection |
| 9 | `220-desktop-select.sh` | root | Choose DE/X11 WM/Wayland WM or skip |
| 10 | `221-desktop-environment.sh` | root | Desktop Environments |
| 11 | `222-window-manager.sh` | root | X11 Window Managers |
| 12 | `223-wayland-wm.sh` | root | Wayland Window Managers |
| 13 | `231-desktop-tools.sh` | root | Additional applications |

## Complete Process

### With Automatic Installer (Recommended)

```bash
# At each stage, simply run:
bash alie.sh
```

The script automatically:
- ✅ Detects current environment
- ✅ Checks previous progress
- ✅ Runs the appropriate next step
- ✅ Saves progress to continue after reboot

### With Individual Scripts (Manual)

```bash
# 1. From installation media
bash install/001-base-install.sh

# 2. In chroot
arch-chroot /mnt
bash install/101-configure-system.sh
exit

# 3. Unmount and reboot
umount -R /mnt
sync
reboot

# 4. After reboot (as root)
bash install/201-user-setup.sh
reboot

# 5. After reboot (as user)
bash install/211-install-aur-helper.sh
bash install/212-cli-tools.sh
reboot
```

## Features

### Progress System
- The installer automatically saves your progress in `.alie-progress`
- You can reboot at any time and continue from where you left off
- Use `bash alie.sh --manual` to clear progress if you need to start over

### Shared Functions
- All common functions are in `lib/shared-functions.sh`
- Consistent UI with colors and clear messages
- Robust error handling
- Automatic retries for network operations
- Security validations (root/user permissions)

### Intelligent Detection
- Auto-detects CPU (Intel/AMD) for correct microcode
- Detects boot mode (UEFI/BIOS)
- Verifies internet connection before installing
- Validates environment (Live USB, chroot, installed system)
- **Multiple shell support** - Choose from Bash, Zsh, Fish, or Nushell with full configuration
- **Robust partitioning** - Enhanced disk cleanup with multiple unmount attempts and process management

### Shell Options
ALIE supports multiple shell environments with full configuration:

#### Available Shells
- **Bash** - Default GNU Bourne Again Shell
- **Zsh** - Extended Bourne Shell with powerful features
- **Fish** - Friendly Interactive Shell with autosuggestions
- **Nushell** - Modern shell written in Rust with structured data support

#### Shell Configuration Features
- **Automatic Detection**: Scripts detect and configure your chosen shell
- **Comprehensive Setup**: Includes aliases, PATH configuration, and editor settings
- **Fallback Support**: Inline configuration if config files are unavailable
- **Nushell Special Features**: Structured data handling, custom prompt, Starship integration

## Customization

Edit scripts before running to:

- Change reflector country
- Modify package list
- Adjust specific configurations

## Important Notes

- **Always review scripts before running**
- Scripts stop on errors (`set -e`)
- Some require user input
- Designed to be idempotent when possible

## Troubleshooting

If a script fails:

1. Read the error message
2. Fix the problem manually
3. Continue with next step or re-run the script

### Disk Partitioning Issues

If the installer fails with "initialization canceled or failed" after selecting a disk:

**1. Check Disk Basics**
```bash
# Verify disk exists and is accessible
lsblk -d /dev/sda  # Replace sda with your disk

# Check if disk is in use
mount | grep /dev/sda
swapon --show | grep /dev/sda
```

**2. Test parted Commands Manually**
```bash
# Test basic parted functionality
sudo parted -s /dev/sda print

# Test partition table creation (dry run)
sudo parted -s /dev/sda mklabel gpt --dry-run
```

**3. Enhanced Partition Cleanup (v2.0+)**
ALIE now includes robust partition unmounting with multiple strategies:
- **Normal unmount** - Standard umount command
- **Lazy unmount** - umount -l for busy partitions
- **Process detection** - Automatically finds and terminates processes using partitions
- **Force unmount** - umount -f as last resort
- **Multiple attempts** - Up to 5 attempts with 3-second delays between retries

If partitions are temporarily busy, the installer will automatically handle cleanup.

**4. Common Issues**

- **Disk not found**: Make sure you're using the correct disk name (sda, nvme0n1, etc.)
- **Permission denied**: Run installer as root
- **Disk in use**: Unmount any mounted partitions first
- **Virtual machine**: Some VMs need special disk configurations
- **USB drive**: Some USB drives don't support all partitioning schemes

**5. Alternative: Manual Partitioning**
If automatic partitioning fails, choose option 2 in the installer for manual partitioning with cfdisk/fdisk.

## Contributions

If you find errors or improvements, open an issue or pull request on the repository.

