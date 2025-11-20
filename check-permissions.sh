#!/bin/bash
# Permission checker script for ALIE project
# Ensures all .sh files have execute permissions
# Run this script to verify and fix permissions if needed

set -eou pipefail

echo "[INFO] Checking execute permissions on shell scripts..."

# Get list of all .sh files in the repository
sh_files=$(git ls-files "*.sh")

if [ -z "$sh_files" ]; then
    echo "[OK] No .sh files found to check"
    exit 0
fi

# Check each .sh file for execute permissions
needs_fix=""
for file in $sh_files; do
    # Check if file has execute permissions in Git index
    perms=$(git ls-files --stage "$file" | awk '{print $1}')
    if [ "$perms" != "100755" ]; then
        needs_fix="$needs_fix $file"
    fi
done

if [ -n "$needs_fix" ]; then
    echo "[WARNING] Found .sh files without execute permissions:"
    for file in $needs_fix; do
        perms=$(git ls-files --stage "$file" | awk '{print $1}')
        echo "   $file (current perms: $perms)"
    done
    echo ""
    echo "[FIX] Fixing permissions..."
    for file in $needs_fix; do
        git update-index --chmod=+x "$file"
        echo "   [OK] Fixed: $file"
    done
    echo ""
    echo "[NOTE] Remember to commit these permission changes:"
    echo "   git commit -m \"Fix execute permissions on shell scripts\""
else
    echo "[OK] All shell scripts have correct execute permissions"
fi