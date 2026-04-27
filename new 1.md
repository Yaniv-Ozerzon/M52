Let's get Z2M running manually. Step by step. I'll keep it minimal so we can see exactly what fails if anything does.

## Step 1 — Check what's already running

In Termux (regular Termux, `~ $` prompt):

```bash
proot-distro login ubuntu -- bash -c "ps aux | grep -E 'mosquitto|node' | grep -v grep"
```

Send me the output, but you can keep going while waiting for me. The output will tell us:
- If Mosquitto is running (we want this to be running)
- If Z2M is running (probably not, since 8080 is down)

## Step 2 — Reboot the SLZB-06 (clears INVALID_STATE risk)

In your browser: `http://192.168.1.126` → scroll to **Reboot** button → click it. **Wait 45 seconds** before continuing. This is the same step that fixed it last time after a phone reboot.

## Step 3 — Enter the Debian container

In Termux:

```bash
proot-distro login ubuntu
```

Wait for the prompt to change to `root@localhost:~#`. From here on, everything runs **inside Debian**.

## Step 4 — Make sure Mosquitto is running

```bash
pgrep mosquitto >/dev/null && echo "Mosquitto running" || echo "Mosquitto DOWN"
```

If it says "Mosquitto running" → skip to Step 5.

If it says "Mosquitto DOWN" → start it:

```bash
mosquitto -c /etc/mosquitto/mosquitto.conf -d
sleep 3
pgrep mosquitto && echo "Mosquitto started"
```

You should see a process ID and "Mosquitto started".

If it doesn't start cleanly, run it in foreground to see the error:
```bash
mosquitto -c /etc/mosquitto/mosquitto.conf
```
And send me what it prints.

## Step 5 — Start Z2M in the foreground first

We start in foreground so we can see immediately if it crashes (INVALID_STATE etc.):

```bash
cd /opt/zigbee2mqtt
npm start
```

Watch the log scroll. You're looking for:

**Success markers:**
```
info: zh:ember: ======== EZSP started ========
info: zh:ember: [STACK STATUS] Network up.
info: z2m: zigbee-herdsman started (resumed)
info: z2m: Connected to MQTT server
info: z2m: Started Zigbee2MQTT
```

If you see "Started Zigbee2MQTT" — Z2M is running. **Don't Ctrl+C.** Continue to Step 6.

**Failure markers:**
- `INVALID_STATE` → SLZB-06 needs reboot again, repeat Step 2 with a longer wait
- `MQTT failed to connect` → Mosquitto issue, redo Step 4
- Anything else → screenshot and send

## Step 6 — Verify the frontend works

While Z2M runs in foreground, open `http://192.168.1.125:8080` in a browser. The dashboard should load.

If it loads → Z2M is fully working. Continue to Step 7.

## Step 7 — Move Z2M to background so it survives Termux closing

In the Termux session running Z2M, press **Ctrl+C** to stop it. Then:

```bash
nohup npm start > /tmp/z2m.log 2>&1 &
disown
```

(You should still be inside Debian and in `/opt/zigbee2mqtt` from Step 5.)

Verify it's running:

```bash
sleep 30
pgrep -f "node.*index" && echo "Z2M backgrounded successfully"
```

Should see a PID and "Z2M backgrounded successfully".

Reload `http://192.168.1.125:8080` in browser — should still work.

## Step 8 — Exit Debian

```bash
exit
```

You're back in regular Termux. Z2M and Mosquitto keep running because they were properly backgrounded.

---

Start with Step 1 — send me what's running. Don't go further until I see the output and confirm. If Mosquitto is dead, we'll handle that before touching Z2M.