Smart — back up while everything is working. Let me do this properly given what we've built.

## What we're backing up

| Item | Location | Why |
|---|---|---|
| HA config | `~/hass-config/` (Termux) | Dashboards, MQTT integration, automations, all settings |
| Z2M data | `/opt/zigbee2mqtt/data/` (Debian) | **Critical** — Zigbee network keys, paired devices, settings. Lose this = re-pair every device |
| Mosquitto password | `/etc/mosquitto/passwd` (Debian) | Trivial to recreate but saves a step |
| Z2M config | `/opt/zigbee2mqtt/data/configuration.yaml` (Debian) | Already inside Z2M data, but a separate copy makes inspection easier |
| Boot script | `~/.termux/boot/start-smarthome.sh` (Termux) | Your auto-start logic |
| HA start script | `~/start-homeassistant.sh` (Termux) | The HA launcher |

## Step 1 — Grant Termux access to phone storage (one-time)

In **regular Termux** (`~ $` prompt — open a new session, don't use the one running services):

```bash
termux-setup-storage
```

An Android permission dialog pops up — tap **Allow**. This creates `~/storage/shared/` linked to your phone's main storage so backups land somewhere accessible from outside Termux.

If it says "already granted," that's fine — skip ahead.

## Step 2 — Create the backup script

```bash
nano ~/backup-smarthome.sh
```

Paste this:

```bash
#!/data/data/com.termux/files/usr/bin/bash
set -u

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=~/storage/shared/SmartHomeBackups
mkdir -p "$BACKUP_DIR"

# Path to the Debian rootfs as seen from Termux
DEBIAN_ROOT=/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian

echo "=== Backup started at $(date) ==="
echo "Saving to: $BACKUP_DIR"
echo ""

# 1. Home Assistant config
echo "[1/5] Home Assistant config..."
tar -czf "$BACKUP_DIR/ha-config_$DATE.tar.gz" -C ~ hass-config 2>/dev/null \
  && echo "    OK: $(du -h "$BACKUP_DIR/ha-config_$DATE.tar.gz" | cut -f1)" \
  || echo "    FAILED"

# 2. Zigbee2MQTT data (the critical one)
echo "[2/5] Zigbee2MQTT data..."
tar -czf "$BACKUP_DIR/z2m-data_$DATE.tar.gz" -C "$DEBIAN_ROOT/opt/zigbee2mqtt" data 2>/dev/null \
  && echo "    OK: $(du -h "$BACKUP_DIR/z2m-data_$DATE.tar.gz" | cut -f1)" \
  || echo "    FAILED"

# 3. Mosquitto password file
echo "[3/5] Mosquitto password..."
cp "$DEBIAN_ROOT/etc/mosquitto/passwd" "$BACKUP_DIR/mosquitto-passwd_$DATE" 2>/dev/null \
  && echo "    OK" \
  || echo "    FAILED"

# 4. Z2M configuration (separate readable copy)
echo "[4/5] Z2M configuration.yaml..."
cp "$DEBIAN_ROOT/opt/zigbee2mqtt/data/configuration.yaml" "$BACKUP_DIR/z2m-config_$DATE.yaml" 2>/dev/null \
  && echo "    OK" \
  || echo "    FAILED"

# 5. Termux scripts (boot script + HA launcher)
echo "[5/5] Termux scripts..."
tar -czf "$BACKUP_DIR/termux-scripts_$DATE.tar.gz" \
  -C ~ start-homeassistant.sh stop-homeassistant.sh .termux/boot 2>/dev/null \
  && echo "    OK" \
  || echo "    FAILED (some files may not exist)"

echo ""
echo "=== Backup complete at $(date) ==="
echo ""
echo "Files in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR" | grep "$DATE"
echo ""
echo "Total backup size:"
du -sh "$BACKUP_DIR" | cut -f1
```

Save: `Ctrl+O`, Enter, `Ctrl+X`. Make it executable:

```bash
chmod +x ~/backup-smarthome.sh
```

## Step 3 — Run it

```bash
bash ~/backup-smarthome.sh
```

You should see five lines each ending with `OK`. Total runtime: 5–30 seconds depending on how big your HA config has grown. Most of the size is the HA tar (Python venv files don't get backed up — they're in `~/hass-venv`, which is reinstallable).

## Step 4 — Verify the files are accessible from outside Termux

The backup files are at `/sdcard/SmartHomeBackups/` from any file manager's perspective. To verify on the phone:

Open the Files app or any file manager → Internal storage → SmartHomeBackups. You should see:
- `ha-config_YYYYMMDD_HHMMSS.tar.gz`
- `z2m-data_YYYYMMDD_HHMMSS.tar.gz`
- `mosquitto-passwd_YYYYMMDD_HHMMSS`
- `z2m-config_YYYYMMDD_HHMMSS.yaml`
- `termux-scripts_YYYYMMDD_HHMMSS.tar.gz`

## Step 5 — Get the backup OFF the phone (the most important step)

A backup that only exists on the phone is not a real backup. Pick at least one:

- **USB to PC**: plug in, copy the entire `SmartHomeBackups` folder to your computer
- **Cloud**: open Google Drive / Dropbox / OneDrive app on phone → upload the folder
- **Email**: select all 5 files in your file manager → Share → Email to yourself
- **Network**: if you have a NAS or another computer on your network, copy via SMB/SFTP

Honestly, do at least two of these. The Z2M data tar is the irreplaceable one — losing it means re-pairing every Zigbee device you ever add to the system.

## Going forward — when to back up

I'd run the backup script:
- After pairing a meaningful number of new devices
- Before any system update or experiment
- On a regular monthly schedule

If you want it to back up automatically, we can add a cron-like scheduler later — but honestly, manual backups before changes are usually enough for a hobby setup. Let's get the first one done first.

## Honest caveat I want to flag

The Z2M backup catches the data files, but if you ever do a full restore on a different phone (or after a factory reset), the **Zigbee network key** will only work with **the same SLZB-06**. If you replace the SLZB-06 hardware, you'd need to re-pair devices regardless. The backup protects you from software disasters, not hardware replacement.

Run the script and send me a screenshot of the output. If all five say "OK," we're done with backup setup.