# Home Assistant Core on Rooted Android (Samsung M52)

This project provides a high-performance, minimalist setup for running Home Assistant Core on a rooted Android device. It is specifically optimized for devices running LineageOS and Magisk, ensuring full hardware access.

Developed by: **Yaniv Ozerzon**

## 🌟 Features
- **Full Hardware Access:** Direct access to USB (Zigbee sticks) and Bluetooth.
- **Root-Optimized:** Uses `tsu` and Magisk to bypass Android's background limitations.
- **Logging System:** All installation steps are logged to `~/install.log` for troubleshooting.
- **Autostart:** Boots automatically with the device using Termux:Boot.
- **Minimalist & Clean:** Runs inside a lightweight Ubuntu 24.04 container with zero GUI overhead.

## 🛠 Prerequisites
- **Device:** Rooted arm64 Android (Optimized for Samsung M52).
- **OS:** LineageOS (recommended) or any Rooted ROM with Magisk.
- **Apps:** - [Termux](https://f-droid.org/en/packages/com.termux/)
  - [Termux:Boot](https://f-droid.org/en/packages/com.termux.boot/)
  - [Termux:API](https://f-droid.org/en/packages/com.termux.api/)

## 🚀 Quick Install

1. Open Termux and run the following commands:
   ```bash
   pkg install git tsu -y
   git clone [https://github.com/Yaniv-Ozerzon/M52.git](https://github.com/Yaniv-Ozerzon/M52.git)
   cd M52
   chmod +x setup-homeassistant.sh
   ./setup-homeassistant.sh