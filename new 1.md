All three files exist with `-rwx` permissions. Sizes look right (1895, 484, 1290 bytes). You're good.

Now we test before any reboot.

## Step 4 — Test the helper script first (safest test)

This script just probes the SLZB-06 — it changes nothing. Quick sanity check:

```bash
bash ~/wait-slzb-ready.sh
```

**Expected output:** `SLZB-06 ready after 1s` (or any number from 1 to 90).

If you see "SLZB-06 ready" → great, the helper works. Continue.
If you see "SLZB-06 not reachable after 90s" → the SLZB-06 isn't reachable from Termux. Stop and tell me.

## Step 5 — Test the watchdog (safe — does nothing if everything's running)

Start the watchdog manually. Right now Mosquitto, Z2M, and HA are all running, so the watchdog should simply log "started" and then go quiet.

```bash
nohup bash ~/watchdog-loop.sh > ~/watchdog-loop-stdout.log 2>&1 &
disown
```

Wait 5 seconds, then check the log:

```bash
cat ~/watchdog.log
```

**Expected output:** one line like `[2026-04-27 09:50:00] Watchdog loop started`. Nothing else, because all services are alive.

Verify it's actually running in the background:

```bash
ps aux | grep watchdog-loop | grep -v grep
```

**Expected:** one line showing the watchdog-loop.sh process.

## Step 6 — Verify watchdog actually works (the meaningful test)

Now we deliberately kill Mosquitto and watch the watchdog catch it. The next watchdog cycle is up to 5 minutes away, so we need to wait OR we run it manually for an immediate test.

**Option A — patient (waits ~5 min):**

```bash
proot-distro login ubuntu -- pkill mosquitto
```

Then wait up to 5 minutes. Eventually:

```bash
cat ~/watchdog.log
```

You should see a new line like `[timestamp] Mosquitto DOWN - restarting`. And:

```bash
proot-distro login ubuntu -- pgrep mosquitto
```

Should show a process ID — Mosquitto is back.

**Option B — quick (runs once now):**

The current watchdog is in a `while sleep 300` loop, so we can't easily ask it to run "now". Instead, run a one-shot version manually to verify the logic:

```bash
proot-distro login ubuntu -- pkill mosquitto

# Verify it's dead
proot-distro login ubuntu -- pgrep mosquitto || echo "DEAD"

# Manually trigger one watchdog cycle
proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf -d'

# Verify it's back
sleep 3
proot-distro login ubuntu -- pgrep mosquitto && echo "BACK"
```

This proves the manual restart command works. The watchdog uses the same command, so if this works, the watchdog logic works too.

I recommend **Option A** — it's the realistic test. Just verify in 5 minutes.

## Don't reboot yet

After Step 6 confirms the watchdog catches and recovers a dead service, we'll have proven:
- Helper script works ✓
- Watchdog runs ✓
- Watchdog detects and recovers crashes ✓

What we *haven't* tested yet is the **full boot script flow at boot time** — but we can simulate that without rebooting. That's Step 7.

---

Run Steps 4 and 5 first. Send me the outputs of:

1. `bash ~/wait-slzb-ready.sh`
2. `cat ~/watchdog.log`
3. `ps aux | grep watchdog-loop | grep -v grep`

If those all look good, do Step 6 Option A and wait 5 minutes for the watchdog to catch the killed Mosquitto.