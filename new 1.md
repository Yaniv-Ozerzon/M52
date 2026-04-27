חכה רגע - יש כאן משהו חשוב מאוד שלא ברור.

## מה רואים בצילום

```
proot-distro login ubuntu -- pgrep mosquitto
23238

proot-distro login ubuntu -- bash -c 'echo > /dev/tcp/localhost/1883 && echo OPEN || echo CLOSED'
OPEN

proot-distro login ubuntu -- cat /tmp/mosq-debug.log
[ריק]
```

**Mosquitto רץ! פורט 1883 פתוח! זה עובד!** 🎉

ה-PID הוא 23238, והפורט מקבל חיבורים. הלוג ריק כי כנראה הוא הופנה אחרת או ש-tee עוד לא flush, אבל זה לא משנה - מה שחשוב זה שהשירות **עובד**.

## רגע - אז למה זה עובד עכשיו ולא קודם?

זה בעצם המידע הקריטי. ההבדל בין "לא עובד" (קודם) ל"עובד" (עכשיו) הוא **רק זה**: עכשיו הרצנו עם `&` ב-foreground+background, בלי `-d`.

זה אומר שיש בעיה ספציפית עם **דגל ה-`-d` (daemon mode)** של Mosquitto בסביבת proot. כשהוא מנסה לעשות fork ולהתנתק מה-terminal, הוא מת. בלי `-d` הוא רץ יפה.

## הפתרון - להפסיק להשתמש ב-`-d`

זה תיקון פשוט אבל קריטי. צריך לשנות את אופן ההפעלה של Mosquitto בכל הסקריפטים שלנו - להפעיל אותו עם `nohup` ו-`&` במקום `-d`.

### שלב 1: לוודא שמה שרץ עכשיו יציב

תחכה דקה ואז:

```bash
proot-distro login ubuntu -- pgrep mosquitto
proot-distro login ubuntu -- bash -c 'echo > /dev/tcp/localhost/1883 && echo OPEN || echo CLOSED'
```

צריך עדיין לראות את אותו PID 23238 ו-OPEN. אם כן - יציב.

### שלב 2: להרוג את ה-Mosquitto שרץ עכשיו ולהריץ אותו "כמו שצריך"

```bash
# הרוג את הקיים
proot-distro login ubuntu -- pkill mosquitto
sleep 2

# הפעל בדרך החדשה - nohup במקום -d
nohup proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf' > ~/mosquitto.log 2>&1 &
disown

sleep 3

# בדוק
proot-distro login ubuntu -- pgrep mosquitto
proot-distro login ubuntu -- bash -c 'echo > /dev/tcp/localhost/1883 && echo OPEN || echo CLOSED'
```

צריך לראות PID חדש ו-`OPEN`.

### שלב 3: עצור כאן ושלח לי את הפלט

לפני שנעדכן את ה-watchdog ו-boot script, אני רוצה לוודא ש-Mosquitto באמת רץ יציב בלי `-d`. שלח את הפלט של שלב 2.

אם זה עובד יציב - אני אכתוב לך גרסאות מתוקנות של `start-smarthome.sh` ו-`watchdog-loop.sh` שמשתמשות ב-`nohup` במקום `-d`, וזה יפתור את הלולאה האינסופית של "Mosquitto DOWN - restarting".