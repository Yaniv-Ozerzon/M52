Found it — the actual error. This is a real, fixable problem.

## What the error says

```
Error loading /data/data/com.termux/files/home/hass-config/configuration.yaml:
in "/data/data/com.termux/files/home/hass-config/configuration.yaml", line 11, column 9:
Unable to read file /data/data/com.termux/files/home/hass-config/scripts.yaml
```

Translated: line 11 of your `configuration.yaml` says "load `scripts.yaml`" — but **`scripts.yaml` doesn't exist** on disk. HA refuses to load *any* config when one referenced file is missing, including all your automations. That's why the automations never appear in the UI even though `automations.yaml` is fine.

This was almost certainly caused by the earlier troubleshooting suggestion to add three include lines (`automation:`, `script:`, `scene:`) — but the matching files were never created.

## The fix — create the missing files

In Termux (regular Termux, `~ $` prompt):

```bash
echo "[]" > ~/hass-config/scripts.yaml
echo "[]" > ~/hass-config/scenes.yaml
```

The `[]` is YAML for "empty list" — meaning no scripts and no scenes are defined yet, but the files exist for HA to read. This satisfies the include statements without adding any actual content.

Verify the files exist now:

```bash
ls -la ~/hass-config/*.yaml
```

You should see at least: `automations.yaml`, `configuration.yaml`, `scenes.yaml`, `scripts.yaml`.

## Re-run the configuration check

Back in the HA web UI:

1. **Settings → System → Restart** (or wherever the "Check and restart" panel was)
2. Click **Check configuration** again

This time it should say **"Configuration valid!"** in green.

## Then restart HA

1. Click **Restart** (the button next to Check configuration — it'll now be active since config is valid)
2. Wait 60–90 seconds. The browser may show a "Lost connection" message during the restart — that's normal.
3. The page reconnects automatically when HA is back

## After the restart

Go to **Settings → Automations & scenes**. All your "failed" automations should now appear in the list — they were never broken, HA was just refusing to load anything because of the missing scripts.yaml.

Then:
1. Identify duplicates (you probably have 3–5 copies of the water leak automation)
2. Delete all but one
3. Click into the surviving one → ⋮ menu → **Run**
4. Check your MI 8 for the notification

---

This is genuinely the cause of all the timeout dialogs. The editor was saving fine, but HA couldn't load the saved automations because of the broken include reference, so the editor's "wait for it to be active" check kept failing. Once you fix the missing files and restart, everything should snap into place.

Run the two `echo` commands and the restart sequence, then tell me what's in the automations list.