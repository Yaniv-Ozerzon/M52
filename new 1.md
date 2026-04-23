Here's the full clean sequence. Run each block in Termux in order. Wait for each block to finish before starting the next.

## Step 1 — Acquire wake lock

Keeps Termux alive if your screen turns off mid-install.

```bash
termux-wake-lock
```

## Step 2 — Clean up all previous attempts

```bash
proot-distro remove ubuntu 2>/dev/null
proot-distro remove ubuntu-24.04 2>/dev/null
rm -rf ~/../usr/var/lib/proot-distro/installed-rootfs/ubuntu
rm -rf ~/../usr/var/lib/proot-distro/installed-rootfs/ubuntu-24.04
rm -rf ~/hass-venv ~/hass-config ~/start-homeassistant.sh ~/stop-homeassistant.sh
```

"No such file or directory" messages are fine — they just mean there was nothing to remove.

## Step 3 — Update Termux

```bash
pkg update -y
pkg upgrade -y
```

If it asks about keeping existing config files, just press Enter to accept the default.

## Step 4 — Install Ubuntu 24.04 explicitly

```bash
proot-distro install ubuntu-24.04
```

Wait for it to finish. This takes 3–10 minutes. **Stop here and tell me what happens:**
- If it finishes successfully → continue to Step 5
- If it fails → screenshot the error and send it to me before doing anything else

## Step 5 — Verify it works

```bash
proot-distro login ubuntu-24.04 -- echo ok
```

You should see `ok` printed with no errors. If yes, continue. If not, stop and send me the output.

## Step 6 — Create the alias so the HA script finds it

The setup script looks for a distro named `ubuntu`. We'll point that name at the 24.04 rootfs.

```bash
cd ~/../usr/var/lib/proot-distro/installed-rootfs
ln -s ubuntu-24.04 ubuntu
cd ~
```

Verify:

```bash
proot-distro login ubuntu -- echo ok
```

Should again print `ok`.

## Step 7 — Download the HA setup script (fresh copy)

```bash
cd ~
rm -f setup-homeassistant.sh
curl -O https://raw.githubusercontent.com/mayukh4/linux-android/main/setup-homeassistant.sh
chmod +x setup-homeassistant.sh
```

## Step 8 — Run the HA setup script

```bash
bash ~/setup-homeassistant.sh
```

This takes 15–45 minutes. Step 4 (compiling Home Assistant) is the longest — 15–30 minutes of the total. Keep your phone plugged in.

## Step 9 — After it finishes

Once the script shows "HOME ASSISTANT INSTALLED", start it:

```bash
bash ~/start-homeassistant.sh
```

First launch takes 5–10 minutes to initialize. When it's ready, open a browser on any device on the same WiFi and go to:

```
http://<your-phone-ip>:8123
```

To find your phone's IP, open a second Termux session and run:

```bash
ip addr show wlan0 | grep 'inet '
```

---

## If something goes wrong

Don't keep re-running the script. Stop at whichever step failed, send me the screenshot, and I'll tell you what to do next. Each step is a real checkpoint — if Step 4 works, Step 5 should work, and so on.

Start with Step 1 and let me know how Step 4 goes.