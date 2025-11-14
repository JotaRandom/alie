# ALIE Scripts Reorganization Summary

## Date
November 14, 2025

## Changes Made

### Script Renaming
The following scripts were renamed to create a more logical installation flow:

| Old Name | New Name | Purpose |
|----------|----------|---------|
| `001b-shell-editor-select.sh` | `002-shell-editor-select.sh` | Shell and editor selection |
| `002-system-install.sh` | `003-system-install.sh` | Base system installation (pacstrap) |

### Rationale

The previous numbering was confusing:
- `001-base-install.sh` did partitioning
- `001b-shell-editor-select.sh` was optional shell/editor selection
- `002-system-install.sh` did pacstrap

**New logical flow:**
1. `001` - Partitioning ONLY (no pacstrap)
2. `002` - Shell/editor selection (OPTIONAL, before pacstrap)
3. `003` - pacstrap and system installation

This allows users to:
- Do manual partitioning and skip `001`
- Skip `002` if they want default shells/editors
- Start at `003` if partitions are already ready

### Files Modified

#### Scripts Updated
- ✅ `001-base-install.sh` - Updated next step references
- ✅ `002-shell-editor-select.sh` - Updated comments and config generation
- ✅ `003-system-install.sh` - Updated references to load config from 002
- ✅ `alie.sh` - Updated manual menu and all script references
- ✅ `README.md` - Updated project structure and installation steps table

#### Scripts Verified (No Changes Needed)
- ✅ `101-configure-system.sh` - No references to renamed scripts
- ✅ `201-user-setup.sh` - No references to renamed scripts
- ✅ `211-install-aur-helper.sh` - No references to renamed scripts
- ✅ `212-cli-tools.sh` - No references to renamed scripts
- ✅ `213-display-server.sh` - No references to renamed scripts
- ✅ `221-desktop-install.sh` - No references to renamed scripts

### Non-ASCII Character Cleanup

All emoji and special Unicode characters were replaced with ASCII equivalents:

| Character | Replacement | Location |
|-----------|-------------|----------|
| ⚠️ | `***` | Warning headers |
| • | `-` | Bullet points |
| ✅ | `[OK]` | Success indicators |
| ✓ | `[OK]` | Checkmarks |
| ✗ | `[X]` | Error markers |
| 🚀 | `***` | Headers |
| 📦 | `[PKG]` | Package references |
| 🔄 | `[LOOP]` | Process indicators |

**Files cleaned:**
- ✅ `001-base-install.sh`
- ✅ `002-shell-editor-select.sh`
- ✅ `003-system-install.sh`
- ✅ `201-user-setup.sh`
- ✅ `211-install-aur-helper.sh`
- ✅ `212-cli-tools.sh`
- ✅ `213-display-server.sh`
- ✅ `221-desktop-install.sh`

### Updated Installation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    ALIE Installation Flow                    │
└─────────────────────────────────────────────────────────────┘

PHASE 1: Live USB (as root)
├── 001-base-install.sh
│   └── Disk partitioning and mounting
│       ├── Automatic partitioning (destructive)
│       ├── Manual partitioning (cfdisk/fdisk)
│       └── Use existing partitions
│
├── 002-shell-editor-select.sh (OPTIONAL)
│   └── Select shells and editors
│       ├── Shells: bash, zsh, fish, dash, tcsh, ksh
│       └── Editors: nano, vim, neovim, emacs, micro, helix
│
└── 003-system-install.sh
    └── Base system installation
        ├── Mirror optimization
        ├── pacstrap (base + linux + firmware)
        ├── Configure selected editors
        └── Generate fstab

═══════════════════════════════════════════════════════════════
                          REBOOT
═══════════════════════════════════════════════════════════════

PHASE 2: Chroot (as root)
└── 101-configure-system.sh
    └── System configuration
        ├── Timezone and locale
        ├── Hostname and network
        ├── Root password
        ├── Pacman configuration
        └── GRUB bootloader

═══════════════════════════════════════════════════════════════
                          REBOOT
═══════════════════════════════════════════════════════════════

PHASE 3: Installed System (as root)
└── 201-user-setup.sh
    └── User creation and configuration
        ├── Create desktop user
        ├── Configure sudo/doas
        ├── Configure user shell
        └── Install basic tools

═══════════════════════════════════════════════════════════════
                     LOGIN AS USER
═══════════════════════════════════════════════════════════════

PHASE 4: Post-Installation (as user)
├── 211-install-aur-helper.sh
│   └── Install yay or paru
│       ├── Optimize makepkg
│       └── Configure AUR helper
│
├── 212-cli-tools.sh
│   └── Interactive CLI tools selection
│       ├── Archive tools
│       ├── System utilities
│       ├── Development tools
│       └── Shell enhancements
│
└── (switch to root for remaining steps)

PHASE 5: Desktop Installation (as root)
├── 213-display-server.sh
│   └── Choose display server
│       ├── Xorg only
│       ├── Wayland only
│       └── Both (recommended)
│
└── 221-desktop-install.sh
    └── Install Cinnamon desktop
        ├── Desktop environment
        ├── LightDM display manager
        └── Desktop utilities
```

## Key Features

### Script 003 Intelligence
The `003-system-install.sh` script can now:
- ✅ Read configuration from `001-base-install.sh` if available
- ✅ Detect mounted partitions automatically if config is missing
- ✅ Work independently if user did manual partitioning
- ✅ Load shell/editor selections from `002-shell-editor-select.sh`
- ✅ Fallback to inline configurations if modular files are missing

### Flexible Installation Path
Users can now:
1. **Full auto**: Run `001` → `002` → `003` for complete automation
2. **Skip selection**: Run `001` → `003` (uses defaults)
3. **Manual partition**: Partition manually → `002` → `003`
4. **Expert mode**: Skip to any step with `alie.sh --manual`

## Testing Recommendations

Before using in production:

1. **Test full flow**: `001` → `002` → `003` → reboot → `101` → reboot → `201`
2. **Test skip 002**: `001` → `003` (verify defaults work)
3. **Test manual partition**: Manual fdisk → `003` (verify detection)
4. **Test manual mode**: `alie.sh --manual` (verify all options)

## Migration Notes

If you have existing scripts or documentation referencing the old names:
- Replace `001b-shell-editor-select.sh` with `002-shell-editor-select.sh`
- Replace `002-system-install.sh` with `003-system-install.sh`
- Update any automation that calls these scripts directly

## Version Compatibility

This reorganization is **NOT backward compatible** with:
- Scripts expecting `001b-shell-editor-select.sh`
- Scripts expecting `002-system-install.sh`
- Progress markers expecting step "02" (now "03")

All references have been updated in the ALIE codebase.

---

**Generated**: November 14, 2025  
**Author**: ALIE Development Team  
**Status**: ✅ Complete
