#!/bin/bash
# Test script to validate doas configuration
# This script checks if doas.conf follows ArchWiki standards

echo "=== ALIE doas Configuration Validator ==="
echo

# Check if opendoas is installed
if ! command -v doas &>/dev/null; then
    echo "❌ ERROR: doas command not found"
    echo "   Install with: pacman -S opendoas"
    exit 1
fi

echo "✅ doas command is available"

# Check if configuration file exists
if [ ! -f /etc/doas.conf ]; then
    echo "❌ ERROR: /etc/doas.conf does not exist"
    echo "   Create configuration first"
    exit 1
fi

echo "✅ /etc/doas.conf exists"

# Check file permissions (must be root:root 0400)
file_perms=$(stat -c "%a" /etc/doas.conf 2>/dev/null)
file_owner=$(stat -c "%U:%G" /etc/doas.conf 2>/dev/null)

if [ "$file_perms" != "400" ]; then
    echo "❌ ERROR: Wrong permissions on /etc/doas.conf"
    echo "   Current: $file_perms, Expected: 400"
    echo "   Fix with: chmod 0400 /etc/doas.conf"
    exit 1
fi

if [ "$file_owner" != "root:root" ]; then
    echo "❌ ERROR: Wrong ownership on /etc/doas.conf"
    echo "   Current: $file_owner, Expected: root:root"
    echo "   Fix with: chown root:root /etc/doas.conf"
    exit 1
fi

echo "✅ File permissions are correct (root:root 0400)"

# Check configuration syntax
if doas -C /etc/doas.conf &>/dev/null; then
    echo "✅ Configuration syntax is valid"
else
    echo "❌ ERROR: Configuration syntax is invalid"
    echo "   Check your /etc/doas.conf for syntax errors"
    exit 1
fi

# Check if configuration ends with newline
if [ "$(tail -c1 /etc/doas.conf | wc -l)" -eq 1 ]; then
    echo "✅ Configuration ends with newline"
else
    echo "⚠️  WARNING: Configuration should end with newline"
    echo "   This might cause issues - add a blank line at the end"
fi

# Show current configuration
echo
echo "📋 Current /etc/doas.conf contents:"
echo "----------------------------------------"
cat /etc/doas.conf
echo "----------------------------------------"

# Test if current user can use doas (if running as non-root)
if [ "$EUID" -ne 0 ]; then
    echo
    echo "🧪 Testing doas access for current user..."
    if doas -n true 2>/dev/null; then
        echo "✅ Current user can use doas without password prompt"
    else
        echo "⚠️  Current user needs password for doas (normal)"
        echo "   Try: doas true"
    fi
else
    echo "⚠️  Running as root - cannot test user doas access"
fi

echo
echo "=== doas Configuration Check Complete ==="