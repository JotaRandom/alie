#!/bin/bash
# Script to configure LightDM to use Slick Greeter
# This is required because Slick Greeter is NOT the default

LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

# Modify greeter-session to use slick-greeter
if grep -q "^#greeter-session=" "$LIGHTDM_CONF"; then
    sed -i 's/^#greeter-session=.*/greeter-session=lightdm-slick-greeter/' "$LIGHTDM_CONF"
elif grep -q "^greeter-session=" "$LIGHTDM_CONF"; then
    sed -i 's/^greeter-session=.*/greeter-session=lightdm-slick-greeter/' "$LIGHTDM_CONF"
else
    # Add greeter-session if it doesn't exist
    sed -i '/^\[Seat:\*\]/a greeter-session=lightdm-slick-greeter' "$LIGHTDM_CONF"
fi

echo "LightDM configured to use Slick Greeter"
