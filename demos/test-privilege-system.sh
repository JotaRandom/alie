#!/bin/bash
#
# ALIE - Demo: Privilege Escalation System Test
# Demonstrates and tests the universal privilege escalation system
# Supports: sudo, doas, sudo-rs, and systemd run0
#
# Author: ALIE Project
# License: MIT
#

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load shared functions
source "$PROJECT_ROOT/lib/shared-functions.sh"

# Test configuration
readonly TEST_TITLE="ALIE Privilege Escalation System Test"
readonly TEST_VERSION="1.0.0"

# Print test header
print_header() {
    echo "╔════════════════════════════════════════════════╗"
    echo "║               $TEST_TITLE             ║"
    echo "║                 v$TEST_VERSION                   ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
}

# Test privilege detection
test_privilege_detection() {
    print_section "Testing Privilege Detection"
    
    # Test privilege tool detection
    local priv_tool=$(get_privilege_tool)
    print_info "Detected privilege tool: $priv_tool"
    
    # Test availability of each tool
    echo ""
    print_info "Checking availability of privilege escalation tools:"
    
    for tool in sudo doas sudo-rs run0; do
        if command -v "$tool" &>/dev/null; then
            print_success "✓ $tool: Available"
            
            # Show version if possible
            case $tool in
                sudo|sudo-rs)
                    local version=$($tool -V 2>/dev/null | head -n1 || echo "Version unknown")
                    print_info "  → $version"
                    ;;
                doas)
                    print_info "  → OpenDoas implementation"
                    ;;
                run0)
                    local systemd_ver=$(systemctl --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "unknown")
                    print_info "  → systemd v$systemd_ver"
                    ;;
            esac
        else
            print_warning "✗ $tool: Not available"
        fi
    done
}

# Test privilege access
test_privilege_access() {
    print_section "Testing Privilege Access"
    
    if has_privilege_access; then
        print_success "✓ Privilege access is available"
        
        # Show which tool would be used
        local priv_tool=$(get_privilege_tool)
        print_info "Would use: $priv_tool"
        
        # Test a safe privileged command
        print_info "Testing privileged command execution..."
        if run_privileged "id"; then
            print_success "✓ Privileged command execution successful"
        else
            print_error "✗ Privileged command execution failed"
        fi
    else
        print_warning "✗ No privilege access available"
        print_info "This is expected if running in a restricted environment"
    fi
}

# Test privilege escalation configuration
test_privilege_config() {
    print_section "Testing Privilege Configuration"
    
    # Check for sudo configuration
    if [ -f /etc/sudoers ]; then
        print_success "✓ /etc/sudoers exists"
        local sudo_rules=$(grep -c "^[^#].*ALL.*ALL" /etc/sudoers 2>/dev/null || echo "0")
        print_info "  → Active rules: $sudo_rules"
    else
        print_info "• /etc/sudoers not found"
    fi
    
    # Check for doas configuration
    if [ -f /etc/doas.conf ]; then
        print_success "✓ /etc/doas.conf exists"
        local doas_rules=$(grep -c "^permit" /etc/doas.conf 2>/dev/null || echo "0")
        print_info "  → Permit rules: $doas_rules"
    else
        print_info "• /etc/doas.conf not found"
    fi
    
    # Check for systemd and run0
    if command -v systemctl &>/dev/null; then
        local systemd_ver=$(systemctl --version | head -n1 | awk '{print $2}')
        if [ "$systemd_ver" -ge 254 ] 2>/dev/null; then
            print_success "✓ systemd v$systemd_ver supports run0"
        else
            print_info "• systemd v$systemd_ver (run0 needs v254+)"
        fi
    else
        print_info "• systemd not available"
    fi
}

# Test compatibility functions
test_compatibility() {
    print_section "Testing Compatibility Functions"
    
    # Test privilege preservation across scripts
    print_info "Testing privilege tool consistency..."
    local tool1=$(get_privilege_tool)
    sleep 0.1
    local tool2=$(get_privilege_tool)
    
    if [ "$tool1" = "$tool2" ]; then
        print_success "✓ Privilege tool selection is consistent"
    else
        print_warning "✗ Privilege tool selection inconsistent: $tool1 vs $tool2"
    fi
    
    # Test environment variable handling
    print_info "Testing environment preservation..."
    if run_privileged "printenv USER" &>/dev/null; then
        print_success "✓ Environment variables are preserved"
    else
        print_info "• Environment preservation test skipped (needs privileges)"
    fi
}

# Performance test
test_performance() {
    print_section "Performance Testing"
    
    print_info "Testing privilege tool detection speed..."
    local start_time=$(date +%s.%N)
    
    for i in {1..10}; do
        get_privilege_tool &>/dev/null
    done
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.1")
    
    print_success "✓ 10 detections in ${duration}s (avg: $(echo "scale=4; $duration / 10" | bc -l 2>/dev/null || echo "0.01")s)"
}

# Summary report
print_summary() {
    print_section "System Summary"
    
    local priv_tool=$(get_privilege_tool)
    local has_access=$(has_privilege_access && echo "Yes" || echo "No")
    
    echo "┌─────────────────────────────────────┐"
    echo "│           System Status             │"
    echo "├─────────────────────────────────────┤"
    echo "│ Primary privilege tool: $priv_tool$(printf "%*s" $((12 - ${#priv_tool})) "")│"
    echo "│ Privilege access:       $has_access$(printf "%*s" $((12 - ${#has_access})) "")│"
    echo "│ Operating System:       $(uname -s)$(printf "%*s" $((12 - ${#$(uname -s)})) "")│"
    echo "│ Shell:                  $SHELL$(printf "%*s" $((12 - ${#SHELL})) "")│"
    echo "└─────────────────────────────────────┘"
    
    # Recommendations
    echo ""
    print_info "Recommendations:"
    
    case $priv_tool in
        sudo|sudo-rs)
            echo "• Current setup uses $priv_tool (traditional)"
            echo "• Consider run0 for better security (no SUID)"
            ;;
        doas)
            echo "• Current setup uses doas (minimal)"
            echo "• Good choice for security-focused systems"
            ;;
        run0)
            echo "• Current setup uses run0 (modern)"
            echo "• Excellent choice for systemd-based systems"
            ;;
        none)
            echo "• No privilege escalation tool detected"
            echo "• Install sudo, doas, or enable run0"
            ;;
    esac
}

# Main execution
main() {
    print_header
    
    # Initialize shared functions
    initialize_shared_functions
    
    # Run all tests
    test_privilege_detection
    test_privilege_access
    test_privilege_config
    test_compatibility
    test_performance
    
    # Show summary
    print_summary
    
    print_success "Privilege escalation system test completed!"
    echo ""
    echo "This test verifies ALIE's universal privilege escalation system."
    echo "For more details, see lib/shared-functions.sh"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi