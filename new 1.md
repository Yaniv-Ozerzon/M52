הסקריפט הפעיל את Z2M, ה-watchdog דיווח "Z2M running after attempt 1" — אבל עכשיו אחרי הבוט הוא לא נגיש. כלומר: Z2M עלה, ואז קרס שקט. זה תבנית מוכרת לבעיית INVALID_STATE שראינו.

בוא נראה בדיוק מה קרה.

## שלב 1 — בדיקה מהירה: האם Z2M רץ עכשיו?

ב-Termux רגיל:

```bash
proot-distro login ubuntu -- bash -c "ps aux | grep -E 'mosquitto|node' | grep -v grep"
```

אני מצפה לראות:
- Mosquitto רץ ✓ (ראינו שהוא PID 7035 והוא חי)
- node index.js — **כנראה לא רץ**, וזו הבעיה

## שלב 2 — קרא את הלוג של Z2M מהבוט

הסקריפט שמר את פלט Z2M. שלוף את 30 השורות האחרונות:

```bash
proot-distro login ubuntu -- tail -30 /tmp/z2m.log 2>/dev/null
```

אם הקובץ לא קיים, נסה:

```bash
cat ~/z2m-boot.log 2>/dev/null | tail -30
```

או:

```bash
cat ~/z2m-watchdog.log 2>/dev/null | tail -30
```

תשלח לי צילום מסך של מה שמופיע. אני מצפה לאחת מהאפשרויות:

**אפשרות א' — INVALID_STATE שוב:**
```
error: z2m: Error: [INIT TC] Failed network init request with status=INVALID_STATE
error: z2m: Failed to start zigbee-herdsman
error: z2m: Exiting...
```

זה אומר שה-retry של 3 פעמים בסקריפט הבוט לא הספיק — אולי SLZB-06 לקח יותר זמן להיות מוכן ממה שחשבנו. יש פתרון.

**אפשרות ב' — שגיאת MQTT:**
```
error: z2m: MQTT failed to connect
```

אז הבעיה בסנכרון בין Mosquitto ל-Z2M.

**אפשרות ג' — Z2M רץ ובריא ב-tail:**
אז הוא מת אחרי שהלוג הסתיים, ובלי שגיאה ברורה. זה המקרה הקשה.

## שלב 3 — בעוד שאני מחכה לתשובה, הפעל את Z2M עכשיו ידנית

כדי שיהיה לך מצב עובד בזמן שאנחנו מנתחים:

```bash
proot-distro login ubuntu
cd /opt/zigbee2mqtt
nohup npm start > /tmp/z2m.log 2>&1 &
disown
exit
```

המתן 30 שניות, ואז בדוק `http://192.168.1.125:8080`. צריך לעלות.

---

תשלח לי את הפלט של שלב 1 ושלב 2 (הtail של הלוג). אז אדע בדיוק למה Z2M מת אחרי הבוט, ונתקן ממוקד — כנראה צריך להוסיף עוד retries או להאריך את ה-sleep בין נסיונות.