# auto-ntfy

Lightweight shell scripts for Android that keep you connected to your device via [ntfy.sh](https://ntfy.sh) push notifications.

## Scripts

| Script | Purpose |
|---|---|
| `daily_ping.sh` | Sends a battery report (level, status, temperature) every 24 hours |
| `ping_listener.sh` | Listens for a `ping` message and replies with an "I'm on" confirmation |

## Features

- **Daily Battery Reports** — battery percentage, charging status, and temperature pushed once a day.
- **Remote Ping / Pong** — send `ping` to your topic from anywhere; the device replies instantly with its status.
- **Auto-Reconnect** — the listener recovers automatically if the connection drops (e.g. Android Doze).
- **Minimal Footprint** — pure shell, no dependencies beyond `curl` and `dumpsys`.
- **Local Logging** — both scripts keep logs on `/sdcard/` for debugging.

## Prerequisites

- An Android device (root recommended for background persistence)
- root (twrp+magisk is favorable)
- A [ntfy.sh](https://ntfy.sh) topic

## Setup

### 1. Configure your topic

Edit the `NTFY_TOPIC` variable in **both** scripts:

```sh
# daily_ping.sh & ping_listener.sh
NTFY_TOPIC="YOUR_TOPIC_HERE"   # ← replace with your own topic
```

### 2. Deploy to your device

```sh
# Copy scripts to the device
via twrp, adb push path\to\scrip.sh /data/adb/service.d

# Make executable
adb shell chmod +x /path/to/script/in/device.sh (permission 755)
```
### 3. Run

```sh
# Start battery monitor (runs forever, reports every 24h)
./daily_ping.sh &

# Start ping listener (runs forever, replies to "ping")
./ping_listener.sh &
```

> **Tip:** In service.d with magisk, it'll run automatically after boot 

## Usage

Send a ping from any device:

```sh
curl -d "ping" ntfy.sh/YOUR_TOPIC_HERE
```

You'll get a notification back:

> **✅ Device Online**
> 📱 I'm on!
> Battery: 87%
> Time: 2026-02-10 14:30

## Logs

| Script | Log file |
|---|---|
| `daily_ping.sh` | `/sdcard/battery_monitor.log` |
| `ping_listener.sh` | `/sdcard/ping_listener.log` |

Monitor in real time:

```sh
tail -f /sdcard/ping_listener.log
```

## How It Works

- **daily_ping.sh** — loops every 24 hours, reads `dumpsys battery`, formats a message, and `curl`s it to your ntfy topic.
- **ping_listener.sh** — subscribes to the topic via ntfy's SSE (Server-Sent Events) stream with `curl -sN`. When a `"ping"` message arrives, it replies with the device's current status.

## License

[MIT](LICENSE)
