#!/bin/bash
# ALIE Desktop Tools and Applications (231-desktop-tools.sh)
# This script installs additional desktop applications and tools
# Run AFTER 221-desktop-environment.sh or 222-window-manager.sh
#
# Note: If you installed Cinnamon Mint Mode, you DON'T need this script.
#       Mint Mode already includes all Linux Mint applications.

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/shared-functions.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/shared-functions.sh"

################################################################################
# APPLICATION INSTALLERS (Granular selection with toolkit labels)
################################################################################

# File Management Tools
install_file_tools() {
    log_info "File Management Tools"
    echo ""
    echo "Select file management tools (choose multiple, space-separated):"
    echo "  1) [GTK] Nemo file manager"
    echo "  2) [Qt]  Dolphin file manager"
    echo "  3) [GTK] Nemo extensions (FileRoller, Share, Audio Tab, Image Converter, Preview)"
    echo "  4) [GTK] File Roller (archive manager)"
    echo "  5) [Qt]  Ark (archive manager)"
    echo "  6) Compression tools (p7zip, unrar, unzip, zip)"
    echo "  0) Skip"
    echo ""
    read -r -a choices -p "Enter options [e.g., 1 3 4 6]: "
    
    for choice in "${choices[@]}"; do
        case "$choice" in
            1) install_package nemo ;;
            2) install_package dolphin ;;
            3) install_package nemo-fileroller nemo-share nemo-audio-tab nemo-image-converter nemo-preview ;;
            4) install_package file-roller ;;
            5) install_package ark ;;
            6) install_package p7zip unrar unzip zip ;;
            0) log_info "Skipping file tools"; return ;;
        esac
    done
    
    log_success "File management tools installed"
}

# Text Editors
install_text_editors() {
    log_info "Text Editors"
    echo ""
    echo "Select text editors:"
    echo "  1) [GTK] Gedit"
    echo "  2) [GTK] Mousepad"
    echo "  3) [Qt]  Kate"
    echo "  4) [Qt]  KWrite"
    echo "  0) Skip"
    echo ""
    read -r -a choices -p "Enter options [e.g., 1 3]: "
    
    for choice in "${choices[@]}"; do
        case "$choice" in
            1) install_package gedit ;;
            2) install_package mousepad ;;
            3) install_package kate ;;
            4) install_package kwrite ;;
            0) log_info "Skipping text editors"; return ;;
        esac
    done
    
    log_success "Text editors installed"
}

# System Utilities
install_system_utilities() {
    log_info "System Utilities"
    echo ""
    echo "Select system utilities:"
    echo "  1) [GTK] GNOME Calculator"
    echo "  2) [GTK] GNOME Disk Utility"
    echo "  3) [GTK] GNOME System Monitor"
    echo "  4) [GTK] GNOME Screenshot"
    echo "  5) [GTK] GNOME Font Viewer"
    echo "  6) [GTK] Character Map (gucharmap)"
    echo "  7) [GTK] System Config Printer"
    echo "  8) [Qt]  Konsole (terminal)"
    echo "  9) [Qt]  Spectacle (screenshot)"
    echo "  0) Skip"
    echo ""
    read -r -a choices -p "Enter options [e.g., 1 2 3]: "
    
    for choice in "${choices[@]}"; do
        case "$choice" in
            1) install_package gnome-calculator ;;
            2) install_package gnome-disk-utility ;;
            3) install_package gnome-system-monitor ;;
            4) install_package gnome-screenshot ;;
            5) install_package gnome-font-viewer ;;
            6) install_package gucharmap ;;
            7) install_package system-config-printer ;;
            8) install_package konsole ;;
            9) install_package spectacle ;;
            0) log_info "Skipping system utilities"; return ;;
        esac
    done
    
    log_success "System utilities installed"
}

# Productivity Suite (LibreOffice - Java/C++)
install_productivity() {
    log_info "Installing Productivity Suite..."
    
    local packages=(
        libreoffice-fresh
        libreoffice-fresh-es
        hunspell-en_us
        hunspell-es_es
    )
    
    install_package "${packages[@]}"
    log_success "Productivity suite installed"
}

# Image Viewers & Editors
install_image_tools() {
    log_info "Image Viewers & Editors"
    echo ""
    echo "Select image tools:"
    echo "  1) [GTK] Eye of GNOME (EOG) - image viewer"
    echo "  2) [GTK] Pix - image viewer & organizer"
    echo "  3) [GTK] Drawing - simple drawing app"
    echo "  4) [Qt]  Gwenview - image viewer"
    echo "  5) [GTK] GIMP - advanced image editing"
    echo "  6) [GTK] Inkscape - vector graphics"
    echo "  7) [Qt]  Krita - digital painting"
    echo "  0) Skip"
    echo ""
    read -r -a choices -p "Enter options [e.g., 1 5 6]: "
    
    for choice in "${choices[@]}"; do
        case "$choice" in
            1) install_package eog ;;
            2) install_package pix ;;
            3) install_package drawing ;;
            4) install_package gwenview ;;
            5) install_package gimp ;;
            6) install_package inkscape ;;
            7) install_package krita ;;
            0) log_info "Skipping image tools"; return ;;
        esac
    done
    
    log_success "Image tools installed"
}

