Going step by step. Each step is small. After each, I'll tell you what to expect, and you tell me what you see.

## Step 1 — Back up current scripts

In Termux (regular Termux, `~ $` prompt):

```bash
mkdir -p ~/script-backups
cp -r ~/.termux/boot ~/script-backups/boot-$(date +%Y%m%d_%H%M)
ls ~/script-backups/
```

**Expected output:** something like `boot-20260427_0935` (a directory inside script-backups).

**If anything fails:** stop, send me the error.

If it worked, run:

```bash
ls ~/script-backups/boot-*/
```

You should see both `start-smarthome.s` and `start-smarthome.sh` listed — those are your safe copies.

## Step 2 — Delete the stale .s file

```bash
rm ~/.termux/boot/start-smarthome.s
ls ~/.termux/boot/
```

**Expected output:** only `start-smarthome.sh` should appear. The duplicate is gone.

If you see only one file → continue. If anything else, stop.

---

Stop here. Do these two steps and tell me the output of the final `ls`. Then I'll send the script contents in the next message.