OK — direct reboot URLs aren't available on your firmware version. That's fine, we'll use a different approach: a "wait until ready, then start" pattern in the boot script. This actually turns out to be more robust than rebooting the SLZB-06.

Before I commit to the plan, let me check one more thing — what API endpoints SMLIGHT actually exposes on your firmware version:The SMLIGHT docs explicitly say their HTTP API is undocumented, internal-use, and "may change without notice." Trying to script around it is fragile. So we'll do something better and more reliable: **don't reboot the SLZB-06 at all — instead, wait for the Zigbee port to be ready before starting Z2M, and retry if the first try fails.**

This pattern is more robust because it survives:
- Phone reboots
- SLZB-06 reboots
- Network blips
- The INVALID_STATE issue (just retry — second attempt almost always works)

## Plan I'm proposing

Three small files. About 20 minutes total.

1. **A "wait for SLZB-06 ready" helper** — checks the TCP port 6638 is open and not stuck
2. **A new boot script** — uses the helper, retries Z2M if it crashes early
3. **A watchdog loop** — runs every 5 minutes, restarts dead services. Started by the boot script (no Termux:API or job-scheduler needed)

I'll write the scripts in a moment. First — confirm where you are right now so we don't break anything:

```bash
proot-distro login ubuntu -- bash -c "ps aux | grep -E 'mosquitto|node index' | grep -v grep"
```

Send me the output. I want to see Mosquitto and Z2M both running so we know we're starting from a healthy state.

Also — quickly confirm:

```bash
ls ~/.termux/boot/
```

I want to know what files are currently in the boot directory so I can tell you exactly what to replace.

Once I see those two outputs, I'll write you the three scripts to replace what's there. We test them by manually running the boot script first (no reboot), then once that works, we do a real reboot test. If anything fails, you can roll back to your current working state because we'll back up the current scripts before replacing them.

Send me those two outputs and I'll write the scripts.