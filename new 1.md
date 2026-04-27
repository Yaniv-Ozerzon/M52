Step 3. I'm giving you all three scripts in this message. Create them one at a time. Don't run anything yet — we test together at the end.

## Script 1 — The "wait for SLZB-06 ready" helper

```bash
nano ~/wait-slzb-ready.sh
```

Paste exactly:

```bash
#!/data/data/com.termux/files/usr/bin/bash
# Waits up to 90 seconds for SLZB-06 Zigbee TCP port to be reachable
# Returns 0 (success) when reachable, 1 (failure) on timeout

SLZB_IP="192.168.1.126"
SLZB_PORT="6638"
TIMEOUT=90

for i in $(seq 1 $TIMEOUT); do
  if timeout 2 bash -c "echo > /dev/tcp/$SLZB_IP/$SLZB_PORT" 2>/dev/null; then
    echo "SLZB-06 ready after ${i}s"
    return 0 2>/dev/null || exit 0
  fi
  sleep 1
done

echo "SLZB-06 not reachable after ${TIMEOUT}s"
exit 1
```

Save: `Ctrl+O`, Enter, `Ctrl+X`.

```bash
chmod +x ~/wait-slzb-ready.sh
```

What this does: tries to open a TCP socket to `192.168.1.126:6638` (the Zigbee port). If the port responds, exits success. Tries every second for 90 seconds. Used by the boot script to make sure SLZB-06 is really ready before launching Z2M.

## Script 2 — The watchdog loop

```bash
nano ~/watchdog-loop.sh
```

Paste exactly:

```bash
#!/data/data/com.termux/files/usr/bin/bash
# Watchdog: checks Mosquitto, Z2M, and HA every 5 minutes
# Restarts whatever's dead. Logs to ~/watchdog.log

LOGFILE=~/watchdog.log

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

log "Watchdog loop started"

while true; do

  # --- Mosquitto ---
  if ! proot-distro login ubuntu -- pgrep mosquitto >/dev/null 2>&1; then
    log "Mosquitto DOWN - restarting"
    proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf -d' >> "$LOGFILE" 2>&1
    sleep 5
  fi

  # --- Zigbee2MQTT ---
  if ! proot-distro login ubuntu -- pgrep -f "node.*index.js" >/dev/null 2>&1; then
    log "Zigbee2MQTT DOWN - restarting"
    nohup proot-distro login ubuntu -- bash -c '
      cd /opt/zigbee2mqtt
      exec npm start
    ' > ~/z2m-watchdog.log 2>&1 &
    disown
    sleep 30
  fi

  # --- Home Assistant ---
  if ! pgrep -f "homeassistant" >/dev/null 2>&1; then
    log "Home Assistant DOWN - restarting"
    nohup bash ~/start-homeassistant.sh > ~/hass-watchdog.log 2>&1 &
    disown
    sleep 30
  fi

  # --- Trim log if it grows too large ---
  if [ -f "$LOGFILE" ] && [ "$(wc -l < "$LOGFILE")" -gt 1000 ]; then
    tail -500 "$LOGFILE" > "$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
  fi

  sleep 300
done
```

Save: `Ctrl+O`, Enter, `Ctrl+X`.

```bash
chmod +x ~/watchdog-loop.sh
```

What this does: infinite loop. Every 5 minutes checks all three services. Restarts any that are dead. Logs every action.

## Script 3 — The new boot script (replaces the current one)

```bash
nano ~/.termux/boot/start-smarthome.sh
```

**First, delete the existing content.** Hold the down arrow until you reach the bottom, then `Ctrl+K` repeatedly to delete each line until the file is empty. Then paste:

```bash
#!/data/data/com.termux/files/usr/bin/bash
# Smart-home boot script — starts Mosquitto, Z2M, HA, and watchdog
# With SLZB-06 readiness check and Z2M retry on INVALID_STATE

termux-wake-lock

LOGFILE=~/boot-startup.log
echo "=== Boot startup at $(date) ===" > "$LOGFILE"

# Wait for system + network to come up
sleep 45
echo "Network wait done at $(date)" >> "$LOGFILE"

# --- Wait for SLZB-06 to be reachable ---
echo "Waiting for SLZB-06..." >> "$LOGFILE"
bash ~/wait-slzb-ready.sh >> "$LOGFILE" 2>&1
SLZB_OK=$?
echo "SLZB-06 readiness check exit: $SLZB_OK" >> "$LOGFILE"

# Extra grace period after SLZB responds (lets Zigbee stack settle)
sleep 15

# --- Start Mosquitto inside Debian ---
echo "Starting Mosquitto..." >> "$LOGFILE"
proot-distro login ubuntu -- bash -c '
  pgrep mosquitto >/dev/null 2>&1 || mosquitto -c /etc/mosquitto/mosquitto.conf -d
' >> "$LOGFILE" 2>&1
sleep 5

# --- Start Zigbee2MQTT with retry on INVALID_STATE ---
# Try up to 3 times, waiting 30s between attempts
for attempt in 1 2 3; do
  echo "Z2M start attempt $attempt at $(date)" >> "$LOGFILE"

  nohup proot-distro login ubuntu -- bash -c '
    cd /opt/zigbee2mqtt
    exec npm start
  ' > ~/z2m-boot.log 2>&1 &
  disown
  Z2M_PID=$!

  # Wait 30s then check if it's still running
  sleep 30
  if proot-distro login ubuntu -- pgrep -f "node.*index.js" >/dev/null 2>&1; then
    echo "Z2M running after attempt $attempt" >> "$LOGFILE"
    break
  fi

  echo "Z2M crashed on attempt $attempt - retrying" >> "$LOGFILE"
  sleep 15
done

# --- Start Home Assistant ---
echo "Starting Home Assistant..." >> "$LOGFILE"
nohup bash ~/start-homeassistant.sh > ~/hass-boot.log 2>&1 &
disown

# --- Start watchdog loop in background ---
echo "Starting watchdog loop..." >> "$LOGFILE"
nohup bash ~/watchdog-loop.sh > ~/watchdog-loop-stdout.log 2>&1 &
disown

echo "=== Boot script finished at $(date) ===" >> "$LOGFILE"
```

Save: `Ctrl+O`, Enter, `Ctrl+X`.

```bash
chmod +x ~/.termux/boot/start-smarthome.sh
```

What this does:
- Waits for network (45s)
- Waits for SLZB-06 to actually answer on port 6638 (up to 90s more)
- Starts Mosquitto
- Starts Z2M with up to 3 retries — if it crashes (INVALID_STATE etc.), retries automatically
- Starts HA
- Starts the watchdog loop

## Verify all three scripts exist and are executable

```bash
ls -la ~/wait-slzb-ready.sh ~/watchdog-loop.sh ~/.termux/boot/start-smarthome.sh
```

Expected: each line starts with `-rwx` (executable). If any shows `-rw-` (no x), the chmod didn't take — re-run the chmod command for that file.

---

**Stop here.** Don't run anything yet. Send me the output of the `ls -la` command. I want to see all three files exist with the right permissions before we test.