#!/bin/bash
# ALIE - Firewalld Basic Configuration
# Zone-based firewall configuration

# Set default zone to public (restrictive)
firewall-cmd --set-default-zone=public

# Permanent rules (survive reboot)
# Allow SSH - CRITICAL for remote access
firewall-cmd --permanent --zone=public --add-service=ssh

# Optional: Allow specific services (uncomment as needed)
# firewall-cmd --permanent --zone=public --add-service=http
# firewall-cmd --permanent --zone=public --add-service=https
# firewall-cmd --permanent --zone=public --add-port=8080/tcp

# Optional: Create trusted zone for local network
# firewall-cmd --permanent --zone=trusted --add-source=192.168.1.0/24

# Reload to apply permanent rules
firewall-cmd --reload

# Show active configuration
firewall-cmd --list-all
