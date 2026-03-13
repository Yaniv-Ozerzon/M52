#!/data/data/com.termux/files/usr/bin/bash
# Launcher with Hardware Access (Root required)

TERMUX_HOME="/data/data/com.termux/files/home"

# בקשת הרשאות Root וביטול חיסכון בסוללה
tsu -c "termux-wake-lock"
tsu -c "cmd battery-optimization disable com.termux"

# זיהוי IP
PHONE_IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

echo "-----------------------------------------------------"
echo "  Starting Home Assistant Core (Root Mode)"
echo "  URL: http://${PHONE_IP:-localhost}:8123"
echo "-----------------------------------------------------"

# הפעלת D-Bus עבור Bluetooth
tsu -c "proot-distro login ubuntu --bind /dev:/dev -- service dbus start > /dev/null 2>&1"

# הרצה עם גישה מלאה לחומרה (/dev)
tsu -c "proot-distro login ubuntu --bind /dev:/dev --bind /sys:/sys -- $TERMUX_HOME/hass-venv/bin/hass -c $TERMUX_HOME/hass-config"