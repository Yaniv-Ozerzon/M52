Now we have a clear answer. The Z2M log shows the real problem:

```
z2m: Not connected to MQTT server!
z2m: MQTT error:
```

**Z2M can't reach Mosquitto.** Every 9 seconds it tries to connect, fails, and tries again. The sensor isn't the problem — the sensor's data has nowhere to go because the MQTT broker that should be relaying it to HA isn't responding.

This explains everything: HA shows the sensor as "unavailable" because no MQTT messages are flowing. Z2M is publishing into the void.

## What likely happened

After the recent restart sequence (HA restart, possibly the phone reboot), **Mosquitto didn't come back up.** Or it crashed. Z2M and HA each manage their own MQTT connections, so they reconnect independently — but if the broker itself is down, neither can connect.

## Step 1 — Check if Mosquitto is running

In Termux, enter the Debian container:

```bash
proot-distro login ubuntu
```

Then check:

```bash
ps aux | grep mosquitto | grep -v grep
```

**Expected output:** one line showing `mosquitto -c /etc/mosquitto/mosquitto.conf -d`

**If output is empty** — Mosquitto is dead. That's the cause.

## Step 2 — Start Mosquitto

If it's not running:

```bash
mosquitto -c /etc/mosquitto/mosquitto.conf -d
```

Then verify:

```bash
ps aux | grep mosquitto | grep -v grep
```

You should see one Mosquitto process now.

Quick auth test to make sure it works:

```bash
mosquitto_pub -h localhost -u ozerzon -P 'Passmein@1' -t test -m hello && echo OK || echo FAILED
```

You should see `OK`.

## Step 3 — Watch Z2M reconnect

Switch to your browser tab with the Z2M log page. Within 10 seconds of Mosquitto starting, you should see:

```
info: z2m: Connected to MQTT server
info: z2m: ... (normal operation messages)
```

The red errors will stop appearing.

## Step 4 — HA reconnects automatically

HA polls MQTT every few seconds. Within 30 seconds of Mosquitto being back, your sensor's "unavailable" state should resolve to either "Wet" or "Dry" — assuming the sensor has reported anything in the meantime.

If the sensor still shows "Unavailable" after Mosquitto is back: touch a wet finger to it. The sensor publishes a state change → Mosquitto relays it → HA picks it up.

## Why this matters for your auto-start setup

This tells us your boot script almost certainly didn't actually launch Mosquitto on the last boot — same bug as before, or a regression. After we get this working again, we should look at the boot script behavior, because if Mosquitto dies again it'll keep happening.

For right now: just get Mosquitto back up. Run Step 1 first and tell me what the `ps aux` shows.