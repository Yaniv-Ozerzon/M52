That's expected behavior — but I should have warned you about it. The command isn't hung, it's just silent.

## What's happening

`termux-job-scheduler` doesn't print confirmation when you schedule a job. It registers the job with Android's JobScheduler service and exits silently. So you're sitting at a blank line waiting for output that will never come.

Two scenarios — let's figure out which:

### Scenario 1 (most likely) — already done, just sitting there

If the cursor is just blinking and you can press Enter to get a new prompt, the command finished successfully. Try pressing **Enter** once. You should get a fresh `~ $` prompt back.

### Scenario 2 — Termux:API app isn't installed yet

The `termux-api` Termux package was just installed (visible in your screenshot), but `termux-job-scheduler` also needs the **Termux:API Android app** to be installed and opened at least once. Without that companion app, the command can hang forever waiting to talk to a service that doesn't exist.

## Step 1 — Press Ctrl+C to abort the hung command

If pressing Enter doesn't give you a prompt, force-kill the command:

```
Ctrl+C
```

You should be back at `~ $`.

## Step 2 — Check if Termux:API app is installed

On your phone, look in your app drawer for an app called **Termux:API**. If you don't have it:

1. Open F-Droid
2. Search for **Termux:API**
3. Install it (publisher: Fredrik Fornwall)
4. **Open the app once** — the screen will be mostly empty, that's fine. Just opening it grants Android the permission for the package to talk to its companion app.
5. Close it

## Step 3 — Verify Termux:API works

Back in Termux:

```bash
termux-battery-status
```

If Termux:API is properly set up, this returns JSON with battery info (percentage, charging state, etc.). It's a quick test that the API bridge works.

If it hangs or returns "command not found" or "API service not responding," the app isn't set up correctly. Reinstall and re-open it.

## Step 4 — Schedule the watchdog (now it should return immediately)

```bash
termux-job-scheduler --period-ms 300000 --persisted true --script ~/watchdog.sh
```

You should get the prompt back within 1–2 seconds.

Verify it's scheduled:

```bash
termux-job-scheduler --pending
```

This should print info about the pending job, including the script path.

---

## If you're stuck and don't want to deal with Termux:API

Honestly, the watchdog is useful but not essential. There's a simpler alternative — run the watchdog as a background loop that checks every 5 minutes, started by the boot script:

```bash
nano ~/watchdog-loop.sh
```

Paste:

```bash
#!/data/data/com.termux/files/usr/bin/bash
while true; do
  bash ~/watchdog.sh
  sleep 300
done
```

Save, make executable:

```bash
chmod +x ~/watchdog-loop.sh
```

Then add this line to the END of `~/.termux/boot/start-smarthome.sh` (just before the final `echo "=== Boot script finished..."`):

```bash
nohup bash ~/watchdog-loop.sh > ~/watchdog-loop.log 2>&1 &
disown
```

This avoids termux-job-scheduler and Termux:API entirely. The boot script kicks off an infinite-loop watchdog that runs every 5 minutes for as long as Termux is alive. It's slightly less robust (if Termux dies, the watchdog dies too), but for our use case where the boot script *is* what brings everything up, that's actually fine.

---

Press Ctrl+C to clear the hung command, then tell me whether you want to install Termux:API or use the simpler loop approach. I'd lean toward the loop approach honestly — fewer moving parts, easier to debug.

















Good call. Let's make this resilient.

Two pieces:

1. **Robust boot script** — replaces the existing one with proper `nohup`/`disown` for both services
2. **Watchdog** — checks every 5 minutes whether Mosquitto, Z2M, and HA are alive; restarts whatever's dead

We'll also clean up the running mess first so we're starting from a known state.

---

## Part 1 — Stop everything cleanly

In **regular Termux** (not inside Debian — `~ $` prompt):

```bash
pkill -f homeassistant
pkill -f "node index.js"
proot-distro login ubuntu -- pkill -f mosquitto
sleep 3
```

Verify everything's dead:

