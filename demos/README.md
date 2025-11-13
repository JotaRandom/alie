# ALIE Demos & Testing Scripts

This directory contains demonstration and testing scripts for the ALIE installer.

## 🎬 Demo Scripts

### demo-cli-menu.sh
Interactive demonstration of the CLI tools selection menu (212-cli-tools.sh).
- Shows all 7 categories available
- Simulates package installation without actually installing
- Safe to run on any system

### demo-display-server.sh  
Interactive demonstration of the display server selection menu (213-display-server.sh).
- Shows Xorg/Wayland/Both options
- Displays custom component selection
- Safe to run on any system

## 🧪 Testing Scripts

### test-doas-config.sh
Validation script for doas configuration compliance.
- Tests doas configuration syntax
- Validates ArchWiki compliance
- Checks file permissions and ownership

## Usage

Run any demo script directly:
```bash
bash demos/demo-cli-menu.sh
bash demos/demo-display-server.sh
```

Testing scripts should be run on configured systems:
```bash
# Only run after doas is configured
bash demos/test-doas-config.sh
```

## Purpose

These scripts help users:
- Preview functionality before installation
- Understand menu systems and options
- Test configurations safely
- Debug issues with specific components