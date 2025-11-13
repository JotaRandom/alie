#!/bin/bash
# DEMO: ALIE Interactive CLI Tools Selection
# This is a demo script to show the menu without installing anything

# Simple color definitions for demo
CYAN='\033[0;36m'
NC='\033[0m'
YELLOW='\033[1;33m'

# Demo functions
print_info() { echo -e "ℹ️  $1"; }
print_section_header() { 
    echo "============================================================"
    echo "    $1"
    echo "    $2" 
    echo "============================================================"
}

# Show main menu
show_main_menu() {
    clear
    echo ""
    print_section_header "CLI Tools Categories" "Choose what to install (DEMO MODE)"
    echo ""
    print_info "Available categories:"
    echo ""
    echo "  ${CYAN}1.${NC} 📁 Archive Tools        - Extractors, compressors (7zip, rar, zstd)"
    echo "  ${CYAN}2.${NC} ⚡ System Utilities     - Modern CLI replacements (exa, bat, fd, ripgrep)"
    echo "  ${CYAN}3.${NC} 🔧 Development Tools    - Compilers, build systems, linux-headers"
    echo "  ${CYAN}4.${NC} 🛡️  Security Tools       - VPN, encryption, security auditing"
    echo "  ${CYAN}5.${NC} 🎵 Media Tools          - Audio, video, image processing"
    echo "  ${CYAN}6.${NC} 💻 Admin & Laptop Tools - System monitoring, power management"
    echo "  ${CYAN}7.${NC} 🎨 Shell Enhancements   - Prompt, aliases, configurations"
    echo ""
    echo "  ${CYAN}A.${NC} 🚀 Install All Categories"
    echo "  ${CYAN}Q.${NC} ❌ Quit without installing"
    echo ""
}

# Demo selection loop
demo_selection() {
    local selected_categories=()
    local input
    
    while true; do
        show_main_menu
        
        if [ ${#selected_categories[@]} -gt 0 ]; then
            print_info "Selected: $(printf "%s " "${selected_categories[@]}")"
            echo ""
        fi
        
        printf "${CYAN}Select categories (1-7), 'A' for all, 'D' for demo install, 'Q' to quit: ${NC}"
        read -r input
        
        case "$input" in
            [1-7])
                # Toggle category selection
                if [[ " ${selected_categories[*]} " =~ " $input " ]]; then
                    # Remove from selection
                    selected_categories=($(printf '%s\n' "${selected_categories[@]}" | grep -v "^$input$"))
                else
                    # Add to selection
                    selected_categories+=("$input")
                fi
                ;;
            [aA])
                selected_categories=("1" "2" "3" "4" "5" "6" "7")
                ;;
            [dD])
                if [ ${#selected_categories[@]} -eq 0 ]; then
                    echo "⚠️  No categories selected. Please select at least one category."
                    read -p "Press Enter to continue..."
                else
                    demo_install "${selected_categories[@]}"
                    return 0
                fi
                ;;
            [qQ])
                echo "ℹ️  Demo cancelled."
                exit 0
                ;;
            *)
                echo "⚠️  Invalid option. Please try again."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Demo installation
demo_install() {
    local categories=("$@")
    clear
    
    echo "============================================================"
    echo "    DEMO: CLI Tools Installation Preview"
    echo "============================================================"
    echo ""
    
    echo "🚀 You selected the following categories:"
    for cat in "${categories[@]}"; do
        case "$cat" in
            1) echo "  • 📁 Archive Tools (7zip, unrar, zstd, lz4, p7zip, atool)" ;;
            2) echo "  • ⚡ System Utilities (exa, bat, fd, ripgrep, htop, btop, neofetch)" ;;
            3) echo "  • 🔧 Development Tools (linux-headers, base-devel, git, python, rust, go)" ;;
            4) echo "  • 🛡️  Security Tools (openvpn, wireguard, gnupg, nmap, lynis)" ;;
            5) echo "  • 🎵 Media Tools (ffmpeg, imagemagick, youtube-dl, pandoc)" ;;
            6) echo "  • 💻 Admin & Laptop Tools (powertop, tlp, acpi, lm_sensors)" ;;
            7) echo "  • 🎨 Shell Enhancements (aliases, bash completion, starship)" ;;
        esac
    done
    
    echo ""
    echo "💡 In the real script, this would install approximately $(( ${#categories[@]} * 15 )) packages"
    echo ""
    echo "✅ Demo completed! The real script would now:"
    echo "   1. Validate AUR helper is available"
    echo "   2. Install packages in each selected category"
    echo "   3. Configure shell enhancements"
    echo "   4. Create useful aliases"
    echo ""
    printf "${YELLOW}Press Enter to exit demo...${NC}"
    read
}

# Run demo
echo "🎬 Starting ALIE CLI Tools Selection Demo"
demo_selection