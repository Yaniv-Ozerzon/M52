אתה צודק — בוא נעשה **סדר ברור, נקי, ולטווח ארוך**.
אנחנו נלך על **הדרך היציבה ביותר**:

**Android → Termux → Ubuntu (proot) → OpenClaw → Auto-Start**

זו הדרך הכי אמינה כיום.

---

# מצב נוכחי שלך

אתה כבר:

✅ בתוך Ubuntu
✅ node/npm מותקן
❌ openclaw CLI לא עובד

לכן נבצע **התקנה נקייה לחלוטין**

---

# שלב 1 — מחיקה נקייה

בתוך Ubuntu הרץ:

```bash
npm uninstall -g openclaw
```

ואז:

```bash
rm -rf /usr/lib/node_modules/openclaw
```

ואז:

```bash
rm -f /usr/bin/openclaw
```

---

# שלב 2 — התקנה יציבה יותר (חשוב מאוד)

התקן Node יציב (LTS):

```bash
apt remove nodejs npm -y
```

ואז:

```bash
apt install curl -y
```

ואז:

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
```

ואז:

```bash
apt install nodejs -y
```

בדיקה:

```bash
node -v
npm -v
```

---

# שלב 3 — התקנת OpenClaw

עכשיו:

```bash
npm install -g openclaw
```

בדיקה:

```bash
which openclaw
```

צריך לקבל:

```
/usr/bin/openclaw
```

---

# שלב 4 — הפעלת OpenClaw

```bash
openclaw onboard
```

בחר:

* Provider: OpenAI
* Model: gpt-4o-mini (מומלץ לטלפון)

---

# שלב 5 — הפעלה

```bash
openclaw gateway
```

עכשיו OpenClaw עובד.

---

# שלב 6 — הפעלה אוטומטית עם הדלקת המכשיר (לטווח ארוך)

חזור ל-Termux (צא מ-Ubuntu):

```bash
exit
```

---

התקן tmux:

```bash
pkg install tmux -y
```

---

צור script:

```bash
mkdir -p ~/.termux/boot
```

---

צור קובץ:

```bash
nano ~/.termux/boot/start-openclaw.sh
```

הדבק:

```bash
#!/data/data/com.termux/files/usr/bin/bash

termux-wake-lock

proot-distro login ubuntu -- bash -c "
tmux new -d -s openclaw 'openclaw gateway'
"
```

---

שמור:

CTRL + X
Y
Enter

---

הרשאות:

```bash
chmod +x ~/.termux/boot/start-openclaw.sh
```

---

# שלב 7 — התקנת Termux Boot

התקן:

[https://f-droid.org/packages/com.termux.boot/](https://f-droid.org/packages/com.termux.boot/)

פתח פעם אחת.

---

# עכשיו מה יקרה

כשאתה:

* מדליק את הטלפון
* Android עולה
* Termux עולה
* Ubuntu עולה
* OpenClaw עולה

אוטומטית 🚀

---

# למה זו הדרך הכי נכונה לטווח ארוך

יתרונות:

✅ יציב
✅ עובד על Android
✅ עולה אוטומטית
✅ לא דורש מחשב
✅ מתאים ל-Galaxy S10 Lite

---

אתה כמעט שם.

ברגע שתגיע לשלב:

```bash
openclaw onboard
```

תגיד לי — ואני אעזור לך לבחור את **הגדרות GPT האידיאליות**.
