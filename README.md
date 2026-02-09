# Android Battery Monitor (ntfy.sh)

A lightweight shell script for Android devices that monitors battery health and sends daily reports to your ntfy.sh topic.

## Features
- Daily Updates: Runs every 24 hours to keep you informed without spam.
- Detailed Stats: Reports battery percentage, charging status, and temperature.
- Persistent Logging: Keeps a local log file at /sdcard/battery_monitor.log.
- Minimal Footprint: Uses native dumpsys and curl.

## Setup

### 1. Prerequisites
- An Android device (Root is recommended for background persistence).
- curl installed on your device.
- A notification topic created on ntfy.sh.

### 2. Configuration
Open daily_ping.sh and edit the following line with your unique topic:
NTFY_URL="https://ntfy.sh/YOUR_CUSTOM_TOPIC"

### 3. Installation
1. Move the script to your device (e.g., /data/local/tmp/ or a Termux folder).
2. Give it execution permissions:
   chmod +x daily_ping.sh
3. Run the script:
   ./daily_ping.sh &

## How it Works
The script utilizes the 'dumpsys battery' command to pull hardware stats directly from the Android system. It then parses the output and formats a message:

- Level: Current battery percentage (0-100%)
- Status: Charging, Discharging, or Full
- Temp: Battery temperature converted to Celsius

## Logging
Logs are stored at /sdcard/battery_monitor.log. You can check the status of the script by running:
tail -f /sdcard/battery_monitor.log

## License
MIT License - feel free to use and modify!
