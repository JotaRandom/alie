# ALIE Installer

**Automated installation scripts for Arch Linux with customizable desktop environments and window managers.**

> 🚀 Modular, robust, and production-ready installer for creating a fully-featured Arch Linux system with your choice of desktop environment or window manager.

---

## ⚠️ Important Notice

**These scripts modify your system significantly. Review the code before running.**

- Formats disks and partitions
- Installs packages and configures services
- Creates users and modifies system files

**Use at your own risk. Always backup important data.**

---

## 📚 Documentation

**Choose your language:**

- 🇪🇸 **[Guía en Español](README.es.md)** - Documentación completa
- 🇬🇧 **[English Guide](README.en.md)** - Complete documentation

**Additional resources:**

- [Configuration Files Documentation](configs/README.md)
- [Shared Functions Library](lib/shared-functions.sh)

---

## 🚀 Quick Start

### Prerequisites

- Arch Linux Live USB (boot in UEFI mode recommended)
- Internet connection
- At least 20GB free disk space

### Installation

**1. Download the installer**

```bash
# From Arch Live USB
git clone https://github.com/JotaRandom/ALIE.git
cd ALIE
```

**2. Run automatic installation**

```bash
bash alie.sh
```

The installer automatically detects your environment and continues from the last completed step.

**3. Manual mode (advanced)**

```bash
bash alie.sh --manual
```

Manually select which installation step to execute.

---

## 📂 Project Structure

```
├── alie.sh                     # Master installer (entry point)
├── install/                    # Installation scripts (sequential numbering)
│   ├── 001-base-install.sh     # Disk partitioning (Live USB, root only)
│   ├── 002-shell-editor-select.sh # Shell/editor selection (bash/zsh/fish/nushell + nano/vim) (OPTIONAL)
│   ├── 003-system-install.sh   # Base system install (pacstrap)
│   ├── 101-configure-system.sh # System configuration (chroot, root only)
│   ├── 201-user-setup.sh       # User creation + privilege config (root only)
│   ├── 211-install-aur-helper.sh # AUR helper (yay/paru) (user only)
│   ├── 212-cli-tools.sh        # Interactive CLI tools selection (user only)
│   ├── 213-display-server.sh   # Graphics server choice (Xorg/Wayland) (root only)
│   ├── 220-desktop-select.sh   # Choose DE/WM or skip (root only)
│   ├── 221-desktop-environment.sh # Desktop environments (Cinnamon/GNOME/KDE/XFCE4) (root only)
│   ├── 222-window-manager.sh   # X11 Window managers (i3/bspwm/Openbox/etc.) (root only)
│   ├── 223-wayland-wm.sh       # Wayland Window managers (Sway/Hyprland/etc.) (root only)
│   └── 231-desktop-tools.sh    # Additional applications and tools (root only)
├── lib/                        # Shared functions and utilities
│   ├── shared-functions.sh     # Common functions for all scripts
│   └── config-functions.sh     # Configuration deployment functions
├── configs/                    # Configuration files and templates
│   ├── README.md               # Configuration files documentation
│   ├── audio/                  # Audio configuration (ALSA/PipeWire)
│   ├── display-managers/       # Display manager configs (LightDM/SDDM)
│   ├── editor/                 # Text editor configurations (nano/vim)
│   ├── firewall/               # Firewall configurations (UFW/Firewalld)
│   ├── network/                # Network configurations (NetworkManager/systemd-resolved)
│   ├── shell/                  # Shell configurations (bash/zsh/fish/nushell/ksh/tcsh)
│   ├── sudo/                   # Sudo/Doas privilege configurations
│   └── xorg/                   # Xorg graphics driver configurations
├── README.en.md                # English documentation
├── README.es.md                # Spanish documentation
├── LICENSE                     # AGPLv3 License
└── .gitignore
```

### Semantic Numbering System

Scripts use a 3-digit naming scheme `XYZ-script-name.sh`:

- **X** = Environment (0=Live CD, 1=Chroot, 2=Installed)
- **Y** = Permissions (0=root only, 1=user only, 2=both)
- **Z** = Step number

#### Examples:
- `001-base-install.sh` = Live CD (0), root only (0), step 1
- `002-shell-editor-select.sh` = Live CD (0), root only (0), step 2
- `003-system-install.sh` = Live CD (0), root only (0), step 3
- `101-configure-system.sh` = Chroot (1), root only (0), step 1  
- `211-install-yay.sh` = Installed (2), user only (1), step 1
- **Y** = Permissions (0=root only, 1=user only, 2=both)
- **Z** = Step number

See the Semantic Numbering System section above for details.

---

## 🔧 Features

