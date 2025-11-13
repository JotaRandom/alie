# LMAE Installer

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
git clone https://github.com/JotaRandom/LMAE.git
cd LMAE/src
```

**2. Run automatic installation**

```bash
bash lmae.sh
```

The installer automatically detects your environment and continues from the last completed step.

**3. Manual mode (advanced)**

```bash
bash lmae.sh --manual
```

Manually select which installation step to execute.

---

## 📂 Project Structure

```
src/
├── lmae.sh                     # Master installer (entry point)
├── install/                    # Installation scripts (semantic numbering)
│   ├── 001-base-install.sh     # Base system (Live USB, root only)
│   ├── 101-configure-system.sh # System config (chroot, root only)
│   ├── 201-desktop-install.sh  # Desktop env (installed system, root only)
│   ├── 211-install-yay.sh      # YAY AUR helper (user only)
│   └── 212-install-packages.sh # Linux Mint packages (user only)
├── lib/                        # Shared libraries
│   └── shared-functions.sh     # Common functions and utilities
├── docs/                       # Documentation
│   ├── CHANGELOG.md
│   ├── GUIA-RAPIDA.md
│   ├── NAMING-SCHEME.md
│   └── shared/
│       └── SHARED-FUNCTIONS.md
├── LICENSE                     # AGPLv3 License
└── .gitignore
```

### Semantic Numbering System

Scripts use a 3-digit naming scheme `XYZ`:

- **X** = Environment (0=Live CD, 1=Chroot, 2=Installed)
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
| 1 | `001-base-install.sh` | Live USB | root | Partition, format, install base |
| 2 | `101-configure-system.sh` | Chroot | root | Configure system (grub, locale, etc.) |
| 3 | `201-desktop-install.sh` | Installed | root | Install desktop & create user |
| 4 | `211-install-yay.sh` | Installed | user | Install YAY AUR helper |
| 5 | `212-install-packages.sh` | Installed | user | Install Mint packages |

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

- **Issues**: [GitHub Issues](https://github.com/JotaRandom/LMAE/issues)
- **Wiki**: [Project Wiki](https://github.com/JotaRandom/LMAE/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/JotaRandom/LMAE/discussions)

---

**Made with ❤️ for the Arch Linux and Linux Mint communities**

