מצוין! עובד! 🎉

## מה רואים

```
pgrep mosquitto
25181
25375
OPEN
```

Mosquitto רץ עם 2 PIDs (זה תקין - אחד ראשי ואחד של ה-listener) ופורט 1883 פתוח. הפלט `[1]+ Done` הוא פשוט הודעה שה-job הקודם של `tee` הסתיים, זה לא רלוונטי.

**אנחנו יכולים לסמוך על זה - Mosquitto יציב כשמפעילים אותו בלי `-d`.**

## עכשיו - לתקן את הסקריפטים פעם אחת ולתמיד

יש לנו שני סקריפטים שצריך לעדכן: `start-smarthome.sh` ו-`watchdog-loop.sh`. בואו נטפל בהם.

### שלב 1: לעדכן את watchdog-loop.sh

```bash
nano ~/watchdog-loop.sh
```

מחק הכל (החזק את החץ למטה עד הסוף, ואז `Ctrl+K` עד שהקובץ ריק) והדבק:

```bash
#!/data/data/com.termux/files/usr/bin/bash
# Watchdog: checks Mosquitto, Z2M, and HA every 5 minutes
# Restarts whatever's dead, in correct dependency order
# Logs to ~/watchdog.log

LOGFILE=~/watchdog.log

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

# Wait for Mosquitto to actually accept connections on port 1883
wait_for_mosquitto() {
  local max=30
  local i=0
  while [ $i -lt $max ]; do
    if proot-distro login ubuntu -- bash -c 'echo > /dev/tcp/localhost/1883' 2>/dev/null; then
      return 0
    fi
    sleep 1
    i=$((i+1))
  done
  return 1
}

log "Watchdog loop started"

while true; do

  # --- Mosquitto FIRST (Z2M depends on it) ---
  MOSQ_RESTARTED=0
  if ! proot-distro login ubuntu -- pgrep mosquitto >/dev/null 2>&1; then
    log "Mosquitto DOWN - restarting"
    nohup proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf' >> ~/mosquitto.log 2>&1 &
    disown
    MOSQ_RESTARTED=1
    if wait_for_mosquitto; then
      log "Mosquitto accepting connections on 1883"
    else
      log "WARNING: Mosquitto restarted but port 1883 not responding after 30s"
    fi
  fi

  # --- Zigbee2MQTT (after Mosquitto is confirmed up) ---
  Z2M_ALIVE=0
  if proot-distro login ubuntu -- pgrep -f "node.*index.js" >/dev/null 2>&1; then
    Z2M_ALIVE=1
  fi

  # If Mosquitto was just restarted, force Z2M restart too (its connection is dead)
  if [ $MOSQ_RESTARTED -eq 1 ] && [ $Z2M_ALIVE -eq 1 ]; then
    log "Mosquitto was restarted - killing stale Z2M to force reconnect"
    proot-distro login ubuntu -- pkill -f "node.*index.js" 2>/dev/null
    sleep 3
    Z2M_ALIVE=0
  fi

  if [ $Z2M_ALIVE -eq 0 ]; then
    log "Zigbee2MQTT DOWN - restarting"
    nohup proot-distro login ubuntu -- bash -c '
      cd /opt/zigbee2mqtt
      exec npm start
    ' > ~/z2m-watchdog.log 2>&1 &
    disown
    sleep 30
  fi

  # --- Home Assistant ---
  if ! pgrep -f "homeassistant" >/dev/null 2>&1; then
    log "Home Assistant DOWN - restarting"
    nohup bash ~/start-homeassistant.sh > ~/hass-watchdog.log 2>&1 &
    disown
    sleep 30
  fi

  # --- Trim log if it grows too large ---
  if [ -f "$LOGFILE" ] && [ "$(wc -l < "$LOGFILE")" -gt 1000 ]; then
    tail -500 "$LOGFILE" > "$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
  fi

  sleep 300
done
```

שמור: `Ctrl+O`, Enter, `Ctrl+X`.

ההבדל היחיד מהקודם: **שורת ההפעלה של Mosquitto** -- במקום `mosquitto -c ... -d`, עכשיו `nohup ... mosquitto -c ... &; disown`.

### שלב 2: לעדכן את start-smarthome.sh

```bash
nano ~/.termux/boot/start-smarthome.sh
```

חפש את השורה שמפעילה את Mosquitto (היא נראית בערך כך):
```bash
proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf -d'
```

החלף אותה ב:
```bash
nohup proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf' >> ~/mosquitto.log 2>&1 &
disown
sleep 5
```

שמור: `Ctrl+O`, Enter, `Ctrl+X`.

### שלב 3: עכשיו - אתחל את הטלפון

זה הזמן הנכון לאתחל. כל השירותים יעלו עם הסקריפטים המתוקנים.

### שלב 4: אחרי האתחול, חכה 10 דקות ושלח לי

```bash
tail -20 ~/watchdog.log
proot-distro login ubuntu -- pgrep mosquitto && echo MOSQ_UP || echo MOSQ_DOWN
proot-distro login ubuntu -- bash -c 'echo > /dev/tcp/localhost/1883' 2>/dev/null && echo "1883 OPEN" || echo "1883 CLOSED"
proot-distro login ubuntu -- pgrep -f "node.*index.js" && echo Z2M_UP || echo Z2M_DOWN
pgrep -f homeassistant && echo HA_UP || echo HA_DOWN
```

מה שאני מצפה לראות ב-watchdog.log: **"Watchdog loop started"** ו**שום הודעות "DOWN - restarting"**. אם הכל יציב, זה אמור להיות לוג שקט מאוד.