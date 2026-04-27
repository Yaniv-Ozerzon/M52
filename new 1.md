Good, I have everything I need. Reading the screenshot:

**Processes:**
- `mosquitto -c /etc/mosquitto/mosquitto.conf -d` ✓
- `node index.js` (the Z2M one, with 1.0% CPU, 81MB RAM — healthy) ✓
- A second `sh -c node index.js` — that's the parent shell, normal

So Mosquitto + Z2M are running. Good starting state.

**Boot directory:**
- `start-smarthome.s` — looks like a truncated/duplicate file
- `start-smarthome.sh` — the real one

There are **two files** with similar names in `~/.termux/boot/`. Both will execute on boot. That's a small mess we should clean up.

## Step 1 — Investigate the duplicate

```bash
ls -la ~/.termux/boot/
```

This shows full names and sizes. I want to see if `start-smarthome.s` is actually a separate file or a partial that needs removing.

```bash
cat ~/.termux/boot/start-smarthome.s 2>/dev/null | head -5
echo "---"
cat ~/.termux/boot/start-smarthome.sh | head -5
```

Send me the output. If both files exist with content, we'll consolidate. If `start-smarthome.s` is empty or accidental, we'll delete it.

## Step 2 — Back up what's there now

Once we see the situation, we back up before changing anything:

```bash
mkdir -p ~/script-backups
cp -r ~/.termux/boot ~/script-backups/boot-$(date +%Y%m%d_%H%M)
```

This way if the new scripts misbehave, you can restore the current ones.

## After that

Once I see the `ls -la` and `cat` outputs, I'll write you three files:

1. **`~/wait-slzb-ready.sh`** — checks the SLZB-06 is reachable AND the Zigbee TCP port is open
2. **`~/.termux/boot/start-smarthome.sh`** — replaces the existing one; uses the helper, retries Z2M up to 3 times if it crashes
3. **`~/watchdog-loop.sh`** — checks every 5 minutes, restarts dead services. Started by the boot script.

The whole thing will be one paste session — no back-and-forth. Then we test it once manually before the real reboot test.

Send me the outputs of `ls -la` and the two `cat` commands.