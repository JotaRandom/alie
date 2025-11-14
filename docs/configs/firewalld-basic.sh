#!/bin/bash
# ALIE - Firewalld Basic Configuration
# This file contains minimal safe firewall rules

# Enable firewalld on boot
# sudo systemctl enable firewalld

# Start firewalld
systemctl start firewalld

# Set default zone to public
firewall-cmd --set-default-zone=public

# Allow SSH (important: don't lock yourself out!)
firewall-cmd --permanent --add-service=ssh

# Allow common services (uncomment as needed)
# HTTP/HTTPS
#firewall-cmd --permanent --add-service=http
#firewall-cmd --permanent --add-service=https

# DNS
#firewall-cmd --permanent --add-service=dns

# Reload firewall
firewall-cmd --reload

# Show configuration
firewall-cmd --list-all
