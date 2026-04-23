Here's the full clean sequence. Run each block in Termux in order. Wait for each block to finish before starting the next.

## Step 1 — Acquire wake lock

Keeps Termux alive if your screen turns off mid-install.

```bash
termux-wake-lock
```





Excellent — Debian installed cleanly. `Finished.` is exactly what we needed to see. No debconf crash this time.

Now let's get the rest set up. Run each block in order, wait for each to finish.

## Step 1 — Verify Debian works

```bash
proot-distro login debian -- echo ok
```

Should print `ok`. If not, stop and tell me.

## Step 2 — Create the alias so the HA script finds it

The script is hardcoded to `proot-distro login ubuntu`. We'll point `ubuntu` at the Debian rootfs:

```bash
cd ~/../usr/var/lib/proot-distro/installed-rootfs
ln -s debian ubuntu
cd ~
```

Verify the alias works:

```bash
proot-distro login ubuntu -- echo ok
```

Should again print `ok`.

## Step 3 — Also copy the distro config file

This is the piece that often gets missed. proot-distro also has a plugin/config file per distro that the `list` and `login` commands check. We need to mirror Debian's:

```bash
cd ~/../usr/etc/proot-distro
cp debian.sh ubuntu.sh
cd ~
```

Now check that `proot-distro list` shows Ubuntu as installed:

```bash
proot-distro list | grep -A1 ubuntu
```

You should see something indicating it's installed. If you see "Error" or it's not there, send me a screenshot before continuing.

## Step 4 — Clean up old HA files

```bash
rm -rf ~/hass-venv ~/hass-config ~/start-homeassistant.sh ~/stop-homeassistant.sh
```

## Step 5 — Download a fresh copy of the HA script

```bash
cd ~
rm -f setup-homeassistant.sh
curl -O https://raw.githubusercontent.com/mayukh4/linux-android/main/setup-homeassistant.sh
chmod +x setup-homeassistant.sh
```

## Step 6 — Run it

```bash
bash ~/setup-homeassistant.sh
```

This is the long one — 15–45 minutes. Step 4 (compiling Home Assistant Core) takes most of that time. Keep your phone plugged in and don't close Termux.

---

## What to watch for this time

The critical moment is Step 2 of the HA script — "Setting up Ubuntu 24.04 container." With our alias in place it should now see Ubuntu as already installed and skip the download/install part, which is exactly what we want. You should see a gray `~` mark with "(already installed)" instead of red X failures.

If Step 2 of the HA script shows "already installed" → the rest should flow. If it fails again, screenshot it and stop.

Send me a screenshot after Step 3 above (the `proot-distro list | grep` check) before running the HA script. That's our last checkpoint before committing to the 30-minute compile.