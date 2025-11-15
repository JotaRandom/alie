#!/bin/bash
set -euo pipefail
# ALIE - UFW Advanced Configuration
# More permissive setup for development/desktop

if [ "$EUID" -ne 0 ]; then
	echo "ERROR: firewall script must be run as root" >&2
	exit 1
fi

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Essential services
ufw allow ssh
ufw limit ssh  # Rate limit SSH to prevent brute force

# Common services
ufw allow http
ufw allow https

# Local network access (adjust subnet as needed)
ufw allow from 192.168.1.0/24

# Specific ports for development
ufw allow 3000/tcp comment 'React/Node dev server'
ufw allow 8080/tcp comment 'Alternative HTTP'
ufw allow 5432/tcp comment 'PostgreSQL'

# Allow mDNS for network discovery
ufw allow 5353/udp

# Enable logging (low level to avoid spam)
ufw logging low

# Enable firewall
# ufw enable
