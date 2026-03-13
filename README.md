# Home Assistant Core on Rooted Android (Samsung M52/LineageOS)

This project provides a high-performance, minimalist setup for running Home Assistant Core on a rooted Android device. 

## 🌟 Features
- **Full Hardware Access:** Direct access to USB (Zigbee sticks) and Bluetooth.
- **Root-Optimized:** Uses `tsu` and Magisk to bypass Android's background limitations.
- **Autostart:** Boots automatically with the device using Termux:Boot.
- **Low Footprint:** No GUI overhead, runs inside a clean Ubuntu 24.04 container.

## 🛠 Prerequisites
- **Device:** Rooted arm64 Android (Tested on Samsung M52).
- **OS:** LineageOS (recommended) or any Rooted ROM with Magisk.
- **Apps:** [Termux](https://f-droid.org/en/packages/com.termux/), [Termux:Boot](https://f-droid.org/en/packages/com.termux.boot/), [Termux:API](https://f-droid.org/en/packages/com.termux.api/).

## 🚀 Quick Install
1. Open Termux and run:
   ```bash
   git clone [https://github.com/YOUR_USERNAME/YOUR_REPO.git](https://github.com/YOUR_USERNAME/YOUR_REPO.git)
   cd YOUR_REPO
   chmod +x setup-homeassistant.sh
   ./setup-homeassistant.sh