#!/bin/bash
set -euo pipefail
# Script to configure LightDM to use Slick Greeter (safe and idempotent)

LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
BACKUP_DIR="/var/backups/alie-configs"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root" >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"

# Ensure the config file exists and create a canonical backup if it does
if [ -f "$LIGHTDM_CONF" ]; then
    BACKUP="$BACKUP_DIR/lightdm.conf.${TIMESTAMP}.bak"
    cp -a "$LIGHTDM_CONF" "$BACKUP" || { echo "Failed to create backup $BACKUP" >&2; exit 1; }
    echo "Backup created: $BACKUP"
else
    echo "LightDM config not found at $LIGHTDM_CONF, creating minimal config"
    mkdir -p "$(dirname "$LIGHTDM_CONF")"
    cat > "$LIGHTDM_CONF" <<'EOF'
[Seat:*]
greeter-session=lightdm-slick-greeter
EOF
    echo "Created minimal $LIGHTDM_CONF"
    exit 0
fi

# Modify greeter-session to use slick-greeter (idempotent)
if grep -qE '^\s*greeter-session=' "$LIGHTDM_CONF"; then
    sed -i 's/^\s*greeter-session=.*/greeter-session=lightdm-slick-greeter/' "$LIGHTDM_CONF" || { echo "Failed to update greeter-session" >&2; exit 1; }
elif grep -qE '^\s*#\s*greeter-session=' "$LIGHTDM_CONF"; then
    sed -i 's/^\s*#\s*greeter-session=.*/greeter-session=lightdm-slick-greeter/' "$LIGHTDM_CONF" || { echo "Failed to uncomment greeter-session" >&2; exit 1; }
else
    # Try to append under [Seat:*] section; if missing, append a new section at end
    if grep -q '^\[Seat:\*\]' "$LIGHTDM_CONF"; then
        sed -i '/^\[Seat:\*\]/a greeter-session=lightdm-slick-greeter' "$LIGHTDM_CONF" || { echo "Failed to add greeter-session under [Seat:*]" >&2; exit 1; }
    else
        echo "[Seat:*]" >> "$LIGHTDM_CONF"
        echo "greeter-session=lightdm-slick-greeter" >> "$LIGHTDM_CONF"
    fi
fi

echo "LightDM configured to use Slick Greeter"
