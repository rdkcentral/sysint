#!/bin/sh

LOGFILE="/opt/logs/dns_status.log"
STATEFILE="/tmp/dns_state"
CHECK_INTERVAL=30

echo "Starting DNS monitor"

LAST_STATE="unknown"
[ -f "$STATEFILE" ] && LAST_STATE=$(cat "$STATEFILE")

# Wait for first DNS "UP"
while true; do
    if ping -c2 google.com > /dev/null 2>&1; then
        CURRENT_STATE="up"
        TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%SZ")
        echo "$TIMESTAMP - DNS first available" >> "$LOGFILE"
        echo "$CURRENT_STATE" > "$STATEFILE"
        echo "DNS UP"
        break
    fi
done

LAST_STATE="up"
while true; do
    if ping -c2  google.com > /dev/null 2>&1; then
        CURRENT_STATE="up"
    else
        CURRENT_STATE="down"
    fi

    if [ "$CURRENT_STATE" != "$LAST_STATE" ]; then
        TIMESTAMP=$(date  +"%Y-%m-%dT%H:%M:%SZ")
        echo "$TIMESTAMP - DNS state changed to $CURRENT_STATE" >> "$LOGFILE"
        echo "$CURRENT_STATE" > "$STATEFILE"
		       LAST_STATE="$CURRENT_STATE"
    fi

    sleep "$CHECK_INTERVAL"
done