```bash
ps aux | grep -E "homeassistant|node index|mosquitto" | grep -v grep
```

Output should be empty. If not, run the `pkill` commands again.

---

## Part 2 — Replace the boot script

```bash
nano ~/.termux/boot/start-smarthome.sh
```

Delete everything (`Ctrl+K` repeatedly to clear lines), paste this:

```bash
#!/data/data/com.termux/files/usr/bin/bash
# Smart-home boot script — starts Mosquitto, Z2M, and HA

termux-wake-lock

LOGFILE=~/boot-startup.log
echo "=== Boot startup at $(date) ===" > "$LOGFILE"

# Wait for system + network
sleep 45
echo "Network wait done at $(date)" >> "$LOGFILE"

# --- Start Mosquitto inside Debian (as a daemon - survives shell exit) ---
echo "Starting Mosquitto..." >> "$LOGFILE"
proot-distro login ubuntu -- bash -c '
  pgrep mosquitto >/dev/null 2>&1 || mosquitto -c /etc/mosquitto/mosquitto.conf -d
' >> "$LOGFILE" 2>&1

sleep 5

# --- Start Zigbee2MQTT inside Debian (as a backgrounded long-running process) ---
echo "Starting Zigbee2MQTT..." >> "$LOGFILE"
nohup proot-distro login ubuntu -- bash -c '
  cd /opt/zigbee2mqtt
  exec npm start
' > ~/z2m-boot.log 2>&1 &
disown

# Wait for Z2M to come up before HA tries to connect
sleep 60
echo "Z2M startup window done at $(date)" >> "$LOGFILE"

# --- Start Home Assistant ---
echo "Starting Home Assistant..." >> "$LOGFILE"
nohup bash ~/start-homeassistant.sh > ~/hass-boot.log 2>&1 &
disown

echo "=== Boot script finished at $(date) ===" >> "$LOGFILE"
```

Save: `Ctrl+O`, Enter, `Ctrl+X`. Make sure it's executable:

```bash
chmod +x ~/.termux/boot/start-smarthome.sh
```

What changed from before:
- **Mosquitto runs as a daemon** (the `-d` flag) — survives shell exit naturally
- **Z2M runs as a `nohup` background process with `disown`** — properly orphaned from the parent shell, survives Termux session close
- **HA same treatment** (`nohup ... &; disown`)
- The `exec` inside the inner bash makes Node replace bash, so the proot session stays alive holding only the Node process — no stray shells

---

## Part 3 — Create the watchdog script

```bash
nano ~/watchdog.sh
```

Paste:

```bash
#!/data/data/com.termux/files/usr/bin/bash
# Watchdog - checks Mosquitto, Z2M, and HA every run; restarts dead services
# Schedule this to run every 5 minutes via Termux:Boot or cron

LOGFILE=~/watchdog.log
NOW=$(date '+%Y-%m-%d %H:%M:%S')

log() {
  echo "[$NOW] $1" >> "$LOGFILE"
}

# --- Check Mosquitto ---
if proot-distro login ubuntu -- pgrep mosquitto >/dev/null 2>&1; then
  : # alive, do nothing
else
  log "Mosquitto DOWN - restarting"
  proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf -d' >> "$LOGFILE" 2>&1
  sleep 5
fi

# --- Check Zigbee2MQTT ---
if proot-distro login ubuntu -- pgrep -f "node.*index.js" >/dev/null 2>&1; then
  : # alive
else
  log "Zigbee2MQTT DOWN - restarting"
  nohup proot-distro login ubuntu -- bash -c '
    cd /opt/zigbee2mqtt
    exec npm start
  ' > ~/z2m-watchdog.log 2>&1 &
  disown
  sleep 30
fi

# --- Check Home Assistant ---
if pgrep -f "homeassistant" >/dev/null 2>&1; then
  : # alive
else
  log "Home Assistant DOWN - restarting"
  nohup bash ~/start-homeassistant.sh > ~/hass-watchdog.log 2>&1 &
  disown
  sleep 30
fi

# --- Optional: trim watchdog log if it grows too large ---
if [ -f "$LOGFILE" ] && [ $(wc -l < "$LOGFILE") -gt 1000 ]; then
  tail -500 "$LOGFILE" > "$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
fi
```

