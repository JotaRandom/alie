# ALIE - Individual Package Selection

## Overview

ALIE now supports **granular package selection** in addition to category-based installation. You can now choose specific individual packages instead of installing entire categories.

> **Note**: ALIE enables the `[multilib]` repository during base system installation (101-configure-system.sh),  
> so all `lib32-*` packages are available without additional configuration.

> **AUR Packages**: Packages marked with **[A]** are from the Arch User Repository and require an AUR helper (yay/paru) to be installed first.

## Available in Scripts

### ✅ 212-cli-tools.sh - CLI Tools Individual Selection

**Access**: Select option `C` (Custom Selection) from the main menu

**Features**:
- Browse all available CLI tools packages
- Select specific packages individually
- Filter packages by name or description
- Install only what you need

**Example Use Cases**:
```bash
# Install only unace extractor (without other archive tools)
./install/212-cli-tools.sh
→ Press 'C' for Custom Selection
→ Search for 'unace'
→ Select package #3
→ Press 'I' to install

# Install specific development tools
./install/212-cli-tools.sh
→ Press 'C' for Custom Selection
→ Select: linux-headers, cmake, git
→ Press 'I' to install
```

### ✅ 213-display-server.sh - Display Server Individual Selection

**Access**: Select option `6` (Individual Packages) from the main menu

**Features**:
- Choose specific Xorg components
- Select individual Wayland packages
- Pick graphics drivers separately
- Mix and match as needed

**Example Use Cases**:
```bash
# Install only xorg-xinit and nothing else
./install/213-display-server.sh
→ Press '6' for Individual Packages
→ Select package #3 (xorg-xinit)
→ Press 'I' to install

# Install minimal Wayland setup
./install/213-display-server.sh
→ Press '6' for Individual Packages
→ Select: wayland, wl-clipboard, xorg-xwayland
→ Press 'I' to install
```

## Package Categories

### 212-cli-tools.sh Available Packages

#### 📁 Archive Tools (10 packages)
- `7zip` - 7-Zip archiver
- `unrar` - RAR extraction
- `unace` - ACE extraction
- `lrzip` - Long range ZIP
- `zstd` - Modern compression
- `lz4` - Fast compression
- `p7zip` - 7-Zip for POSIX
- `cpio` - CPIO archiver
- `pax` - POSIX archiver
- `atool` - Archive tool wrapper

#### ⚡ System Utilities (14 packages)
- `htop` - Interactive process monitor
- `btop` - Modern system monitor
- `iotop` - I/O monitor
- `iftop` - Network monitor
- `ncdu` - Disk usage analyzer
- `tmux` - Terminal multiplexer
- `screen` - Terminal multiplexer alternative
- `exa` - Modern ls replacement
- `bat` - Better cat with syntax highlighting
- `fd` - Better find
- `ripgrep` - Fast grep
- `fzf` - Fuzzy finder
- `tldr` - Simplified man pages
- `trash-cli` - Safe rm alternative

#### 🔧 Development Tools (60+ packages)

**Core Build Tools**:
- `base-devel` - Essential build tools (gcc, make, binutils, etc)
- `git` - Version control system
- `cmake` - Cross-platform build system
- `ninja` - Fast build system
- `meson` - Modern build system
- `linux-headers` - Current kernel headers
- `linux-lts-headers` - LTS kernel headers
- `dkms` - Dynamic kernel module support

**Build Optimization**:
- `ccache` - Compiler cache (C/C++)
- `distcc` - Distributed compilation
- `sccache` - Shared compilation cache (Rust)

**GCC Compiler Variants**:
- `gcc-ada` - GCC Ada compiler (GNAT)
- `gcc-fortran` - GCC Fortran compiler
- `gcc-go` - GCC Go frontend (gccgo)
- `gcc-objc` - GCC Objective-C compiler
- `gcc-m2` - GCC Modula-2 compiler
- `gcc-d` - GCC D language compiler

**Multilib Support**:
- `multilib-devel` - 32-bit development libraries

> **Note**: The `[multilib]` repository is automatically enabled during ALIE base installation,  
> so 32-bit packages are available without additional setup.

**LLVM/Clang Toolchain**:
- `clang` - LLVM C/C++ compiler
- `llvm` - LLVM compiler toolkit
- `lld` - LLVM linker
- `lldb` - LLVM debugger
- `compiler-rt` - LLVM runtime libraries

**Rust Toolchain**:
- `rust` - Rust language and cargo
- `rust-analyzer` - Rust LSP server
- `cargo-bloat` - Find what takes space in binary
- `cargo-edit` - Cargo subcommands (add/rm/upgrade)
- `cargo-outdated` - Check outdated dependencies

**Go Toolchain**:
- `go` - Go programming language
- `gopls` - Go language server
- `delve` - Go debugger

