#!/data/data/com.termux/files/usr/bin/bash

# נתיב מלא לפקודות של טרמוקס כדי שה-Root יזהה אותן
T_PATH="/data/data/com.termux/files/usr/bin"

echo "[*] Initializing Root Environment..."
# הפעלת Wake Lock והחרגת סוללה
su -c "$T_PATH/termux-wake-lock"
su -c "cmd deviceidle whitelist +com.termux"

echo "[*] Starting Home Assistant Core (Root Mode)..."
echo "URL: http://192.168.1.119:8123"

# הפעלת שירותי המערכת בתוך אובונטו
su -c "$T_PATH/proot-distro login ubuntu --bind /dev:/dev -- service dbus start > /dev/null 2>&1"

# הפעלת השרת עצמו עם נתיבים מלאים
su -c "$T_PATH/proot-distro login ubuntu --bind /dev:/dev --bind /sys:/sys -- /data/data/com.termux/files/home/hass-venv/bin/hass -c /data/data/com.termux/files/home/hass-config"
