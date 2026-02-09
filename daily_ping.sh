#!/system/bin/sh
# Simple notify
# Runs every 24 hours and sends battery status to ntfy.sh

# Wait for system to boot
sleep 60

# Configuration
NTFY_URL="https://ntfy.sh/INSERT_YOUR_TOPIC_HERE"
LOG_FILE="/sdcard/battery_monitor.log"

# Simple logging function
log() {
    echo "$(date) - $1" >> "$LOG_FILE"
}

log "=== Battery Monitor Started ==="

# Main loop
while true; do
    log "Starting battery check..."
    
    # Get battery level using simple method
    LEVEL=$(dumpsys battery | grep level | awk '{print $2}')
    STATUS=$(dumpsys battery | grep status | awk '{print $2}')
    TEMP=$(dumpsys battery | grep temperature | awk '{print $2}')
    
    # Convert temperature (divide by 10)
    TEMP_C=$((TEMP / 10))
    
    # Determine status text
    case "$STATUS" in
        2) STATUS_TEXT="Charging" ;;
        3) STATUS_TEXT="Discharging" ;;
        5) STATUS_TEXT="Full" ;;
        *) STATUS_TEXT="Unknown" ;;
    esac
    
    # Create simple message
    MSG="Battery: ${LEVEL}%
Status: ${STATUS_TEXT}
Temperature: ${TEMP_C}°C
Time: $(date '+%H:%M')"
    
    log "Battery: $LEVEL% | Status: $STATUS_TEXT | Temp: ${TEMP_C}C"
    
    # Send to ntfy.sh
    curl -s \
        -H "Title: 🔋 Battery ${LEVEL}%" \
        -H "Tags: battery" \
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