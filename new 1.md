מעולה, יש לך יותר מספיק מקום. 100GB+ פנויים זה שפע - נוכל ליצור image נדיב של 8GB שיאפשר גמישות ל-HA, logs, מסד נתונים של היסטוריה, וכל התוספות שתרצה להוסיף בעתיד.

לפני שאני כותב את המדריך המלא, שתי הערות חשובות על Linux Deploy שכדאי שתדע מראש:

## הערה ראשונה - המצב של Linux Deploy ב-2026

Linux Deploy היא אפליקציה ותיקה (מ-2012) שעדיין עובדת מצוין, אבל:
- עדכון אחרון שלה היה ב-2021 בערך
- ב-F-Droid יש גרסה 2.6.0 שהיא יציבה
- זה אומר שהממשק שלה ישן, אבל הפונקציונליות של chroot לא השתנתה מאז - זה עדיין עובד מושלם

## הערה שנייה - בחירה חשובה בתוך Linux Deploy

Linux Deploy מציעה שתי דרכי התקנה:
- **File** (קובץ image) - מומלץ בשבילך. יוצר קובץ אחד גדול שמתנהג כ-disk.
- **Directory** - תיקייה רגילה. פחות מבודד, לפעמים יש בעיות הרשאות.

אנחנו נלך עם File.

---

אני אכתוב את המדריך בצורה מאוד ברורה - הפעם אתאמץ שכל פקודה תהיה בחלונית נפרדת והערות תמיד מחוץ. המדריך יהיה ארוך אבל מחולק לחלקים.

## חלק 1: התקנת האפליקציות

### פעולה 1.1: התקנת F-Droid (אם אין לך כבר)

הורד מ: https://f-droid.org/

אם יש לך כבר F-Droid, דלג.

---

### פעולה 1.2: התקנת Linux Deploy

פתח את F-Droid, חפש **"Linux Deploy"** והתקן. אם לא מופיע - הוסף את המאגר:
```
https://apt.izzysoft.de/fdroid/repo
```
(Settings → Repositories → + → הדבק).

---

### פעולה 1.3: התקנת BusyBox (נדרש ל-Linux Deploy)

ב-F-Droid, חפש **"BusyBox"** והתקן את הגרסה של **Meefik** (אותו מפתח של Linux Deploy).

---

### פעולה 1.4: מתן הרשאות root

פתח את Magisk → Superuser → תקבל בקשות הרשאה כשתריץ את Linux Deploy ו-BusyBox. אשר את שתיהן.

---

## חלק 2: הגדרת Linux Deploy

### פעולה 2.1: יצירת Profile

1. פתח את Linux Deploy
2. בצד ימין למעלה, לחץ על סמל הפרופיל (סמל איש קטן)
3. לחץ על **+** ליצירת פרופיל חדש
4. תן לו שם: `homeassistant`
5. בחר אותו מהרשימה

---

### פעולה 2.2: הגדרות הפרופיל (החלק הכי חשוב)

לחץ על סמל **ההגדרות** (גלגל שיניים למטה). הנה הערכים שאתה צריך להכניס:

| הגדרה | ערך | הערות |
|---|---|---|
| **Distribution** | Debian | |
| **Distribution suite** | bookworm | Debian 12 - יציב מאוד עם HA |
| **Architecture** | arm64 | |
| **Installation type** | File | לא Directory |
| **Installation path** | ~/linux.img | Linux Deploy יצור את זה |
| **Image size (MB)** | 8192 | 8GB - מרווח טוב |
| **File system** | ext4 | |
| **User name** | ha | משתמש שלנו |
| **User password** | (בחר סיסמה חזקה) | תזדקק לה להרבה דברים |
| **Privileged users** | ha | |
| **Localization** | en_US.UTF-8 | |
| **DNS** | 1.1.1.1 | |
| **Init system** | sysv | |

---

### פעולה 2.3: הפעלת SSH (חשוב!)

גלול למטה בהגדרות עד **"SSH"**:
- הפעל את ה-**checkbox**
- Port: **22** (ברירת מחדל)

גלול עוד קצת עד **"Init"**:
- הפעל **checkbox** של "Enable"

זה חשוב - בלי זה תהיה תלוי במקלדת וירטואלית.

---

## חלק 3: בניית ה-Image

### פעולה 3.1: התחלת ההתקנה

1. חזור למסך הראשי של Linux Deploy
2. תפריט למעלה (שלוש נקודות) → **Install**
3. יבקש אישור - אשר

**זה ייקח 15-30 דקות**. תראה log רץ שמוריד חבילות. אל תסגור את האפליקציה.

בסיום תראה `<<< end: install`.

---

### פעולה 3.2: הפעלת הסביבה לראשונה

1. במסך הראשי, לחץ **START** (כפתור גדול למטה)
2. המתן לראות בלוג `<<< start` בלי שגיאות
3. המצב יראה משהו כמו `running` או אור ירוק

