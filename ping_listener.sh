#!/system/bin/sh
# Ping Listener
# Listens to a ntfy.sh topic and replies "I'm on" when it receives a "ping" message
# Place in /data/adb/service.d/ and chmod 755

# Run in background so Magisk can continue booting
(

# Give WiFi time to connect after boot
sleep 60

# Configuration
NTFY_TOPIC="YOUR_TOPIC_HERE"
NTFY_URL="https://ntfy.sh/${NTFY_TOPIC}"
WAIT_FOR_NETWORK=false  # Set to true for network check
LOG_FILE="/data/local/tmp/ping_listener.log"
LOCK_FILE="/data/local/tmp/ping_listener.lock"
LAST_ID_FILE="/data/local/tmp/ping_listener_lastid"
LAST_TIME_FILE="/data/local/tmp/ping_listener_lasttime"

# Simple logging function
log() {
    echo "$(date) - $1" >> "$LOG_FILE"
}

# Prevent multiple instances
if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Already running (PID $OLD_PID). Exiting."
        exit 1
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"; exit' EXIT INT TERM

log "=== Ping Listener Started (PID $$) ==="

# Wait for network (max 5 min)
if [ "$WAIT_FOR_NETWORK" = true ]; then
    N=0; while [ $N -lt 30 ] && ! ping -c 1 -W 3 ntfy.sh >/dev/null 2>&1; do N=$((N+1)); sleep 10; done
fi

# Subscribe to the topic using JSON stream (more reliable on Android than SSE)
# Stream messages and react to "ping"
while true; do
    # Only respond to messages arriving from now onward
    SINCE=$(date +%s)
    if [ -f "$LAST_TIME_FILE" ]; then
        SINCE=$(cat "$LAST_TIME_FILE")
    fi
    log "Subscribing to topic: ${NTFY_TOPIC} (since=${SINCE})..."

    curl -fNsS "${NTFY_URL}/json?since=${SINCE}&poll=0" 2>> "$LOG_FILE" | while read -r line; do
        # Skip empty lines and non-message events
        EVENT=$(echo "$line" | grep -o '"event":"[^"]*"' | sed 's/"event":"//;s/"$//')
        if [ "$EVENT" != "message" ]; then
            continue
        fi

        # Extract message ID and time for deduplication / reconnection
        MSG_ID=$(echo "$line" | grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"$//')
        MSG_TIME=$(echo "$line" | grep -o '"time":[0-9]*' | sed 's/"time"://')

        # Save timestamp for reconnect
        [ -n "$MSG_TIME" ] && echo "$MSG_TIME" > "$LAST_TIME_FILE"

        # Skip if we already processed this message
        if [ -n "$MSG_ID" ] && [ -f "$LAST_ID_FILE" ]; then
            LAST_ID=$(cat "$LAST_ID_FILE")
            if [ "$MSG_ID" = "$LAST_ID" ]; then
                log "Skipping duplicate message ID: ${MSG_ID}"
                continue
            fi
        fi

        # Extract the message body from JSON
        MESSAGE=$(echo "$line" | grep -o '"message":"[^"]*"' | sed 's/"message":"//;s/"$//')

        if [ -z "$MESSAGE" ]; then
            continue
        fi

        log "Received message: ${MESSAGE} (ID: ${MSG_ID})"

        # Check if the message is "ping" (case-insensitive)
        LOWER_MSG=$(echo "$MESSAGE" | tr '[:upper:]' '[:lower:]')

        if [ "$LOWER_MSG" = "ping" ]; then
            log "Ping detected! Sending 'I'm on' reply..."

            # Acquire wakelock to keep network alive
            echo "ping_reply" > /sys/power/wake_lock

            # Get battery level for extra context
            LEVEL=$(dumpsys battery | grep level | awk '{print $2}')

            REPLY="I'm on! | Battery: ${LEVEL}% | $(date '+%Y-%m-%d %H:%M')"

            # Retry up to 3 times
            R=0; SENT=false
            while [ $R -lt 3 ]; do
                curl -fsS -m 10 \
                    -H "Tags:white_check_mark" \
                    -d "$REPLY" \
                    "$NTFY_URL" > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    SENT=true; break
                fi
                R=$((R+1)); sleep 5
            done

            # Release wakelock
            echo "ping_reply" > /sys/power/wake_unlock

            if [ "$SENT" = true ]; then
                log "Reply sent successfully"
                [ -n "$MSG_ID" ] && echo "$MSG_ID" > "$LAST_ID_FILE"
            else
                log "Failed to send reply after 3 attempts"
            fi
        fi
    done

    # If curl disconnects, wait and retry
    log "Connection lost. Reconnecting in 30 seconds..."
    sleep 30
done

) &
