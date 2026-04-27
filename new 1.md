עכשיו יש לי תמונה ברורה. תודה על הצילומים - הם חושפים בדיוק מה קורה.

## מה הצילומים מספרים

**צילום 3 - הממצא הקריטי:**
```
MOSQ DOWN
17085
17321
Z2M UP
4171
HA UP
```

זה מוזר מאוד - הסקריפט אומר "MOSQ DOWN" אבל מציג 2 PIDs (17085, 17321). זה אומר ש-`pgrep mosquitto` **כן** מצא תהליכים, אבל ה-`echo "MOSQ UP"` לא הופעל. למה? כי השורה היא:
```
pgrep mosquitto && echo "MOSQ UP" || echo "MOSQ DOWN"
```
ה-`pgrep` מדפיס את ה-PIDs ואז... מחזיר exit code 0 (הצליח), אז `MOSQ UP` היה אמור להופיע. אבל אנחנו רואים `MOSQ DOWN`.

**מה שקורה בפועל:** Mosquitto **כן רץ** (PIDs 17085, 17321 מופיעים) אבל `pgrep mosquitto` בתוך proot מחזיר exit code שגוי, או שיש שני תהליכים והבדיקה מתבלבלת.

**צילום 1 - 192.168.1.125:8080 refused:**
זה פורט Home Assistant. HA כתוב "UP" עם PID 4171, אבל הוא לא מקשיב על 8080. או שהוא עדיין מתאתחל, או שהוא קורס שקט.

**צילום 2 - הלולאה האינסופית:**
מההפעלה של 14:46 ועד 15:26 - **כל 5 דקות בדיוק** Mosquitto נופל ו-Z2M נופל. זה לא רנדומלי - זה systematic.

## האבחנה האמיתית

יש כאן **שני באגים נפרדים**, ואני חושב שהראשון הוא הסיבה לכל הבלגן:

### באג 1: יש שני תהליכי Mosquitto (PIDs 17085 ו-17321)

מבט נוסף על צילום 3 - יש **שני** PIDs של Mosquitto. זה לא תקין. זה אומר שה-watchdog "הפעיל מחדש" את Mosquitto בעוד שהוא כבר רץ. שני תהליכים מתחרים על פורט 1883 → אחד מהם נכשל → הלולאה ממשיכה.

### באג 2: הבדיקה `proot-distro login ubuntu -- pgrep mosquitto` לא אמינה

כל פעם שהיא רצה היא יוצרת session חדש של proot, וזה איטי, יקר במשאבים, ולפעמים מחזיר תוצאות לא עקביות.

## מה לעשות עכשיו - שלב אחר שלב

### שלב 1: לעצור הכל ולנקות

```bash
# הרוג את ה-watchdog
pkill -f watchdog-loop.sh

# הרוג את כל ה-Mosquitto-ים הכפולים
proot-distro login ubuntu -- pkill -9 mosquitto

# הרוג את Z2M
proot-distro login ubuntu -- pkill -9 -f "node.*index.js"

# הרוג את HA
pkill -9 -f homeassistant

# חכה 5 שניות
sleep 5

# וודא שהכל מת
proot-distro login ubuntu -- pgrep mosquitto
proot-distro login ubuntu -- pgrep -f node
pgrep -f homeassistant
```

שלוש הפקודות האחרונות צריכות **לא להחזיר כלום**. אם משהו עדיין רץ, הרץ שוב את ה-`pkill -9` המתאים.

### שלב 2: להפעיל את Mosquitto לבד ולוודא שהוא יציב

```bash
# הפעל Mosquitto
proot-distro login ubuntu -- bash -c 'mosquitto -c /etc/mosquitto/mosquitto.conf -d'

# חכה 3 שניות
sleep 3

# בדוק שיש בדיוק תהליך אחד
proot-distro login ubuntu -- pgrep mosquitto
```

צריך לראות **PID אחד בלבד**. אם רואים שניים - יש בעיה בקובץ ההגדרות של Mosquitto. תגיד לי ואני אעזור לבדוק.

### שלב 3: לבדוק שפורט 1883 באמת מקבל חיבורים

```bash
proot-distro login ubuntu -- bash -c 'echo > /dev/tcp/localhost/1883 && echo "1883 OPEN" || echo "1883 CLOSED"'
```

צריך לראות `1883 OPEN`. אם רואים `CLOSED` - Mosquitto לא באמת מקשיב. אז נבדוק את הקונפיג שלו.

### שלב 4: עצור כאן ושלח לי את הפלט

לפני שנמשיך להפעיל Z2M ו-HA, אני רוצה לראות שלפחות Mosquitto יציב. שלח לי את הפלט של שלבים 1-3.

אם Mosquitto לא יציב, אין טעם להפעיל מחדש את כל השאר - הם פשוט יקרסו שוב באותה לולאה.