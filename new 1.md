Good — now I understand your full state. Let me consolidate everything I know before writing steps:

**What you have:**
- Phone running HA Core at `http://<phone-ip>:8123` with user `Ozerzon`
- Debian container installed, aliased as `ubuntu`
- SLZB-06Mg24U at `192.168.1.126`, Ethernet, Zigbee coordinator mode, firmware `20250212` / core `v3.1.6.dev1`
- The SMLIGHT SLZB integration is already added to HA — that's what gives you the device page in your screenshot
- Mosquitto and Zigbee2MQTT: not installed yet
- Router: `192.168.1.1`, username convention: `ozerzon`

**Important new consideration from your screenshot:** The SMLIGHT HA integration you've added only provides *monitoring* (temperature, firmware status, reboot button) — it does **not** make the SLZB-06 control Zigbee devices. That's fine to leave in place; it doesn't conflict with Z2M. But it also means you still need Z2M to actually do anything with Zigbee devices.

One thing to verify before we start: your dashboard earlier showed "Socket connected: Yes, 1 client." Since we now know the SMLIGHT HA integration is the only thing attached, that's almost certainly it — and it uses a *different* socket than Zigbee2MQTT's `6638`. So we should be fine. If Z2M fails to connect later we'll revisit it.

Now the full sequence.

---

## Step 1 — Verify SLZB-06 is in the right mode

In a browser on your PC, open `http://192.168.1.126` and click **Z2M and ZHA** in the left sidebar.

Confirm or set:
- Mode: **Zigbee2MQTT**
- TCP port: **6638**

If you change anything, save and reboot the SLZB-06 via the **Reboot** button. Send me a screenshot of this tab if you're unsure what you're looking at.

## Step 2 — Reserve the SLZB-06 IP in your router

