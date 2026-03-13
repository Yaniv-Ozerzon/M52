#!/data/data/com.termux/files/usr/bin/bash
echo "[*] Stopping Home Assistant Services..."

# סגירת תהליכים עם Root
tsu -c "pkill -f hass"
tsu -c "proot-distro login ubuntu -- service dbus stop > /dev/null 2>&1"
tsu -c "termux-wake-unlock"

echo "[✔] All services stopped."