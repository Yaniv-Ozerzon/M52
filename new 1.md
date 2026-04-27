אבדוק את ההיסטוריה כדי להבין על מה דיברנו.מצאתי את ההקשר. נמשיך מהמקום שעצרנו - בנינו את מערכת ה-watchdog והסקריפטים. עכשיו הצילומים מראים בעיה אמיתית שצריך לפתור.

תן לי לקרוא את הצילומים בעיון:

## מה אני רואה בצילומים

**צילום 1** - boot-startup.log מראה שהמערכת עלתה תקין:
- Mon Apr 27 14:44:35 - Boot startup
- Network wait done 14:45:20
- SLZB-06 ready after 1s ✓
- Mosquitto, Z2M, Home Assistant הופעלו
- Watchdog loop התחיל
- Boot script finished 14:46:17

**צילום 2** - watchdog.log מראה **בעיה רצינית**:
```
Mosquitto DOWN - restarting   (מספר פעמים)
Zigbee2MQTT DOWN - restarting (מספר פעמים)
```

יש לולאת קריסות - השירותים נופלים שוב ושוב כל כמה דקות. זה לא תקין.

**צילום 3** - z2m-boot.log חושף את **שורש הבעיה**:
```
[11:45:56] info: z2m: Connecting to MQTT server at mqtt://localhost:1883
[11:45:57] error: z2m: MQTT failed to connect, exiting... ()
[11:45:57] info: z2m: Stopping zigbee-herdsman...
```

## האבחנה

**Z2M לא מצליח להתחבר ל-Mosquitto** - וזו הסיבה שהוא קורס. אבל למה?

תראה את הסדר ב-watchdog.log:
```
14:46:30 Zigbee2MQTT DOWN - restarting
14:52:01 Mosquitto DOWN - restarting
14:52:09 Zigbee2MQTT DOWN - restarting
```

יש כאן **race condition קלאסי**:
1. ה-watchdog מנסה להפעיל את Z2M
2. Mosquitto עצמו לא רץ באותו רגע (או עדיין מתאתחל)
3. Z2M ניסה להתחבר ל-`mqtt://localhost:1883`, נכשל, יצא
4. ה-watchdog רואה ש-Z2M מת, מנסה שוב - שוב נכשל

בנוסף - שים לב לפער הזמנים: 11:45:56 ב-z2m-boot.log לעומת 14:xx ב-watchdog.log. כלומר הבעיה הזו קיימת כבר מהבוקר ולא רק מההפעלה האחרונה.

## הפתרון - שתי בעיות לתקן

### בעיה 1: ה-watchdog לא בודק ש-Mosquitto עלה לפני שמפעיל Z2M

בסקריפט הנוכחי, הבדיקות הן עצמאיות. אנחנו צריכים שהפעלת Z2M תחכה ש-Mosquitto באמת מקבל חיבורים.

### בעיה 2: כש-Mosquitto נופל, Z2M שמחובר אליו קורס - וזה בסדר - אבל ה-watchdog צריך להפעיל אותם בסדר הנכון

בוא נשפר את `~/watchdog-loop.sh`. עדכן אותו כך:

```bash
nano ~/watchdog-loop.sh
```

מחק הכל והדבק:

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
    proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf -d' >> "$LOGFILE" 2>&1
    MOSQ_RESTARTED=1
    if wait_for_mosquitto; then
      log "Mosquitto accepting connections on 1883"
    else
      log "WARNING: Mosquitto restarted but port 1883 not responding after 30s"
    fi
  fi

  # --- Zigbee2MQTT (after Mosquitto is confirmed up) ---
  # If Mosquitto was just restarted, force Z2M restart too (its connection is dead)
  Z2M_ALIVE=0
  if proot-distro login ubuntu -- pgrep -f "node.*index.js" >/dev/null 2>&1; then
    Z2M_ALIVE=1
  fi

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

**מה השתנה:**
1. **בודק את Mosquitto קודם** - תמיד, לפני Z2M
2. **`wait_for_mosquitto`** - ממתין שהפורט 1883 באמת מקבל חיבורי TCP, לא רק שהתהליך קיים
3. **כש-Mosquitto הופעל מחדש - הורג גם את Z2M** - כי החיבור שלו עכשיו "מת" וצריך להתחבר מחדש
4. **סדר תלויות נכון** - Mosquitto → Z2M → HA

## איך להפעיל את התיקון

ה-watchdog הנוכחי עדיין רץ. צריך להרוג אותו ולהפעיל את החדש:

```bash
# מצא את ה-PID של הלולאה
pgrep -f watchdog-loop.sh
```

אם מצאת PID:
```bash
pkill -f watchdog-loop.sh
```

ואז הפעל מחדש:
```bash
nohup bash ~/watchdog-loop.sh > /dev/null 2>&1 &
disown
```

## בדיקה אחרי 5-10 דקות

```bash
tail -20 ~/watchdog.log
```

אתה אמור לראות יותר שקט - או לכל היותר הפעלה אחת של Mosquitto+Z2M ביחד, לא לולאה אינסופית.

תרוץ את התיקון, ואחרי 10-15 דקות תשלח לי את ה-`tail` של watchdog.log ונראה אם נפתרה הבעיה. אם Mosquitto עדיין נופל בקצב הזה - יש בעיה אחרת (הגדרות, דיסק, RAM) שצריך לחקור.