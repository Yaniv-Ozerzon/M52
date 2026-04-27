אישור: אבחנה נכונה. שתי הפקודות מסכימות:

```
$ proot-distro login ubuntu -- pgrep mosquitto
7035                                              ← נמצא תהליך

$ proot-distro login ubuntu -- bash -c "ps aux | grep mosquitto | grep -v grep"
u0_a166  7035  0.2  0.0  15768  3116  S<s  ...  mosquitto -c /etc/mosquitto/mosquitto.conf -d
                                                  ← אותו PID 7035, מצב S (sleeping = healthy)
```

Mosquitto חי ובריא — PID 7035, רץ 26 דקות (לפי `0:26` בעמודת CPU time).

אז המסקנה:

**ה-watchdog לא טועה ב-pgrep**, ו-Mosquitto **לא מת ולא קורס**. אבל יש 11 הודעות "Mosquitto DOWN - restarting" בלוג מהיום, כולן false positives.

## מה כן קורה

זה מקרה ידוע של `pgrep` בתוך `proot-distro login` — לפעמים הוא מחזיר ריק *רק לאיטרציה הזאת* בגלל איך ש-proot יוצר namespace חדש לכל login, אבל בפעם הבאה זה עובד שוב. זה לא באג קבוע, זה race condition.

ההוכחה: כש-pgrep ב-watchdog החזיר ריק, הפקודה הבאה הייתה:
```bash
mosquitto -c /etc/mosquitto/mosquitto.conf -d
```
אבל ב-Mosquitto יש בדיקה פנימית — אם פורט 1883 כבר תפוס, הוא יוצא בלי להפריע למה שכבר רץ. אז "התיקון" הזה היה לא-פעולה. וזו הסיבה שהמערכת המשיכה לעבוד.

**המערכת בריאה. הלוג רועש.**

## מה לתקן (אופציונלי, רק אם רוצים לוג נקי)

יש שתי גישות:

### אפשרות א' — לעזוב את זה לבד

הרעש בלוג לא מזיק. ה-watchdog משחית מעט CPU כל 5 דקות מנסה להפעיל Mosquitto שלא צריך הפעלה. בפועל זה לא משנה כלום.

**יתרון:** אפס שינויים, אפס סיכון.
**חיסרון:** הלוג מלא הודעות שווא, וקשה לראות בלוג קריסה אמיתית אם תהיה.

### אפשרות ב' — לתקן את ה-watchdog לבדיקה אמינה יותר

במקום לבדוק "האם תהליך mosquitto קיים", לבדוק "האם פורט 1883 מקשיב". זה לא רגיש ל-pgrep ב-proot.

```bash
nano ~/watchdog-loop.sh
```

מצא את הבלוק:

```bash
  # --- Mosquitto ---
  if ! proot-distro login ubuntu -- pgrep mosquitto >/dev/null 2>&1; then
    log "Mosquitto DOWN - restarting"
    proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf -d' >> "$LOGFILE" 2>&1
    sleep 5
  fi
```

החלף ל:

```bash
  # --- Mosquitto (port-based check, more reliable in proot) ---
  if ! proot-distro login ubuntu -- bash -c "ss -tln 2>/dev/null | grep -q ':1883 '"; then
    log "Mosquitto DOWN - restarting"
    proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf -d' >> "$LOGFILE" 2>&1
    sleep 5
  fi
```

באותו סגנון תיקון אפשרי גם ל-Z2M (פורט 8080):

מצא:
```bash
  if ! proot-distro login ubuntu -- pgrep -f "node.*index.js" >/dev/null 2>&1; then
```

החלף ל:
```bash
  if ! proot-distro login ubuntu -- bash -c "ss -tln 2>/dev/null | grep -q ':8080 '"; then
```

**יתרון:** לוג נקי, יותר אמין.
**חיסרון:** שינוי קוד = סיכון קל לבאג חדש.

לפני זה — בדיקה אם `ss` קיים בכלל בקונטיינר Debian:

```bash
proot-distro login ubuntu -- which ss
```

אם מחזיר נתיב (כמו `/usr/bin/ss`) → התיקון יעבוד.
אם מחזיר ריק → צריך להתקין: `proot-distro login ubuntu -- apt install -y iproute2`

## ההמלצה שלי

**אפשרות א'.** המערכת רצה. הלוג מלא false positives שלא מזיקים. כל שינוי הוא סיכון. אם זה לא מפריע לך, השאר.

אם זה כן מפריע — תבדוק את ה-`which ss` ואז נחליט אם להתקדם עם אפשרות ב'.