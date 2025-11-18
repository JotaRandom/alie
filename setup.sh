#!/bin/bash
# ALIE Setup Script
# This script sets up the ALIE project for development and execution
# Run this after cloning the repository to ensure proper permissions

set -e

echo "🔧 Setting up ALIE project..."

# Make all shell scripts executable
echo "📁 Making shell scripts executable..."
find . -name "*.sh" -type f -exec chmod +x {} \;

# Make main executable if it exists
if [ -f "alie.sh" ]; then
    echo "🚀 Making main installer executable..."
    chmod +x alie.sh
fi

# Make lmae.sh executable if it exists
if [ -f "lmae.sh" ]; then
    echo "🔄 Making LMAE script executable..."
    chmod +x lmae.sh
fi

echo "✅ Setup complete!"
echo ""
echo "🎯 You can now run the installer with:"
echo "   ./alie.sh"
echo ""
echo "📚 Or run individual scripts:"
echo "   ./install/001-base-install.sh"
echo "   ./install/002-shell-editor-select.sh"
echo "   etc."