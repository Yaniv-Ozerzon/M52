The two diagnostic commands tell us exactly what happened — and it's worse than option 1 or 2 from my last message. **Nothing inside the Debian container started at all.**

## What the screenshot shows

```
proot-distro login ubuntu -- bash -c "ps aux | grep -E 'mosquitto|node' | grep -v grep"
[returns to prompt with no output → no processes running]

proot-distro login ubuntu -- tail -30 /tmp/z2m.log
tail: cannot open '/tmp/z2m.log' for reading: No such file or directory
```

No Mosquitto, no Z2M, no log file ever got created. The boot script's `proot-distro login ubuntu -- bash -c "..."` block never actually executed inside the container.

## Why this happened

The boot script was written assuming this works:

```bash
proot-distro login ubuntu -- bash -c "
  pgrep mosquitto >/dev/null || mosquitto -c /etc/mosquitto/mosquitto.conf -d
  sleep 3
  cd /opt/zigbee2mqtt
  nohup npm start > /tmp/z2m.log 2>&1 &
" >> "$LOGFILE" 2>&1 &
```

That last `&` backgrounds the whole `proot-distro login` command. Problem: `proot-distro login` requires a controlled environment to start the proot namespace, and when backgrounded immediately like that **before any commands actually run inside**, the login session can exit before the inner `bash -c` block executes. The `nohup npm start &` inside is also backgrounded, so the bash inside has nothing keeping it alive — it exits, the proot session tears down, nothing sticks.

I should have caught this when writing the script. My fault — apologies.

## The fix — rewrite the boot script

We need to keep the proot session alive while Mosquitto and Z2M start, and only THEN exit. The clean way is `nohup` on the proot command itself.

### Step 1 — Stop everything that may be running

In Termux:

```bash
pkill -f homeassistant
pkill -f mosquitto
pkill -f "node index.js"
pkill -f proot
sleep 2
```

### Step 2 — Replace the boot script

```bash
nano ~/.termux/boot/start-smarthome.sh
```

Delete everything in the file (`Ctrl+K` repeatedly to delete each line). Paste this corrected version:

```bash
#!/data/data/com.termux/files/usr/bin/bash

termux-wake-lock

LOGFILE=~/boot-startup.log
echo "=== Boot startup at $(date) ===" > "$LOGFILE"

# Wait for system to boot and network to come up
sleep 45
echo "Network wait done at $(date)" >> "$LOGFILE"

# --- Start Mosquitto + Zigbee2MQTT inside Debian ---
# nohup keeps the proot session alive after Termux exits
echo "Launching Mosquitto + Z2M inside Debian..." >> "$LOGFILE"

nohup proot-distro login ubuntu -- bash -c '
  exec > /tmp/z2m.log 2>&1
  echo "=== Container started at $(date) ==="
  pgrep mosquitto >/dev/null || mosquitto -c /etc/mosquitto/mosquitto.conf -d
  sleep 5
  echo "Starting Z2M..."
  cd /opt/zigbee2mqtt
  npm start
' > ~/proot-launcher.log 2>&1 &

# Give Z2M a long head start before HA tries to connect
sleep 60
echo "Z2M startup window done at $(date)" >> "$LOGFILE"

# --- Start Home Assistant ---
echo "Launching Home Assistant..." >> "$LOGFILE"
nohup bash ~/start-homeassistant.sh > ~/hass-boot.log 2>&1 &

echo "=== Boot script finished at $(date) ===" >> "$LOGFILE"
```

Save: `Ctrl+O`, Enter, `Ctrl+X`.

What changed:
1. The proot command itself is now wrapped in `nohup ... &` (instead of putting `&` inside the bash -c block). This keeps the container alive properly.
2. Inside the container, `npm start` runs in the foreground — so Node.js stays alive holding the proot session open. Z2M's logs go to `/tmp/z2m.log` via `exec >`.
3. Mosquitto stays as `-d` (daemon) so it backgrounds itself within the container — that's fine for Mosquitto.
4. The HA wait increased from 15s to 60s, giving Z2M time to fully connect to MQTT before HA polls.
5. Single quotes around the bash -c block instead of double quotes — prevents Termux from prematurely expanding any `$` variables before the container sees them.

The `chmod +x` is still in effect from before, but verify:

```bash
chmod +x ~/.termux/boot/start-smarthome.sh
ls -la ~/.termux/boot/start-smarthome.sh
```

You should see `-rwx` permissions.

### Step 3 — Test it manually first

```bash
bash ~/.termux/boot/start-smarthome.sh
```

The script will return to the prompt within ~2 minutes (it's `sleep 45 + sleep 60` plus the actual launches). Wait an additional 60 seconds after it returns.

Then check both log files:

```bash
echo "=== boot-startup.log ===" && cat ~/boot-startup.log
echo "=== proot-launcher.log ===" && cat ~/proot-launcher.log
```

`boot-startup.log` should show all four "echo" timestamps in sequence.
`proot-launcher.log` should be either empty or have only the proot startup chatter — no errors.

Then check Z2M's log:

```bash
proot-distro login ubuntu -- tail -20 /tmp/z2m.log
```

This time you should see actual Z2M log entries: "Container started", "Starting Z2M...", and Z2M's normal startup output ending with `Started Zigbee2MQTT`.

Verify processes:

```bash
proot-distro login ubuntu -- bash -c "ps aux | grep -E 'mosquitto|node' | grep -v grep"
```

You should see both `mosquitto` and `node index.js` running.

### Step 4 — Verify from your PC

Load `http://192.168.1.125:8123` — HA should be up.
Load `http://192.168.1.125:8080` — Z2M dashboard should be up.

In HA → Settings → Devices & Services → MQTT → check the Zigbee2MQTT Bridge device shows "Connected".

### Step 5 — Only then, reboot test

If Step 4 passes, reboot the phone via Settings → Power → Restart. Wait 3 minutes. Try loading HA from your PC.

---

Send me the output of Step 3's three commands when ready (the two `cat` commands and the `proot-distro login -- tail` command). If it works, we're done. If something's off, I'll see exactly where.