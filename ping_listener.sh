#!/system/bin/sh
# Ping Listener
# Listens to a ntfy.sh topic and replies "I'm on" when it receives a "ping" message

# Wait for system to boot
sleep 30

# Configuration
NTFY_TOPIC="YOUR_TOPIC_HERE"
NTFY_URL="https://ntfy.sh/${NTFY_TOPIC}"
LOG_FILE="/sdcard/ping_listener.log"
LOCK_FILE="/sdcard/ping_listener.lock"
LAST_ID_FILE="/sdcard/ping_listener_lastid"

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

# Subscribe to the topic using JSON stream (more reliable on Android than SSE)
# Stream messages and react to "ping"
while true; do
    log "Subscribing to topic: ${NTFY_TOPIC}..."

    curl -sN "${NTFY_URL}/json" 2>> "$LOG_FILE" | while read -r line; do
        # Skip empty lines and non-message events
        EVENT=$(echo "$line" | grep -o '"event":"[^"]*"' | sed 's/"event":"//;s/"$//')
        if [ "$EVENT" != "message" ]; then
            continue
        fi

        # Extract message ID for deduplication
        MSG_ID=$(echo "$line" | grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"$//')

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

            # Get battery level for extra context
            LEVEL=$(dumpsys battery | grep level | awk '{print $2}')

            REPLY="📱 I'm on!
Battery: ${LEVEL}%
Time: $(date '+%Y-%m-%d %H:%M')"

            curl -s \
                -H "Title: ✅ Device Online" \
                -H "Tags: white_check_mark" \
                -d "$REPLY" \
                "$NTFY_URL" >> "$LOG_FILE" 2>&1

            if [ $? -eq 0 ]; then
                log "Reply sent successfully"
                # Save message ID to prevent duplicates
                [ -n "$MSG_ID" ] && echo "$MSG_ID" > "$LAST_ID_FILE"
            else
                log "Failed to send reply"
            fi
        fi
    done

    # If curl disconnects, wait and retry
    log "Connection lost. Reconnecting in 30 seconds..."
    sleep 30
done
