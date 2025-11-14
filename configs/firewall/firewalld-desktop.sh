#!/bin/bash
# ALIE - Firewalld Desktop Configuration
# Permissive setup for development workstation

# Set default zone
firewall-cmd --set-default-zone=public

# Create a development zone
firewall-cmd --permanent --new-zone=development 2>/dev/null || true
firewall-cmd --permanent --zone=development --set-target=ACCEPT

# Public zone - essential services
firewall-cmd --permanent --zone=public --add-service=ssh
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-service=mdns

# Development ports
firewall-cmd --permanent --zone=public --add-port=3000/tcp  # React/Node
firewall-cmd --permanent --zone=public --add-port=8080/tcp  # Alt HTTP
firewall-cmd --permanent --zone=public --add-port=5432/tcp  # PostgreSQL

# Trust local network (adjust as needed)
firewall-cmd --permanent --zone=trusted --add-source=192.168.1.0/24

# Enable masquerading (useful for VMs/containers)
firewall-cmd --permanent --zone=public --add-masquerade

# Reload and show config
firewall-cmd --reload
firewall-cmd --list-all-zones