Save: `Ctrl+O`, Enter, `Ctrl+X`. Make executable:

```bash
chmod +x ~/watchdog.sh
```

---

## Part 4 — Schedule the watchdog

Termux doesn't have traditional `cron`, so we'll use `termux-job-scheduler` (built into Termux:API) for reliable periodic execution. First check if you have it:

```bash
which termux-job-scheduler
```

If it returns a path → you have it. If it returns "not found":

```bash
pkg install termux-api -y
```

You'll also need the **Termux:API** Android app from F-Droid (separate from Termux itself, like Termux:Boot was). Open F-Droid, search "Termux:API", install. Open it once.

Then schedule the watchdog every 5 minutes:

```bash
termux-job-scheduler --period-ms 300000 --persisted true --script ~/watchdog.sh
```

Breakdown:
- `--period-ms 300000` = run every 5 minutes (300,000 ms)
- `--persisted true` = survives reboots
- `--script ~/watchdog.sh` = what to run

Verify the job is scheduled:

```bash
termux-job-scheduler --pending
```

You should see one pending job pointing to watchdog.sh.

---

## Part 5 — Test the boot script manually first

Don't reboot yet. Run the boot script directly and watch what happens:

```bash
bash ~/.termux/boot/start-smarthome.sh
```

It returns to the prompt within ~2 minutes (plus the sleep timers). Wait an extra 60 seconds, then verify:

```bash
echo "=== boot-startup.log ===" && cat ~/boot-startup.log
echo ""
echo "=== Processes ==="
proot-distro login ubuntu -- bash -c "ps aux | grep -E 'mosquitto|node index' | grep -v grep"
ps aux | grep -i homeassistant | grep -v grep | head -3
```

Expected output:
- `boot-startup.log` shows all 4 timestamped messages
- Inside Debian: one mosquitto process + one node process
- In Termux: HA's Python process

From your PC: load `http://192.168.1.125:8123` and `http://192.168.1.125:8080`. Both should work.

---

## Part 6 — Test the watchdog

While everything's running, manually kill Mosquitto to simulate a crash:

```bash
proot-distro login ubuntu -- pkill mosquitto
```

Then run the watchdog manually (don't wait 5 minutes):

```bash
bash ~/watchdog.sh
```

Check the log:

```bash
cat ~/watchdog.log
```

You should see a line: `[timestamp] Mosquitto DOWN - restarting`. Verify Mosquitto came back:

```bash
proot-distro login ubuntu -- pgrep mosquitto
```

Should return a process ID.

If that works → the watchdog correctly detects and recovers a dead service.

---

## Part 7 — The reboot test

Only after Parts 5 and 6 pass:

1. **Settings → Power → Restart** the phone
2. Wait **3 minutes** after the lock screen
3. From PC, load `http://192.168.1.125:8123` and `http://192.168.1.125:8080`
4. If both work → auto-start with watchdog is fully operational

---

## Honest reality of this setup

With these two scripts:

- **Boot script** handles cold start
- **Watchdog** handles services dying mid-flight
- Together: ~95–99% uptime in practice

What this still doesn't protect against:
- Phone reboots due to Android OS issues (rare on LineageOS)
- Network outages (HA loads but devices unreachable)
- The phone running out of storage (rare on a hub-only device)
- termux-job-scheduler itself being killed by Android (uncommon but possible — set Termux to Unrestricted in battery settings if you haven't already)

If you ever notice the watchdog *itself* not running, you can run it manually any time with `bash ~/watchdog.sh`. And `cat ~/watchdog.log` shows you a history of every restart it's done — so you'll know which service is unstable.

Run Part 1 (stop everything) and Part 5 (manual boot test) first. Send me the output of Part 5's three diagnostic commands. If they look good, do Part 6 to verify watchdog works. If both pass, we're done.