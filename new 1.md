הבנתי, זה הרבה יותר נוח. הנה כל פקודה בחלונית נפרדת:

---

### שלב 1: יציאה מה-venv

```bash
deactivate
```

### שלב 2: יציאה למשתמש root

```bash
exit
```

אחרי הפקודה הזו שורת הפקודה אמורה להיות `root@localhost:~#` (בלי `(homeassistant)` בהתחלה).

---

### שלב 3: הגדרת משתני סביבה לsession הנוכחי

```bash
export CARGO_BUILD_TARGET=aarch64-unknown-linux-gnu
```

```bash
export ANDROID_API_LEVEL=34
```

### שלב 4: שמירת המשתנים לצמיתות

```bash
echo 'export CARGO_BUILD_TARGET=aarch64-unknown-linux-gnu' >> /etc/profile
```

```bash
echo 'export ANDROID_API_LEVEL=34' >> /etc/profile
```

---

### שלב 5: חזרה למשתמש homeassistant

```bash
sudo -u homeassistant -H -s
```

שורת הפקודה אמורה להשתנות ל-`homeassistant@localhost:~$`.

### שלב 6: כניסה לתיקייה והפעלת ה-venv

```bash
cd /srv/homeassistant
```

```bash
source bin/activate
```

אחרי זה אמור להיות `(homeassistant) homeassistant@localhost:/srv/homeassistant$`.

---

### שלב 7: ניקוי cache של pip

```bash
pip cache purge
```

זה מוחק קבצי build חלקיים שנשארו מהניסיון הקודם שכשל.

---

### שלב 8: התקנת cryptography כ-wheel מוכן

```bash
pip install --only-binary :all: cryptography
```

זה השלב הקריטי - אם הוא עובר בהצלחה, כל השאר יעבור. חכה שזה יסתיים לפני שממשיכים.

---

### שלב 9: המשך התקנת Home Assistant

```bash
pip install homeassistant
```

זה ייקח 10-20 דקות. אם יש עוד חבילות שמנסות לקמפל ונכשלות, נטפל בהן אחר כך.

---

**עצור כאן ותגיד לי מה קרה בשלב 8** - זה הקריטי ביותר. אם `cryptography` הותקן בהצלחה, תראה בסוף שורה כמו:
```
Successfully installed cryptography-XX.X.X
```

אם זה נכשל, שלח צילום מסך ונמשיך מנקודה זו.



















מצוין, בחירה נכונה. נצא לדרך.

לפני שמתחילים - **הערה חשובה אחת**: אנדרואיד אוהב להרוג תהליכים ברקע כדי לחסוך סוללה. כדי שה-HA שלך לא ימות כשהמסך נכבה, נצטרך לטפל בזה בסוף המדריך. אל תדלג על השלב הזה.

---

## שלב 1: הכנת Termux

פתח את Termux ותריץ:

```bash
pkg update && pkg upgrade -y
pkg install proot-distro wget curl nano termux-api -y
termux-setup-storage
```

**חשוב - מנע מאנדרואיד להרוג את Termux:**

```bash
# מבקש מהמערכת לא להרוג את Termux
pkg install termux-services -y
```

גם גש ל**הגדרות המכשיר → אפליקציות → Termux → סוללה → ללא הגבלה / Unrestricted**. עשה את זה גם ל-Termux:Boot אם תתקין אותו בהמשך.

## שלב 2: התקנת Debian

```bash
proot-distro install debian
```

זה ייקח 5-10 דקות. כשזה מסתיים:

```bash
proot-distro login debian
```

**שים לב לשורת הפקודה** - היא אמורה להשתנות ל-`root@localhost:~#`. כל שלב מכאן והלאה הוא **בתוך Debian**, לא בתוך Termux.

## שלב 3: הכנת Debian

```bash
apt update && apt upgrade -y
apt install -y \
  python3 python3-dev python3-venv python3-pip \
  build-essential libssl-dev libffi-dev \
  libjpeg-dev zlib1g-dev \
  autoconf libopenjp2-7 libtiff6 libturbojpeg0-dev \
  tzdata ffmpeg liblapack3 liblapack-dev \
  libatlas-base-dev git curl wget nano sudo \
  bluez libbluetooth-dev \
  avahi-daemon
```

הגדר timezone (חשוב ל-HA):

```bash
dpkg-reconfigure tzdata
```

בחר Asia → Jerusalem.

צור משתמש ייעודי ל-HA (practice טוב יותר מאשר להריץ כ-root):

```bash
useradd -rm homeassistant -G dialout,audio
mkdir /srv/homeassistant
chown homeassistant:homeassistant /srv/homeassistant
```

## שלב 4: יצירת סביבת Python והתקנת HA

```bash
sudo -u homeassistant -H -s
cd /srv/homeassistant
python3 -m venv .
source bin/activate
python3 -m pip install --upgrade pip wheel
```

עכשיו ההתקנה של HA עצמה (זה ייקח 10-20 דקות, יש הרבה תלויות לקמפל):

```bash
pip install homeassistant
```