# Video Tools
install_video_tools() {
    log_info "Video Tools"
    echo ""
    echo "Select video tools:"
    echo "  1) [Qt]  Kdenlive - video editor"
    echo "  2) [Qt]  OBS Studio - streaming/recording"
    echo "  3) [GTK] Celluloid - MPV-based video player"
    echo "  4) [Qt]  VLC - multimedia player"
    echo "  5) FFmpeg - multimedia framework"
    echo "  6) [GTK] Handbrake - video transcoder"
    echo "  0) Skip"
    echo ""
    read -r -a choices -p "Enter options [e.g., 1 4 5]: "
    
    for choice in "${choices[@]}"; do
        case "$choice" in
            1) install_package kdenlive ;;
            2) install_package obs-studio ;;
            3) install_package celluloid ;;
            4) install_package vlc ;;
            5) install_package ffmpeg ;;
            6) install_package handbrake ;;
            0) log_info "Skipping video tools"; return ;;
        esac
    done
    
    log_success "Video tools installed"
}

# Audio Tools
install_audio_tools() {
    log_info "Audio Tools"
    echo ""
    echo "Select audio tools:"
    echo "  1) [wxWidgets] Audacity - audio editor"
    echo "  2) [GTK] Rhythmbox - music player"
    echo "  3) [Qt]  Elisa - music player"
    echo "  4) [Qt]  K3b - CD/DVD burning"
    echo "  0) Skip"
    echo ""
    read -r -a choices -p "Enter options [e.g., 1 2]: "
    
    for choice in "${choices[@]}"; do
        case "$choice" in
            1) install_package audacity ;;
            2) install_package rhythmbox ;;
            3) install_package elisa ;;
            4) install_package k3b ;;
            0) log_info "Skipping audio tools"; return ;;
        esac
    done
    
    log_success "Audio tools installed"
}

# Document Viewers
install_document_viewers() {
    log_info "Document Viewers"
    echo ""
    echo "Select document viewers:"
    echo "  1) [GTK] Evince - PDF/document viewer"
    echo "  2) [Qt]  Okular - PDF/document viewer"
    echo "  0) Skip"
    echo ""
    read -r -a choices -p "Enter options [e.g., 1]: "
    
    for choice in "${choices[@]}"; do
        case "$choice" in
            1) install_package evince ;;
            2) install_package okular ;;
            0) log_info "Skipping document viewers"; return ;;
        esac
    done
    
    log_success "Document viewers installed"
}

# Internet Applications
install_internet() {
    log_info "Internet Applications"
    echo ""
    echo "Select internet applications:"
    echo "  1) [GTK] Firefox browser"
    echo "  2) [GTK] Thunderbird email client"
    echo "  3) [GTK] Transmission BitTorrent client"
    echo "  4) [wxWidgets] FileZilla FTP client"
    echo "  0) Skip"
    echo ""
    read -r -a choices -p "Enter options [e.g., 1 2 3]: "
    
    for choice in "${choices[@]}"; do
        case "$choice" in
            1) install_package firefox firefox-i18n-es-es ;;
            2) install_package thunderbird ;;
            3) install_package transmission-gtk ;;
            4) install_package filezilla ;;
            0) log_info "Skipping internet apps"; return ;;
        esac
    done
    
    log_success "Internet applications installed"
}

install_mint_themes() {
    log_info "Linux Mint Themes Information"
    log_warning "Mint themes require AUR helper (yay/paru)"
    log_info "Install with: yay -S mint-themes mint-y-icons mint-x-icons"
    echo ""
    read -r -p "Press Enter to continue..."
}

# Development Tools
install_development() {
    log_info "Development Tools"
    echo ""
    echo "Select development tools:"
    echo "  1) Git version control"
    echo "  2) base-devel (build tools)"
    echo "  3) [Electron] Visual Studio Code"
    echo "  4) Docker & Docker Compose"
    echo "  5) Python (python, pip)"
    echo "  6) Node.js & npm"
    echo "  7) [Java] JetBrains IDEs info (PyCharm, IntelliJ - requires AUR)"
    echo "  0) Skip"
    echo ""
    read -r -a choices -p "Enter options [e.g., 1 2 3]: "
    
    for choice in "${choices[@]}"; do
        case "$choice" in
            1) install_package git ;;
            2) install_package base-devel ;;
            3) install_package code ;;
            4) install_package docker docker-compose ;;
            5) install_package python python-pip ;;
            6) install_package nodejs npm ;;
            7)
                log_warning "JetBrains IDEs require AUR helper"
                log_info "Install with: yay -S pycharm-community-edition intellij-idea-community-edition"
                read -r -p "Press Enter to continue..."
                ;;
            0) log_info "Skipping development tools"; return ;;
        esac
    done
    
    log_success "Development tools installed"
}

