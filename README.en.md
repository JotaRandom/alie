# LMAE Installation Scripts

Automated installation scripts for Linux Mint Arch Edition.

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
bash lmae.sh
```

Detects if you are in:

- **Live CD**: Starts base installation
- **Chroot**: Configures the system
- **Installed system without desktop**: Installs desktop environment
- **System with desktop**: Installs YAY and Mint packages

Progress is saved automatically, so you can reboot between steps without losing track.

### Manual Mode

Manually choose which script to run:

```bash
bash lmae.sh --manual
```

Useful for:
- Re-running specific steps
- Debugging
- Custom installations

## Directory Structure

```
src/
├── lmae.sh                   # Master installer (entry point)
├── install/                  # Installation scripts
│   ├── 001-base-install.sh    # Base system installation
│   ├── 101-configure-system.sh # System configuration
│   ├── 201-desktop-install.sh # Desktop environment
│   ├── 211-install-yay.sh     # YAY AUR helper
│   └── 212-install-packages.sh # Linux Mint packages
├── lib/                      # Shared libraries
│   └── shared-functions.sh   # Common functions
└── docs/                     # Documentation
    ├── CHANGELOG.md          # Change history
    ├── GUIA-RAPIDA.md        # Quick reference
    ├── METRICAS.md           # Project metrics
    ├── RESUMEN-MODERNIZACION.md # Modernization summary
    └── shared/               # Shared library docs
        └── SHARED-FUNCTIONS.md # Function documentation
```

## Available Scripts

| # | Script | Run as | When |
|---|--------|--------|------|
| 0 | `lmae.sh` | root/user | Anytime (auto-detects environment) |
| 1 | `install/001-base-install.sh` | root | From installation media |
| 2 | `install/101-configure-system.sh` | root | Inside arch-chroot |
| 3 | `install/201-desktop-install.sh` | root | After first reboot |
| 4 | `install/211-install-yay.sh` | user | After reboot with desktop |
| 5 | `install/212-install-packages.sh` | user | After installing yay |

## Complete Process

### With Automatic Installer (Recommended)

```bash
# At each stage, simply run:
bash lmae.sh
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
- The installer automatically saves your progress in `.lmae-progress`
- You can reboot at any time and continue from where you left off
- Use `bash lmae.sh --manual` to clear progress if you need to start over

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