**Python Toolchain**:
- `python` - Python 3 interpreter
- `python-pip` - Python package installer
- `python-virtualenv` - Virtual environments
- `python-pipenv` - Python workflow tool
- `python-poetry` - Dependency management
- `ipython` - Enhanced Python shell
- `pyenv` - Python version manager

**Lua**:
- `lua` - Lua scripting language
- `luajit` - LuaJIT compiler
- `luarocks` - Lua package manager

**Other Languages**:
- `nodejs` - JavaScript runtime
- `npm` - Node package manager
- `yarn` - Fast package manager
- `ruby` - Ruby programming language
- `perl` - Perl programming language
- `julia` - Julia programming language
- `zig` - Zig programming language

**Debugging Tools**:
- `gdb` - GNU Debugger
- `valgrind` - Memory debugging and profiling
- `strace` - System call tracer
- `ltrace` - Library call tracer
- `perf` - Performance profiler

**Documentation**:
- `man-db` - Manual page database
- `man-pages` - Linux manual pages

#### 🛡️ Security Tools (12 packages)
- `ufw` - Uncomplicated firewall
- `firewalld` - Dynamic firewall daemon
- `firejail` - Application sandboxing
- `apparmor` - Mandatory access control
- `openvpn` - VPN client
- `wireguard-tools` - Modern VPN
- `nmap` - Network scanner
- `wireshark-cli` - Packet analyzer
- `tcpdump` - Packet capture
- `gnupg` - GNU Privacy Guard
- `pass` - CLI password manager
- `keepassxc` - GUI password manager

#### 🎵 Media Tools (13 packages)
- `alsa-utils` - ALSA utilities
- `alsa-tools` - ALSA advanced tools
- `alsa-firmware` - ALSA firmware files
- `sof-firmware` - Sound Open Firmware
- `ffmpeg` - Video/audio converter
- `imagemagick` - Image manipulation
- `gifsicle` - GIF tools
- `sox` - Sound exchange
- `flac` - FLAC codec tools
- `opus-tools` - Opus codec tools
- `mediainfo` - Media file information
- `exiftool` - Metadata editor
- `youtube-dl` - Video downloader

#### 💻 Admin & Laptop Tools (13 packages)
- `android-udev` - Android device udev rules
- `tlp` - Advanced power management
- `powertop` - Power usage analyzer
- `acpi` - Battery information
- `lm_sensors` - Hardware monitoring
- `smartmontools` - Disk health monitoring
- `hdparm` - Disk parameter tuning
- `rsync` - File synchronization
- `rclone` - Cloud storage sync
- `ddrescue` - Data recovery
- `testdisk` - Partition recovery
- `stress` - System stress testing
- `cpupower` - CPU frequency scaling

#### 🎨 Shell Enhancements (7 packages)
- `zsh` - Z shell
- `fish` - Friendly interactive shell
- `oh-my-zsh-git` - Zsh framework
- `starship` - Cross-shell prompt
- `zoxide` - Smart cd command
- `autojump` - Directory jumper
- `thefuck` - Command corrector

### 213-display-server.sh Available Packages

#### 🖥️ Xorg Core (3 packages)
- `xorg-server` - Main X11 server
- `xorg-xauth` - X authentication
- `xorg-xinit` - X initialization (startx)

#### 🔧 Xorg Display Tools (4 packages)
- `xorg-xrandr` - Display configuration
- `xorg-xset` - X settings utility
- `xorg-xdpyinfo` - Display information
- `xorg-xsetroot` - Root window settings

#### 🪟 Xorg Window Tools (4 packages)
- `xorg-xprop` - Window properties
- `xorg-xwininfo` - Window information
- `xorg-xkill` - Force close windows
- `xorg-xev` - X event tester

#### ⌨️ Xorg Input Tools (2 packages)
- `xorg-xmodmap` - Keyboard mapping
- `xorg-xinput` - Input device configuration

#### 📋 Xorg Clipboard (2 packages)
- `xclip` - Clipboard command-line tool
- `xsel` - X selection tool

#### 🔤 Xorg Fonts (4 packages)
- `xorg-fonts-misc` - Miscellaneous X fonts
- `ttf-dejavu` - DejaVu TrueType fonts
- `ttf-liberation` - Liberation fonts
- `noto-fonts` - Google Noto fonts

#### 🛠️ Xorg Development (4 packages)
- `xorg-xrdb` - X resource database
- `xorg-xhost` - Access control utility
- `xorg-xlsclients` - List X clients
- `xorg-xvinfo` - Video extension information

#### 🌊 Wayland Core (3 packages)
- `wayland` - Wayland core library
- `wayland-protocols` - Wayland protocols
- `xorg-xwayland` - X11 compatibility layer

#### 🔧 Wayland Tools (3 packages)
- `wl-clipboard` - Wayland clipboard utilities
- `wlroots` - Wayland compositor library
- `xdg-desktop-portal-wlr` - Desktop portal for wlroots