---

## חלק 4: כניסה דרך SSH מהמחשב

עכשיו אנחנו עוזבים את הטרמינל בטלפון - עוברים למחשב.

### פעולה 4.1: מציאת ה-IP של הטלפון

בהגדרות WiFi של אנדרואיד, לחץ על הרשת שאתה מחובר אליה → שם יופיע IP address. שמור אותו.

לחלופין, ב-Termux:
```bash
ifconfig wlan0 | grep inet
```

---

### פעולה 4.2: התחברות SSH מהמחשב

אם אתה על Windows 11 - פתח PowerShell או Terminal.
אם אתה על Linux/Mac - פתח Terminal.

```bash
ssh ha@<IP-של-הטלפון>
```

דוגמה אם ה-IP הוא 192.168.1.50:
```bash
ssh [email protected]
```

הקלד את הסיסמה שקבעת.

---

## חלק 5: בדיקת הסביבה

### פעולה 5.1: בדיקת platform - הרגע המכריע

```bash
python3 -c "import sysconfig; print(sysconfig.get_platform())"
```

**מה אתה אמור לראות:**
```
linux-aarch64
```

אם זה מה שיצא - **ניצחנו**. הסביבה מזהה את עצמה כ-Linux אמיתי. עכשיו Python ו-pip ימצאו wheels לכל החבילות.

אם עדיין מופיע `android-` - שלח לי צילום מסך ונחליט מה לעשות.

---

## חלק 6: התקנת Home Assistant

### פעולה 6.1: מעבר ל-root

```bash
sudo -i
```

הסיסמה אותה סיסמה.

---

### פעולה 6.2: עדכון והתקנת תלויות

```bash
apt update && apt upgrade -y
```

---

```bash
apt install -y python3 python3-dev python3-venv python3-pip build-essential libssl-dev libffi-dev libjpeg-dev zlib1g-dev autoconf libopenjp2-7 libtiff6 libturbojpeg0-dev tzdata ffmpeg liblapack3 liblapack-dev libopenblas-dev git curl wget nano bluez libbluetooth-dev avahi-daemon
```

---

### פעולה 6.3: הגדרת timezone

```bash
ln -sf /usr/share/zoneinfo/Asia/Jerusalem /etc/localtime
```

```bash
echo "Asia/Jerusalem" > /etc/timezone
```

```bash
date
```

אמור להראות שעה ישראלית.

---

### פעולה 6.4: יצירת משתמש homeassistant

```bash
useradd -rm homeassistant -G dialout,audio
```

```bash
mkdir /srv/homeassistant
```

```bash
chown homeassistant:homeassistant /srv/homeassistant
```

---

### פעולה 6.5: מעבר למשתמש ויצירת venv

```bash
su - homeassistant -s /bin/bash
```

```bash
cd /srv/homeassistant
```

```bash
python3 -m venv .
```

```bash
source bin/activate
```

ה-prompt אמור להיות `(homeassistant) homeassistant@localhost:/srv/homeassistant$`.

---

### פעולה 6.6: שדרוג pip

```bash
python3 -m pip install --upgrade pip wheel setuptools
```

---

### פעולה 6.7: התקנת Home Assistant

```bash
pip install homeassistant
```

**זה ייקח 10-20 דקות**. הפעם, מכיוון ש-Python מזהה את עצמו כ-linux-aarch64, pip ימצא wheels מוכנים לכל החבילות ולא יצטרך לקמפל. אם יראה שגיאות - שלח לי.

---

### פעולה 6.8: הרצה ראשונה

```bash
hass
```

ההרצה הראשונה תיקח 3-5 דקות - HA מוריד תלויות נוספות ובונה config ראשוני.

תראה הרבה הודעות. חכה לשורה:
```
INFO (MainThread) [homeassistant.core] Starting Home Assistant
```

---

### פעולה 6.9: גישה ל-HA

מהדפדפן במחשב (או בטלפון):
```
http://<IP-של-הטלפון>:8123
```

אתה אמור לראות את מסך ההגדרה הראשוני של Home Assistant.

---

## מה הלאה

**עצור כאן** כשיש לך HA פועל ותגיע למסך הצהוב של יצירת משתמש.

אחרי זה נטפל ב:
- autoboot (הפעלה אוטומטית עם הטלפון)
- MQTT
- האינטגרציות הספציפיות שלך
- נעילת הטלפון נגד kill של אנדרואיד

---

**שלב קריטי לעצור בו ולדווח לי**: פעולה 5.1 - אחרי ה-SSH הראשון, הרץ את בדיקת ה-platform. אם רואים `linux-aarch64` - פניננו פנוי וכל השאר יעבוד חלק. אם רואים משהו אחר - נעצור, נבין, ונפתור.

בהצלחה! 🚀