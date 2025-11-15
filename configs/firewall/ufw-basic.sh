#!/bin/bash
set -euo pipefail
# ALIE - UFW Basic Configuration
# Simple and secure firewall setup

if [ "$EUID" -ne 0 ]; then
	echo "ERROR: firewall script must be run as root" >&2
	exit 1
fi

# Default policies: deny incoming, allow outgoing
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (port 22) - CRITICAL for remote access
# Comment this if you don't need SSH or use a different port
ufw allow ssh

# Optional: Allow specific services (uncomment as needed)
# ufw allow http       # Port 80 - Web server
# ufw allow https      # Port 443 - Secure web server
# ufw allow 8080/tcp   # Custom port example

# Optional: Allow from specific IP/subnet
# ufw allow from 192.168.1.0/24  # Local network
# ufw allow from 10.0.0.5        # Specific IP

# Enable firewall
# Note: Run this manually after reviewing rules
# ufw enable
