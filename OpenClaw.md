מצוין — עכשיו ברור מה קורה.

אתה קיבלת:

```
/usr
```

זה אומר ש-npm התקין את OpenClaw כאן:

```
/usr/bin/openclaw
```

אבל כנראה שהקובץ לא נוצר נכון (זה קורה לפעמים עם npm בתוך Ubuntu ב-proot).

נעשה התקנה מחדש בצורה נקייה.

# שלב 1 — התקנה מחדש (מומלץ)

הרץ:

```bash
npm uninstall -g openclaw
```

ואז:

```bash
npm install -g openclaw --unsafe-perm=true --allow-root
```

(הפרמטרים האלו חשובים כי אתה root בתוך proot)

---

# שלב 2 — בדיקה

הרץ:

```bash
which openclaw
```

אתה אמור לקבל:

```
/usr/bin/openclaw
```

---

# שלב 3 — אם עדיין לא עובד

נסה:

```bash
/usr/bin/openclaw onboard
```

---

# אם עדיין לא עובד (fallback בטוח)

נסה:

```bash
npx openclaw onboard
```

---

# למה זה קורה

בתוך:

* Android
* Termux
* Ubuntu (proot)

npm לפעמים:

* מתקין בלי ליצור binary
* או יוצר binary בלי הרשאות

זה באג מוכר.

---

אגב — אתה מתקדם מצוין.
זה החלק הכי "קשה" בהתקנה — ומכאן זה נהיה קל.

אחרי שזה יעבוד, נעבור ל:

* Autostart בעת boot
* חיסכון בסוללה
* שימוש עם GPT בצורה אופטימלית
