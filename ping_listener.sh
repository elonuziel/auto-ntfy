#!/system/bin/sh
# Ping Listener
# Listens to a ntfy.sh topic and replies "I'm on" when it receives a "ping" message

# Wait for system to boot
sleep 30

# Configuration
NTFY_TOPIC="YOUR_TOPIC_HERE"
NTFY_URL="https://ntfy.sh/${NTFY_TOPIC}"
LOG_FILE="/sdcard/ping_listener.log"

# Simple logging function
log() {
    echo "$(date) - $1" >> "$LOG_FILE"
}

log "=== Ping Listener Started ==="

# Subscribe to the topic using server-sent events (SSE)
# Stream messages and react to "ping"
while true; do
    log "Subscribing to topic: ${NTFY_TOPIC}..."

    curl -sN "${NTFY_URL}/sse" | while read -r line; do
        # SSE data lines start with "data: "
        case "$line" in
            data:*)
                # Extract the JSON payload
                PAYLOAD=$(echo "$line" | sed 's/^data: //')

                # Extract the message body from JSON
                # Using grep + sed since jq may not be available on Android
                MESSAGE=$(echo "$PAYLOAD" | grep -o '"message":"[^"]*"' | sed 's/"message":"//;s/"$//')

                if [ -z "$MESSAGE" ]; then
                    continue
                fi

                log "Received message: ${MESSAGE}"

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
                    else
                        log "Failed to send reply"
                    fi
                fi
                ;;
        esac
    done

    # If curl disconnects, wait and retry
    log "Connection lost. Reconnecting in 30 seconds..."
    sleep 30
done