- ✅ **Fully automated** - Auto-detects environment and resumes installation
- ✅ **Progress tracking** - Saves state, safe to interrupt and resume
- ✅ **Input validation** - Sanitizes all user inputs to prevent errors
- ✅ **Error handling** - `set -euo pipefail` in all scripts
- ✅ **Modular design** - Shared functions library for code reuse
- ✅ **Manual mode** - Run individual steps as needed
- ✅ **Comprehensive logging** - Clear progress indicators and error messages
- ✅ **Multiple shell support** - Choose from Bash, Zsh, Fish, or Nushell with full configuration

---

## 🛠️ What Gets Installed

### Base System (001-003 + 101)
- Arch Linux base system
- GRUB bootloader (UEFI)
- Network configuration
- Timezone, locale, hostname setup

### User & Privileges (201)
- Desktop user with sudo privileges
- Optional shell customization (bash/zsh/fish/nushell)
- Comprehensive shell configuration with structured data support (Nushell)

### AUR Helper & CLI Tools (211-212)
- YAY or Paru for AUR package management
- Interactive CLI tools selection (development, system monitoring, etc.)

### Display Server (213)
- **Choice of**: X11 (Xorg), Wayland, or Both
- Mesa drivers and graphics support

### Desktop Selection (220)
**Desktop Environments** (221):
- Cinnamon (Normal/Mint Mode with LMAE compliance)
- GNOME (Normal/Full/Complete)
- KDE Plasma (Normal/Full/Complete)
- XFCE4

**Window Managers** (222/223):
- **X11 Window Managers** (222): i3/i3-gaps, bspwm, Openbox, Awesome, Qtile, Xmonad, dwm
- **Wayland Window Managers** (223): Sway, Hyprland, River, Niri, Labwc, Wlmaker (compositor)

**Or Skip** - Continue without GUI

### Optional Desktop Tools (231)
- Productivity: LibreOffice suite
- Multimedia: GIMP, Kdenlive, OBS
- Internet: Firefox, Thunderbird
- Development: VS Code, Git tools
- Gaming: Steam, Lutris, Wine
- Themes: Linux Mint themes (AUR)

---

## 🐚 Shell Options

ALIE supports multiple shell environments with full configuration:

### Available Shells
- **Bash** - Default GNU Bourne Again Shell
- **Zsh** - Extended Bourne Shell with powerful features
- **Fish** - Friendly Interactive Shell with autosuggestions
- **Nushell** - Modern shell written in Rust with structured data support

### Shell Configuration Features
- **Automatic Detection**: Scripts detect and configure your chosen shell
- **Comprehensive Setup**: Includes aliases, PATH configuration, and editor settings
- **Fallback Support**: Inline configuration if config files are unavailable
- **Nushell Special Features**: Structured data handling, custom prompt, Starship integration

---

## 📋 Installation Steps

| Step | Script | Environment | User | Description |
|------|--------|-------------|------|-------------|
| 1 | `001-base-install.sh` | Live USB | root | Disk partitioning and formatting |
| 2 | `002-shell-editor-select.sh` | Live USB | root | Shell & editor selection (bash/zsh/fish/nushell + nano/vim) (OPTIONAL) |
| 3 | `003-system-install.sh` | Live USB | root | Base system installation (pacstrap) |
| 4 | `101-configure-system.sh` | Chroot | root | System configuration (grub, locale) |
| 5 | `201-user-setup.sh` | Installed | root | User creation & privilege config |
| 6 | `211-install-aur-helper.sh` | Installed | user | AUR helper (yay/paru) installation |
| 7 | `212-cli-tools.sh` | Installed | user | **Interactive** CLI tools selection |
| 8 | `213-display-server.sh` | Installed | root | **Interactive** graphics server choice |
| 9 | `220-desktop-select.sh` | Installed | root | **Interactive** Choose DE/WM or skip |
| 10 | `221-desktop-environment.sh` | Installed | root | **Interactive** Desktop Environments (Cinnamon/GNOME/KDE/XFCE4) |
| 11 | `222-window-manager.sh` | Installed | root | **Interactive** X11 Window Managers (i3/bspwm/Openbox/Awesome/Qtile/Xmonad/dwm) |
| 12 | `223-wayland-wm.sh` | Installed | root | **Interactive** Wayland Window Managers (Sway/Hyprland/River/Niri/Labwc) + Wlmaker compositor |
| 13 | `231-desktop-tools.sh` | Installed | root | Desktop applications (LibreOffice, GIMP, etc.) |

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test thoroughly on a VM
4. Submit a pull request

---

## 📜 License

This project is licensed under the **GNU Affero General Public License v3.0** (AGPLv3).

See [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Arch Linux** - The base distribution
- **Linux Mint** - Desktop environment and package inspiration
- **Community** - Bug reports, suggestions, and contributions

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/JotaRandom/ALIE/issues)
- **Wiki**: [Project Wiki](https://github.com/JotaRandom/ALIE/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/JotaRandom/ALIE/discussions)

---

**Made with ❤️ for the Arch Linux and Linux Mint communities**

