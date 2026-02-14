#!/system/bin/sh
# Simple Battery Monitor for Android 11
# Runs every 24 hours and sends battery status to ntfy.sh
# Place in /data/adb/service.d/ and chmod 755

# Run in background so Magisk can continue booting
(

# Give WiFi time to connect after boot
sleep 60

# Configuration
NTFY_TOPIC="YOUR_TOPIC_HERE"
NTFY_URL="https://ntfy.sh/${NTFY_TOPIC}"
WAIT_FOR_NETWORK=false  # Set to true for network check
LOG_FILE="/data/local/tmp/battery_monitor.log"
LOCK_FILE="/data/local/tmp/battery_monitor.lock"

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

# Wait for network (max 5 min)
if [ "$WAIT_FOR_NETWORK" = true ]; then
    N=0; while [ $N -lt 30 ] && ! ping -c 1 -W 3 ntfy.sh >/dev/null 2>&1; do N=$((N+1)); sleep 10; done
fi

# Main loop
while true; do
    log "Starting battery check..."
    
    # Get battery info (single call)
    BATTERY_INFO=$(dumpsys battery)
    LEVEL=$(echo "$BATTERY_INFO" | grep level | awk '{print $2}')
    STATUS=$(echo "$BATTERY_INFO" | grep status | awk '{print $2}')
    TEMP=$(echo "$BATTERY_INFO" | grep temperature | awk '{print $2}')
    
    # Convert temperature (divide by 10)
    TEMP_C=$((${TEMP:-0} / 10))
    
    # Determine status text
    case "$STATUS" in
        2) STATUS_TEXT="Charging" ;;
        3) STATUS_TEXT="Discharging" ;;
        4) STATUS_TEXT="Not Charging" ;;
        5) STATUS_TEXT="Full" ;;
        *) STATUS_TEXT="Unknown" ;;
    esac
    
    # Create simple message
    MSG="Daily Battery ${LEVEL}% | ${STATUS_TEXT} | ${TEMP_C}C | $(date '+%H:%M')"
    
    log "Battery: $LEVEL% | Status: $STATUS_TEXT | Temp: ${TEMP_C}C"
    
    # Send to ntfy.sh
    curl -fsS \
        -H "Tags:battery" \
        -d "$MSG" \
        "$NTFY_URL" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "Notification sent successfully"
    else
        log "Failed to send notification"
    fi
    
    log "Sleeping for 24 hours..."
    
    # Sleep 24 hours
    sleep 86400
done

) &
