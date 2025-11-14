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
src/
├── alie.sh                    # Master installer (entry point)
├── install/                   # Installation scripts
│   ├── 001-base-install.sh    # Disk partitioning & formatting
│   ├── 002-shell-editor-select.sh # Shell/editor selection (optional)
│   ├── 003-system-install.sh  # Base system install (pacstrap)
│   ├── 101-configure-system.sh # System configuration (grub, locale)
│   ├── 201-user-setup.sh      # User creation & privileges
│   ├── 211-install-aur-helper.sh # AUR helper (yay/paru)
│   ├── 212-cli-tools.sh       # Interactive CLI tools selection
│   ├── 213-display-server.sh  # Display server (X11/Wayland)
│   ├── 220-desktop-select.sh  # Choose DE/WM or skip
│   ├── 221-desktop-environment.sh # Desktop Environments
│   ├── 222-window-manager.sh  # Window Managers
│   └── 231-desktop-tools.sh   # Additional applications
├── lib/                       # Shared libraries
│   ├── shared-functions.sh    # Common functions
│   └── config-functions.sh    # Config deployment
├── configs/                   # Configuration files
│   └── display-managers/      # DM configurations
└── docs/                      # Documentation
    ├── CHANGELOG.md           # Change history
    ├── GUIA-RAPIDA.md         # Quick reference
    └── shared/
        └── SHARED-FUNCTIONS.md # Function documentation
```

## Available Scripts

| # | Script | Run as | When |
|---|--------|--------|------|
| 0 | `alie.sh` | root/user | Anytime (auto-detects environment) |
| 1 | `001-base-install.sh` | root | From installation media |
| 2 | `002-shell-editor-select.sh` | root | Optional shell/editor selection |
| 3 | `003-system-install.sh` | root | From installation media |
| 4 | `101-configure-system.sh` | root | Inside arch-chroot |
| 5 | `201-user-setup.sh` | root | After first reboot |
| 6 | `211-install-aur-helper.sh` | user | After reboot |
| 7 | `212-cli-tools.sh` | user | Interactive CLI tools |
| 8 | `213-display-server.sh` | root | X11/Wayland selection |
| 9 | `220-desktop-select.sh` | root | Choose DE/WM or skip |
| 10 | `221-desktop-environment.sh` | root | Desktop Environments |
| 11 | `222-window-manager.sh` | root | Window Managers |
| 12 | `231-desktop-tools.sh` | root | Additional applications |

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
bash install/201-desktop-install.sh
reboot

# 5. After reboot (as user)
bash install/211-install-yay.sh
bash install/212-install-packages.sh
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

## Contributions

If you find errors or improvements, open an issue or pull request on the repository.

