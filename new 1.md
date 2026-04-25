Since you're already rooted, that's a meaningful difference — we have better tools available. Let me give you the clean instructions.

## Why root changes the approach

Without root, we'd use `Termux:Boot` and accept some unreliability. With root, we can use `init.d`-style boot scripts that run at the system level. This is more reliable and survives Samsung's battery management better.

But I'm going to give you both options and recommend the simpler one first. **Termux:Boot still works on rooted phones**, and it's much easier to set up than Magisk modules. If it works reliably, no need to overcomplicate.

## Recommended path: Termux:Boot first, root option as backup

Try Termux:Boot first. If it proves unreliable after a week, we upgrade to a Magisk module.

---

## Part 1 — Install Termux:Boot

### Step 1 — Install from F-Droid

Open F-Droid → search **Termux:Boot** → install.

If F-Droid shows two options, pick the one published by **Fredrik Fornwall** (the original Termux maintainer).

### Step 2 — Open Termux:Boot once

Launch the app. The screen will show a brief description and not much else. **You must open it once** — Android won't grant boot permissions until the app has been launched.

Close it.

### Step 3 — Galaxy S10 Lite battery settings

Even with root, do these — they prevent unnecessary fights with Samsung's battery manager:

**Settings → Apps → Termux → Battery → Unrestricted**
**Settings → Apps → Termux:Boot → Battery → Unrestricted**

**Settings → Battery and device care → Battery → Background usage limits:**
- **Never sleeping apps**: add Termux and Termux:Boot
- Make sure they're NOT in the Sleeping or Deep sleeping lists

**Settings → Connections → Wi-Fi → ⋮ Advanced → Keep Wi-Fi on during sleep → Always**

---

## Part 2 — Create the boot script

### Step 1 — Create the boot directory

In **regular Termux** (open a fresh session — `~ $` prompt):

```bash
mkdir -p ~/.termux/boot
```

### Step 2 — Create the script

```bash
nano ~/.termux/boot/start-smarthome.sh
```

Paste this exactly:

```bash
#!/data/data/com.termux/files/usr/bin/bash

# Acquire wake lock so Termux survives screen-off
termux-wake-lock

# Wait for system to fully boot and network to come up
sleep 45

# Log everything
LOGFILE=~/boot-startup.log
echo "=== Boot startup at $(date) ===" > "$LOGFILE"

# --- Start Mosquitto + Zigbee2MQTT inside Debian container ---
echo "Starting Mosquitto and Zigbee2MQTT..." >> "$LOGFILE"
proot-distro login ubuntu -- bash -c "
  pgrep mosquitto >/dev/null || mosquitto -c /etc/mosquitto/mosquitto.conf -d
  sleep 3
  cd /opt/zigbee2mqtt
  nohup npm start > /tmp/z2m.log 2>&1 &
" >> "$LOGFILE" 2>&1 &

# Wait for MQTT to be ready before starting HA
sleep 15

# --- Start Home Assistant ---
echo "Starting Home Assistant..." >> "$LOGFILE"
nohup bash ~/start-homeassistant.sh > ~/hass-boot.log 2>&1 &

echo "=== Startup script finished at $(date) ===" >> "$LOGFILE"
```

Save: `Ctrl+O`, Enter, `Ctrl+X`.

### Step 3 — Make it executable

```bash
chmod +x ~/.termux/boot/start-smarthome.sh
```

### Step 4 — Verify the file is in place

```bash
ls -la ~/.termux/boot/
```

You should see `start-smarthome.sh` listed with `-rwx` permissions. If you see `-rw-` (no `x`), the chmod didn't work — repeat Step 3.

---

## Part 3 — Test without rebooting first

Before committing to a full reboot, let's test the script directly.

### Step 1 — Stop everything currently running

In whatever Termux sessions you have HA and Z2M running, press **Ctrl+C** to stop them. Or just kill them all from a fresh session:

```bash
pkill -f homeassistant
pkill -f mosquitto
pkill -f "node index.js"
sleep 2
ps aux | grep -E "homeassistant|mosquitto|node" | grep -v grep
```

The last command should return nothing (or just the grep itself). Everything is now stopped.

### Step 2 — Run the boot script manually

```bash
bash ~/.termux/boot/start-smarthome.sh
```

It will return to the prompt within ~60 seconds. Don't worry — the work happens in the background.

### Step 3 — Wait 2–3 minutes, then verify

After waiting:

```bash
cat ~/boot-startup.log
```

You should see all three "echo" messages, with timestamps about 60 seconds apart.

Now check from your PC: load `http://192.168.1.125:8123` in a browser. **HA should load.** Then load `http://192.168.1.125:8080` — **Z2M dashboard should load**.

If both work → the script works.
If something doesn't work, send me `cat ~/boot-startup.log` and `cat ~/hass-boot.log`.

---

## Part 4 — The actual reboot test

Only after Part 3 passes:

1. Just reboot the phone normally — **Settings → Power → Restart**, or hold the power button.
2. Wait **3 minutes** after the lock screen appears (the script has `sleep 45` plus Z2M takes a bit, plus HA takes 60–90 seconds to be reachable).
3. From your PC, load `http://192.168.1.125:8123`.

If HA loads — auto-start works. Done.

If HA doesn't load after 5 minutes:
- Open Termux on the phone (the regular Termux app)
- Run `cat ~/boot-startup.log`
- Send me the output

---

## If reboot test fails — fallback to Magisk module

Since you're rooted with Magisk, if Termux:Boot proves unreliable, the cleaner solution is a Magisk boot script that runs Termux's startup as root, with no reliance on Termux:Boot's permissions. I can write that module for you, but only if needed — let's not overengineer this until we know the simple path doesn't work.

The Magisk approach has one caveat I want to flag honestly: running Termux processes as root via Magisk has some pitfalls (file ownership confusion, SELinux interactions). It works well, but it's not fire-and-forget — there's debugging if it goes wrong. Termux:Boot is more straightforward.

---

## Honest expectation setting

Even with all of this, here's what reliable means in practice:

- **HA will be reachable >95% of the time.** Good enough for a smart home hub.
- **Some reboots may fail to bring HA up automatically.** Especially if the phone reboots when on slow WiFi or low battery. The fix is opening Termux and running the script manually.
- **You'll occasionally need to manually restart Z2M.** Maybe once a month. This is normal even on dedicated hardware — Zigbee adapters sometimes hang.

If you want true 100% uptime, this is the moment I'd say: a Raspberry Pi with HA OS is the right tool. But for a hobby setup with a repurposed phone, what we're building here is genuinely solid.

Run Part 1, send me a "done" when battery settings are applied, and I'll wait while you do Part 2 and Part 3.