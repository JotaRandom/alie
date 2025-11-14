#!/bin/bash
# ALIE - UFW (Uncomplicated Firewall) Basic Configuration
# This file contains minimal safe firewall rules

# Enable UFW on boot
# sudo systemctl enable ufw

# Default policies
# Deny all incoming by default, allow all outgoing
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (important: don't lock yourself out!)
ufw allow ssh
# Or specific port: ufw allow 22/tcp

# Allow common services (uncomment as needed)
# HTTP/HTTPS
#ufw allow 80/tcp
#ufw allow 443/tcp

# DNS
#ufw allow 53

# Enable UFW
ufw enable

# Show status
ufw status verbose
