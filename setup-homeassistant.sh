#!/data/data/com.termux/files/usr/bin/bash
# Home Assistant Core — Rooted Android Installer with Logging

LOG_FILE="/data/data/com.termux/files/home/install.log"
TERMUX_HOME="/data/data/com.termux/files/home"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo "--- Installation Started ---" > "$LOG_FILE"
log "Starting Home Assistant Core Installation..."

# 1. עדכון חבילות
log "Updating Termux packages..."
pkg update && pkg upgrade -y >> "$LOG_FILE" 2>&1

log "Installing required Termux tools..."
pkg install proot-distro tsu termux-api -y >> "$LOG_FILE" 2>&1

# 2. אובונטו
log "Installing Ubuntu container..."
proot-distro install ubuntu >> "$LOG_FILE" 2>&1
proot-distro login ubuntu -- apt update && apt upgrade -y >> "$LOG_FILE" 2>&1

# 3. תלויות
log "Installing build dependencies in Ubuntu (Python, Rust, Bluetooth)..."
proot-distro login ubuntu -- apt install -y python3 python3-pip python3-venv python3-dev \
    build-essential libffi-dev libssl-dev libjpeg-dev zlib1g-dev autoconf \
    cargo pkg-config bluez dbus libuv1-dev >> "$LOG_FILE" 2>&1

# 4. התקנת HA
log "Setting up Python Venv and installing Home Assistant Core..."
proot-distro login ubuntu -- python3 -m venv $TERMUX_HOME/hass-venv >> "$LOG_FILE" 2>&1
proot-distro login ubuntu -- $TERMUX_HOME/hass-venv/bin/pip install --upgrade pip wheel setuptools >> "$LOG_FILE" 2>&1
proot-distro login ubuntu -- $TERMUX_HOME/hass-venv/bin/pip install homeassistant >> "$LOG_FILE" 2>&1

# 5. פאטץ' רשת
log "Applying ifaddr network patch..."
IFADDR_PATCH=$(proot-distro login ubuntu -- find $TERMUX_HOME/hass-venv -name "_posix.py" | grep ifaddr)
proot-distro login ubuntu -- sed -i 's/raise OSError(eno, os.strerror(eno))/return []/g' $IFADDR_PATCH

# 6. הגדרות
log "Creating initial configuration..."
mkdir -p $TERMUX_HOME/hass-config
echo "homeassistant:
  name: My Home
  unit_system: metric
  currency: ILS

http:
  server_host: 0.0.0.0
" > $TERMUX_HOME/hass-config/configuration.yaml

log "Installation Completed Successfully!"
echo "Check $LOG_FILE for details."