install_gaming() {
    log_info "Installing Gaming Platform..."
    
    # Enable multilib for 32-bit support
    log_info "Enabling multilib repository..."
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
        pacman -Sy
    fi
    
    local packages=(
        steam
        lutris
        wine-staging
        winetricks
        gamemode
        lib32-nvidia-utils  # If using NVIDIA
    )
    
    install_package "${packages[@]}"
    log_success "Gaming platform installed"
}

################################################################################
# MENU SYSTEM
################################################################################

show_tools_menu() {
    echo ""
    log_info "Desktop Applications Installer"
    echo ""
    log_info "Toolkit labels: [GTK] [Qt] [Electron] [wxWidgets] [Java]"
    echo "  GTK      = GNOME/Cinnamon/XFCE native"
    echo "  Qt       = KDE Plasma native"
    echo "  Electron = Cross-platform (heavier)"
    echo "  wxWidgets/Java = Cross-platform frameworks"
    echo ""
    echo "Select application categories:"
    echo ""
    echo "  1) File Management (file managers, archives)"
    echo "  2) Text Editors (Gedit, Kate, etc.)"
    echo "  3) System Utilities (calculator, monitors, etc.)"
    echo "  4) Image Viewers & Editors (GIMP, Krita, etc.)"
    echo "  5) Video Tools (Kdenlive, VLC, etc.)"
    echo "  6) Audio Tools (Audacity, music players)"
    echo "  7) Document Viewers (PDF readers)"
    echo "  8) Productivity (LibreOffice)"
    echo "  9) Internet (Firefox, Thunderbird, etc.)"
    echo "  10) Mint Themes (AUR info)"
    echo "  11) Development (VS Code, Git, Docker)"
    echo "  12) Gaming (Steam, Lutris, Wine)"
    echo ""
    echo "  13) Install ALL categories"
    echo ""
    echo "  0) Exit"
    echo ""
    
    read -r -p "Select option [0-13]: " choice
    
    case "$choice" in
        1) install_file_tools ;;
        2) install_text_editors ;;
        3) install_system_utilities ;;
        4) install_image_tools ;;
        5) install_video_tools ;;
        6) install_audio_tools ;;
        7) install_document_viewers ;;
        8) install_productivity ;;
        9) install_internet ;;
        10) install_mint_themes ;;
        11) install_development ;;
        12) install_gaming ;;
        13)
            log_info "Installing all categories..."
            install_file_tools
            install_text_editors
            install_system_utilities
            install_image_tools
            install_video_tools
            install_audio_tools
            install_document_viewers
            install_productivity
            install_internet
            install_mint_themes
            install_development
            install_gaming
            ;;
        0)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    require_root
    
    log_section "ALIE Desktop Applications Installer"
    
    log_info "This script installs desktop applications with granular selection"
    echo ""
    echo "Categories available:"
    echo "  - File Management (Nemo, Dolphin, archives)"
    echo "  - Text Editors (Gedit, Kate, etc.)"
    echo "  - System Utilities (calculator, monitors)"
    echo "  - Image Tools (GIMP, Krita, viewers)"
    echo "  - Video Tools (Kdenlive, VLC, OBS)"
    echo "  - Audio Tools (Audacity, music players)"
    echo "  - Document Viewers (PDF readers)"
    echo "  - Productivity (LibreOffice)"
    echo "  - Internet (Firefox, Thunderbird)"
    echo "  - Development (VS Code, Git, Docker)"
    echo "  - Gaming (Steam, Lutris, Wine)"
    echo ""
    log_warning "Desktop environment must be installed first!"
    echo "  Run 220-desktop-select.sh if not done"
    echo ""
    read -r -p "Press Enter to continue or Ctrl+C to exit..."
    
    # Show menu and install
    show_tools_menu
    
    log_section "Desktop Tools Installation Completed"
    
    echo ""
    log_success "Desktop tools installation completed!"
    echo ""
    log_info "Next steps:"
    echo "  - Explore your installed applications"
    echo "  - Configure your desktop environment"
    echo "  - For Mint themes, install AUR helper first:"
    echo "    bash install/211-install-yay.sh (as user)"
    echo "    yay -S mint-themes mint-y-icons mint-x-icons"
    echo ""
}

# Run main function
main "$@"
