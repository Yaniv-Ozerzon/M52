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