Open `http://192.168.1.1`, find the DHCP/client list, locate `80:B5:4E:57:74:1C` (the SLZB-06's MAC — we can see it in your HA screenshot), and reserve `192.168.1.126` to that MAC. This prevents the IP changing after a router reboot, which would break Z2M.

## Step 3 — In Termux: wake lock and enter Debian

```bash
termux-wake-lock
proot-distro login ubuntu
```

Your prompt becomes `root@localhost:~#`. You're **inside Debian**. Every command from Step 4 through Step 12 runs inside the container.

## Step 4 — Install Mosquitto

```bash
apt update
apt install -y mosquitto mosquitto-clients
```

## Step 5 — Create the Mosquitto user `ozerzon`

```bash
mosquitto_passwd -c /etc/mosquitto/passwd ozerzon
```

It prompts twice for a password. **Write it down** — you'll use it in Step 9 (Z2M config) and Step 13 (HA MQTT integration).

## Step 6 — Configure Mosquitto

```bash
nano /etc/mosquitto/mosquitto.conf
```

Go to the bottom of the file (hold Down arrow). Add these five lines:

```
listener 1883 0.0.0.0
allow_anonymous false
password_file /etc/mosquitto/passwd
persistence true
persistence_location /var/lib/mosquitto/
```

Save: `Ctrl+O`, Enter, `Ctrl+X`.

## Step 7 — Start Mosquitto and test it

```bash
mosquitto -c /etc/mosquitto/mosquitto.conf -d
ps aux | grep mosquitto
```

You should see a `mosquitto` process. Quick functional test (replace `YOUR_PASSWORD` with what you set in Step 5):

```bash
mosquitto_sub -h localhost -u ozerzon -P Passmein@1 -t test &
mosquitto_pub -h localhost -u ozerzon -P Passmien@1 -t test -m "hello"
```

You should see `hello` print. Then:

```bash
kill %1
```

to stop the background subscriber.

## Step 8 — Install Node.js 20

```bash
apt install -y curl git make g++ gcc ca-certificates
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
node --version
```

Must print `v20.x.x`. If it doesn't, stop and tell me.

## Step 9 — Install Zigbee2MQTT

```bash
mkdir -p /opt/zigbee2mqtt
git clone --depth 1 https://github.com/Koenkk/zigbee2mqtt.git /opt/zigbee2mqtt
cd /opt/zigbee2mqtt
npm ci
```

`npm ci` takes 5–20 minutes on a phone. Don't close Termux. When it finishes you get your prompt back with no error.

## Step 10 — Configure Zigbee2MQTT with your specific values

```bash
nano /opt/zigbee2mqtt/data/configuration.yaml
```

Select all existing content and delete it (in nano: `Ctrl+K` repeatedly deletes line-by-line). Paste the block below exactly, then **change only the password line** (replace `YOUR_MOSQUITTO_PASSWORD` with what you set in Step 5):

```yaml
homeassistant: true
permit_join: false

mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://localhost:1883
  user: ozerzon
  password: Passmien@1

serial:
  port: tcp://192.168.1.126:6638
  adapter: ember

advanced:
  network_key: GENERATE
  pan_id: GENERATE
  ext_pan_id: GENERATE
  log_level: info

frontend:
  port: 8080
  host: 0.0.0.0
```

Notes on what's pre-filled for your setup:
- `tcp://192.168.1.126:6638` — your SLZB-06 IP and socket port, from your dashboard
- `adapter: ember` — correct for SLZB-06**Mg24** (Silicon Labs EFR32MG24 chip). Do not change this
- `user: ozerzon` — matches what you created in Step 5

Save: `Ctrl+O`, Enter, `Ctrl+X`.

## Step 11 — Test Z2M manually

```bash
cd /opt/zigbee2mqtt
npm start
```

Watch the output. Success looks like:

```
Starting Zigbee2MQTT ...
Connected to MQTT server
Adapter: ember, firmware: ...
Coordinator firmware version: ...
Started Zigbee2MQTT
```

If you see that, **stop it with Ctrl+C**. We're just verifying the stack works before setting up auto-start.

If it fails, common causes:
- `Failed to connect to the adapter` → another client still has the SLZB-06 socket. Go to `http://192.168.1.126`, Dashboard tab — if "Socket connected" shows a client, hit **Reboot** on the SLZB-06 and retry
- `MQTT error: not authorized` → password mismatch between Step 5 and Step 10
- `MQTT error: connection refused` → Mosquitto isn't running; redo Step 7

Tell me the exact error if any of these — don't guess.

## Step 12 — Exit the container

```bash
exit
```

You're back in regular Termux.

## Step 13 — Add MQTT integration in Home Assistant

On your PC, open HA at `http://<phone-ip>:8123`.

1. **Settings → Devices & Services → + Add Integration**
2. Search **MQTT**, select it
3. Broker: `localhost`
4. Port: `1883`
5. Username: `ozerzon`
6. Password: (from Step 5)
7. Submit — it should say "Success"

## Step 14 — Create the launcher script

In regular Termux (not inside Debian):

```bash
cat > ~/start-zigbee.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
proot-distro login ubuntu -- bash -c "
  pgrep mosquitto >/dev/null || mosquitto -c /etc/mosquitto/mosquitto.conf -d
  sleep 2
  cd /opt/zigbee2mqtt && npm start
"
EOF
chmod +x ~/start-zigbee.sh
```

## Step 15 — Running the full stack

You need two Termux sessions. Swipe from the left edge in Termux to open the session drawer, tap "New Session".

**Session 1 — HA:**
```bash
bash ~/start-homeassistant.sh
```

**Session 2 — Mosquitto + Z2M:**
```bash
bash ~/start-zigbee.sh
```

Both need to be running for Zigbee devices to work.

## Step 16 — Pair your first Zigbee device

On your PC, open **`http://<phone-ip>:8080`** — the Z2M frontend.

1. Click **Permit join (All)** at the top — opens a 4-minute window
2. Put your Zigbee device into pairing mode (usually hold its button ~5 seconds; varies by device)
3. The device appears in Z2M's device list and automatically shows up in HA under **Settings → Devices & Services → MQTT** thanks to `homeassistant: true`
4. Turn off "Permit join" when done — security best practice

---

## Things to watch

**About the existing SMLIGHT integration in HA:** It'll keep working independently alongside Z2M. The two don't conflict because they use separate communication channels — SMLIGHT uses HTTP polling, Z2M uses the Zigbee TCP socket. You'll end up with one device card for the coordinator (from SMLIGHT) plus device cards for each paired Zigbee device (from Z2M via MQTT). That's the correct setup.

**About the "Core firmware / Zigbee firmware — update available" prompts** in your HA screenshot: don't update either right now. Let's get Z2M connected on the current firmware first. Firmware updates during setup are a reliable way to brick things mid-process.

**About persistence:** Android's battery management can still kill Termux. Go to **Settings → Apps → Termux → Battery** on your phone and set it to **Unrestricted**. This significantly reduces but doesn't eliminate the chance of the OS killing your sessions.

Start with Step 1 — verify the SLZB-06 mode — and let me know what it shows. Don't run Step 3 onward until I've confirmed Step 1 looks right.