אם זה נכשל באמצע (קורה), הרץ שוב - pip ימשיך מאיפה שהפסיק.

## שלב 5: הרצה ראשונה

```bash
hass
```

ההרצה הראשונה תיקח **3-5 דקות** כי HA מוריד תלויות ובונה config ראשוני. חכה שתראה שורה כמו:
```
INFO (MainThread) [homeassistant.core] Starting Home Assistant
```

פתח דפדפן **בטלפון עצמו** או במחשב באותה רשת:
```
http://<IP-של-הטלפון>:8123
```

למצוא את ה-IP: בטרמינל חדש של Termux (לא בתוך Debian), הרץ `ifconfig` או תראה בהגדרות WiFi של אנדרואיד.

תראה את מסך ההגדרה הראשוני של HA - תצור משתמש ותיכנס.

## שלב 6: חיבור Mosquitto (MQTT Broker)

צא מהמשתמש homeassistant (`exit`), חזור ל-root ב-Debian:

```bash
apt install -y mosquitto mosquitto-clients
```

הגדר משתמש/סיסמה:

```bash
mosquitto_passwd -c /etc/mosquitto/passwd ha_user
# הכנס סיסמה
```

ערוך config:

```bash
nano /etc/mosquitto/conf.d/default.conf
```

הדבק:
```
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd
persistence true
persistence_location /var/lib/mosquitto/
```

הפעל:
```bash
service mosquitto start
```

אחר כך ב-HA UI: **Settings → Devices & Services → Add Integration → MQTT** עם `localhost:1883` ו-ha_user/הסיסמה.

## שלב 7: אוטומציה של ההפעלה - הנקודה הקריטית

עכשיו החלק שבלעדיו הכל לחינם. צריך שהכל יעלה אוטומטית עם הפעלת הטלפון.

**התקן Termux:Boot** מ-F-Droid (לא מ-Google Play - הגרסה שם ישנה):
https://f-droid.org/packages/com.termux.boot/

אחרי ההתקנה פתח אותו פעם אחת, אחר כך:

```bash
# ב-Termux (לא ב-Debian)
mkdir -p ~/.termux/boot
nano ~/.termux/boot/start-ha.sh
```

הדבק:
```bash
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
proot-distro login debian -- bash -c "
  service mosquitto start
  service avahi-daemon start
  sudo -u homeassistant -H bash -c 'cd /srv/homeassistant && source bin/activate && hass' &
"
```

```bash
chmod +x ~/.termux/boot/start-ha.sh
```

**ה-`termux-wake-lock`** זה הקריטי - הוא מונע מאנדרואיד לישון את התהליך.

## שלב 8: גישה מרחוק - בלי לפתוח פורטים

לגישה מחוץ לבית, אני ממליץ על **Nabu Casa (Home Assistant Cloud)** - 6.5$ לחודש, זה ה-cloud הרשמי, תומך ב-Google Assistant/Alexa, ואתה תומך בפרויקט. כחלופה חינמית - **Tailscale** (תתקין גם בטלפון-שרת וגם בנייד שלך, ותגש ל-HA דרך ה-Tailscale IP).

## הנקודות שעלולות להכשיל אותך - שים לב

**1. אנדרואיד הורג את התהליך:**
אם HA מפסיק לעבוד אחרי כמה שעות - הסוללה של אנדרואיד אגרסיבית. ודא:
- Termux ו-Termux:Boot ב-"ללא הגבלת סוללה"
- `termux-wake-lock` רץ (תראה notification קבוע - זה טוב)
- השאר את הטלפון מחובר לחשמל תמיד

**2. השעון נסחף ב-proot:**
אחרי Reboot, לפעמים שעון ה-proot לא מסונכרן. הרץ בתוך Debian: `date` והשווה. אם לא תקין: `apt install ntpdate && ntpdate pool.ntp.org`.

**3. HA לא מגיב אחרי עדכון:**
אם `pip install --upgrade homeassistant` שובר משהו, אפשר לחזור: `pip install homeassistant==<גרסה קודמת>`. גבה את התיקייה `/root/.homeassistant` (או `~/.homeassistant` של המשתמש homeassistant) לפני כל עדכון.

**4. Zigbee2MQTT - כשתגיע לזה:**
דונגל USB דרך OTG בטלפון זה עניין בפני עצמו. כשתהיה מוכן, תחזור אליי עם:
- איזה דונגל קנית
- פלט של `lsusb` ו-`dmesg | tail -50` אחרי חיבור
ונראה יחד אם ה-kernel של LineageOS שלך מזהה אותו או שנצטרך להטעין module דרך Magisk.

---

## מה הלאה?

התחל משלבים 1-5 בלבד כרגע. כשיש לך HA פועל ואתה מצליח להיכנס ל-UI, תחזור אליי ונמשיך ל-MQTT, autoboot, והאינטגרציות שלך. אם תיתקע באיזשהו שלב - שלח לי את השגיאה המדויקת (צילום מסך או copy של הטקסט) ונפתור.

בהצלחה! 🏠