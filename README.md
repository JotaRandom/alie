# ALIE Installer

**Automated installation scripts for Arch Linux with Linux Mint's Cinnamon desktop environment.**

> 🚀 Modular, robust, and production-ready installer for creating a Linux Mint-like experience on Arch Linux.

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

- [Quick Reference Guide](docs/GUIA-RAPIDA.md)
- [Naming Scheme](docs/NAMING-SCHEME.md)
- [Changelog](docs/CHANGELOG.md)
- [Shared Functions Documentation](docs/shared/SHARED-FUNCTIONS.md)

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
cd ALIE/src
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
│   ├── 002-shell-editor-select.sh # Shell/editor selection (OPTIONAL)
│   ├── 003-system-install.sh   # Base system install (pacstrap)
│   ├── 101-configure-system.sh # System configuration (chroot, root only)
│   ├── 201-user-setup.sh       # User creation + privilege config (root only)
│   ├── 211-install-aur-helper.sh # AUR helper (yay/paru) (user only)
│   ├── 212-cli-tools.sh        # Interactive CLI tools selection (user only)
│   ├── 213-display-server.sh   # Graphics server choice (Xorg/Wayland) (root only)
│   └── 221-desktop-install.sh  # Desktop environment (Cinnamon) (root only)
├── lib/                        # Shared functions and utilities
│   └── shared-functions.sh     # Common functions for all scripts
├── docs/                       # Documentation
│   ├── CHANGELOG.md            # Project history
│   ├── GUIA-RAPIDA.md          # Quick start guide (Spanish)
│   ├── SCRIPT-IMPROVEMENTS.md  # Technical improvements log
│   ├── WIKI-COMPLIANCE.md      # Arch Wiki compliance fixes
│   └── shared/
│       └── SHARED-FUNCTIONS.md # Function library documentation
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

See [NAMING-SCHEME.md](docs/NAMING-SCHEME.md) for details.

---

## 🔧 Features

- ✅ **Fully automated** - Auto-detects environment and resumes installation
- ✅ **Progress tracking** - Saves state, safe to interrupt and resume
- ✅ **Input validation** - Sanitizes all user inputs to prevent errors
- ✅ **Error handling** - `set -euo pipefail` in all scripts
- ✅ **Modular design** - Shared functions library for code reuse
- ✅ **Manual mode** - Run individual steps as needed
- ✅ **Comprehensive logging** - Clear progress indicators and error messages

---

## 🛠️ What Gets Installed

### Base System (001 + 101)
- Arch Linux base system
- GRUB bootloader (UEFI)
- Network configuration
- Timezone, locale, hostname setup

### Desktop Environment (201)
- Cinnamon desktop
- LightDM display manager
- Xorg and Mesa drivers
- Desktop user with sudo privileges

### AUR Helper (211)
- YAY for AUR package management

### Linux Mint Packages (212)
- Mint themes, icons, and fonts
- Nemo file manager with extensions
- LibreOffice, Firefox, Thunderbird
- Multimedia apps (Rhythmbox, Celluloid)
- System tools (Timeshift, CUPS printing)
- Optional: Laptop optimizations (TLP)

---

## 📋 Installation Steps

| Step | Script | Environment | User | Description |
|------|--------|-------------|------|-------------|
| 1 | `001-base-install.sh` | Live USB | root | Disk partitioning and formatting |
| 2 | `002-shell-editor-select.sh` | Live USB | root | Shell & editor selection (OPTIONAL) |
| 3 | `003-system-install.sh` | Live USB | root | Base system installation (pacstrap) |
| 4 | `101-configure-system.sh` | Chroot | root | System configuration (grub, locale) |
| 5 | `201-user-setup.sh` | Installed | root | User creation & privilege config |
| 6 | `211-install-aur-helper.sh` | Installed | user | AUR helper (yay/paru) installation |
| 7 | `212-cli-tools.sh` | Installed | user | **Interactive** CLI tools selection |
| 8 | `213-display-server.sh` | Installed | User | **Interactive** graphics server choice |
| 9 | `221-desktop-install.sh` | Installed | root & User | Desktop environment (Cinnamon) |

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