#### 🎮 Graphics Drivers - Mesa (3 packages)
- `mesa` - Open-source graphics drivers
- `mesa-utils` - OpenGL utilities
- `vulkan-icd-loader` - Vulkan loader

#### 💠 Graphics Drivers - Intel (3 packages)
- `xf86-video-intel` - Intel Xorg driver
- `vulkan-intel` - Intel Vulkan driver
- `intel-media-driver` - Intel media acceleration

#### 🔴 Graphics Drivers - AMD (3 packages)
- `xf86-video-amdgpu` - AMD Xorg driver
- `vulkan-radeon` - AMD Vulkan driver
- `libva-mesa-driver` - VA-API for Mesa

#### 🟢 Graphics Drivers - NVIDIA (3 packages)
- `nvidia` - NVIDIA proprietary driver
- `nvidia-utils` - NVIDIA utilities
- `nvidia-settings` - NVIDIA configuration tool

## Interactive Features

### Search Functionality
Both scripts support package filtering:

```bash
# In individual selection mode:
search xorg        # Shows only xorg-related packages
search compression # Shows compression tools
search intel       # Shows Intel-specific packages
clear             # Removes filter
```

### Selection Commands

| Command | Action |
|---------|--------|
| `1-999` | Toggle package selection (by number) |
| `all` | Select all packages |
| `none` | Deselect all packages |
| `search <term>` | Filter packages by keyword |
| `clear` | Remove search filter |
| `I` | Install selected packages |
| `Q` | Cancel and return to menu |

## Benefits of Individual Selection

### 🎯 **Precision**
- Install exactly what you need
- No unwanted dependencies
- Minimal system footprint

### 💾 **Disk Space**
- Save disk space by avoiding bulk installs
- Perfect for minimal systems or VMs
- Control your installation size

### ⚡ **Performance**
- Faster installation (fewer packages)
- Reduced update overhead
- Cleaner package management

### 🔧 **Flexibility**
- Mix packages from different categories
- Create custom combinations
- Add packages incrementally

## Usage Workflow

### Recommended Approach

1. **Start with Categories** (if you need most packages in a category)
   ```bash
   ./install/212-cli-tools.sh
   → Select category 1, 2, 3 (for example)
   → Press 'I' to install
   ```

2. **Add Individual Packages** (for specific needs)
   ```bash
   ./install/212-cli-tools.sh
   → Press 'C' for Custom Selection
   → Select only: linux-lts-headers, cmake
   → Press 'I' to install
   ```

3. **Fine-tune Later** (add missing tools as needed)
   ```bash
   # Run script again and select individual packages
   # Previously installed packages won't be reinstalled
   ```

## Examples

### Minimal Developer Setup
```bash
# Only essential development tools
./install/212-cli-tools.sh
→ 'C' Custom Selection
→ Select: base-devel, git, linux-headers
→ 'I' Install
```

### Minimal Xorg Setup for i3wm
```bash
# Only core X11 for window manager
./install/213-display-server.sh
→ '6' Individual Packages
→ Select: xorg-server, xorg-xinit, xorg-xrandr
→ 'I' Install
```

### Archive Extraction Only
```bash
# Just extraction tools, no compression
./install/212-cli-tools.sh
→ 'C' Custom Selection
→ Select: unrar, unace, 7zip
→ 'I' Install
```

### Wayland-Only Gaming Setup
```bash
# Wayland + Mesa + Vulkan
./install/213-display-server.sh
→ '6' Individual Packages
→ Select: wayland, wl-clipboard, mesa, vulkan-icd-loader
→ 'I' Install
```

## Tips & Tricks

### 💡 **Combine with Category Install**
- Install a category first, then add missing packages individually
- Category install is faster for bulk packages
- Individual selection for fine-tuning

### 💡 **Use Search Effectively**
- `search header` - Find all header packages
- `search vulkan` - Find graphics API packages
- `search power` - Find power management tools

### 💡 **Check Before Installing**
- Review selected packages before pressing 'I'
- Use 'none' to clear and start over if needed
- Search helps verify package names

### 💡 **Incremental Installation**
- You can run scripts multiple times
- pacman skips already-installed packages
- Safe to experiment with selections

## Future Enhancements

Planned improvements for individual selection:

- [ ] Package dependency visualization
- [ ] Size information per package
- [ ] Conflict detection
- [ ] Save/load selection presets
- [ ] Export package list to file
- [ ] Batch installation from file

## Compatibility

**Works with**:
- ✅ All ALIE installation modes
- ✅ Existing category-based installs
- ✅ Manual pacman/yay usage
- ✅ Automated scripts

**Safe to use**:
- Multiple runs won't reinstall packages
- Can switch between category and individual modes
- No conflicts with system package manager

---

This feature makes ALIE the most flexible Arch Linux installer, giving you complete control over your installation while maintaining the convenience of automated setup.
