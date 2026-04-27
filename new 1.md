Now I can see exactly what happened. The error is specific and well-documented.

## What killed Z2M

Read these key lines from your screenshots:

**Image 1:**
- `EZSP started ✓` — Z2M connected to the SLZB-06 successfully
- `Adapter version info: ... build:397, type:170 ✓` — handshake OK
- `[STACK STATUS] Network up. ✓`
- `zh:ember: [EzspConfigId]` — starting to configure

**Image 2:**
- `tatus=INVALID_STATE. Firmware value will be used instead`
- **`error: z2m: Error: [INIT TC] Failed network init request with status=INVALID_STATE`**
- `Error while starting zigbee-herdsman`
- `Failed to start zigbee-herdsman`
- `Exiting...`

So Z2M reached the SLZB-06, started initializing the Zigbee network on it, and got `INVALID_STATE` from the EmberZNet firmware. Z2M correctly bails out rather than corrupting your Zigbee network.

## What `INVALID_STATE` means here

This is a known issue specific to the SLZB-06 + EmberZNet adapter that happens when **Z2M starts before the SLZB-06 is fully ready**. The SLZB-06 is on Ethernet — when the phone reboots, the SLZB-06 isn't necessarily reset. But your boot script's TCP connection to the SLZB-06 raced ahead of the SLZB-06's internal state being clean.

The "INVALID_STATE" specifically means the Zigbee network coordinator on the SLZB-06 is in a state Z2M can't safely initialize from. The Z2M docs explicitly link to a troubleshooting page for this in the error itself: `https://www.zigbee2mqtt.io/guide/installation/20_zigbee2mqtt-fails-to-start_crashes-runtime.html`

## Three fixes, in order of preference

### Fix 1 (try first) — Reboot the SLZB-06

This clears its internal state. From any browser, go to `http://192.168.1.126`, scroll to the bottom of the dashboard, click **Reboot**. Wait 30 seconds for it to come back.

Then start Z2M manually and see if it works:

```bash
proot-distro login ubuntu
pgrep mosquitto >/dev/null || mosquitto -c /etc/mosquitto/mosquitto.conf -d
sleep 3
cd /opt/zigbee2mqtt
npm start
```

(Run in foreground first so we can see any error.)

If it now logs `Started Zigbee2MQTT` cleanly → SLZB-06 reboot fixed it. Then Ctrl+C, restart it as a background process:

```bash
nohup npm start > /tmp/z2m.log 2>&1 &
disown
```

### Fix 2 — Add a longer wait + SLZB-06 health check to the boot script

The real fix is making the boot script wait until the SLZB-06's TCP socket is actually ready and not stuck in some half-state. Once Fix 1 confirms manual start works, we'll modify `~/.termux/boot/start-smarthome.sh` to wait for the SLZB-06 to respond cleanly before launching Z2M.

I want to do this in a follow-up — let's first confirm Fix 1 actually solves your immediate problem.

### Fix 3 (only if Fixes 1 and 2 fail) — Restore Z2M from coordinator backup

Z2M keeps a `coordinator_backup.json` from the last successful run. If the network state in that file matches the SLZB-06's state, restart works clean. If they've diverged (e.g., from previous failed attempts), the backup can fix it. This is a more invasive recovery and we'd only do it if the easier fixes don't work.

---

## Do this now

1. Open `http://192.168.1.126` in your browser
2. Scroll to the bottom, click **Reboot**
3. Wait 30 seconds
4. In Termux, run the four commands from Fix 1 above
5. Watch the `npm start` output in your terminal

Tell me what you see. Specifically: does Z2M now log `Started Zigbee2MQTT`, or does it still crash with `INVALID_STATE`?

If it works → great, run the `nohup` background restart, verify `http://192.168.1.125:8080` loads, and then we'll tackle the boot script's race condition.

If it crashes with the same error → screenshot it, we'll go to Fix 3.

























So the boot script started HA but didn't successfully start Z2M. That tells us specifically that the proot-launching part of the script isn't working as intended after a real reboot.

Let me get diagnostics first, then we'll fix what's actually wrong.

## Step 1 — Check the boot logs

In Termux (regular Termux, `~ $` prompt):

```bash
echo "=== boot-startup.log ==="
cat ~/boot-startup.log

echo ""
echo "=== z2m-boot.log (last 30 lines) ==="
tail -30 ~/z2m-boot.log

echo ""
echo "=== Processes inside Debian ==="
proot-distro login ubuntu -- bash -c "ps aux | grep -E 'mosquitto|node' | grep -v grep"

echo ""
echo "=== Z2M frontend port check ==="
proot-distro login ubuntu -- bash -c "ss -tln 2>/dev/null | grep 8080 || echo 'Nothing listening on 8080'"
```

Send me the output of all of that. Each section tells us something specific:

- `boot-startup.log` — did the boot script reach all 4 timestamped milestones?
- `z2m-boot.log` — what did Z2M actually print when it tried to start? This is the critical one.
- The process check — what's running inside Debian *right now*?
- The port check — is anything listening on 8080?

## Most likely causes (so you have context)

Based on past patterns in our session, the failure is likely one of:

1. **Mosquitto didn't start in time before Z2M tried to connect** — Z2M crashes within seconds of starting because MQTT auth fails
2. **The proot-distro login from boot didn't actually launch Z2M inside Debian** — same bug shape we hit before
3. **Z2M started but crashed on a Zigbee adapter timing issue** — the SLZB-06 wasn't fully reachable yet when Z2M tried to connect
4. **The 60-second sleep between Z2M start and HA start was off** — should be benign but worth checking

I don't want to guess. The logs will tell us.

## Quick fix to get you running NOW (parallel to diagnostics)

While we figure out the boot script, manually start Z2M so you have a working setup right now:

```bash
proot-distro login ubuntu
```

(Wait for `root@localhost:~#` prompt)

```bash
pgrep mosquitto >/dev/null || mosquitto -c /etc/mosquitto/mosquitto.conf -d
sleep 3
cd /opt/zigbee2mqtt
nohup npm start > /tmp/z2m.log 2>&1 &
disown
```

Wait 60 seconds, then check `http://192.168.1.125:8080` — should load.

Then `exit` to leave Debian.

This gets you working immediately. Then send me the diagnostic output from Step 1 and we'll fix the boot script properly so you don't have to do this manually next reboot.