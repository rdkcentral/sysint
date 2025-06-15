#!/bin/bash

LOG_FILE="/tmp/nm-conn-status.log"
STATE_FILE="/tmp/last_nm_state.txt"

log_status() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Initialize last state
LAST_LOGGED_STATE=""
[ -f "$STATE_FILE" ] && LAST_LOGGED_STATE=$(cat "$STATE_FILE")

dbus-monitor --system "type='signal',interface='org.freedesktop.NetworkManager',member='StateChanged'" |
while read -r line; do
    if echo "$line" | grep -q "uint32"; then
        state=$(echo "$line" | awk '{print $NF}')
        case $state in
            10) status="ASLEEP" ;;
            20) status="DISCONNECTED" ;;
            30) status="DISCONNECTING" ;;
            40) status="CONNECTING" ;;
            50) status="CONNECTED_LOCAL" ;;
            60) status="CONNECTED_SITE" ;;
            70) status="CONNECTED_GLOBAL" ;;
            *) status="UNKNOWN ($state)" ;;
        esac

        # Only log for the first time
        if [[ "$status" == "CONNECTED_GLOBAL" && "$LAST_LOGGED_STATE" != "CONNECTED_GLOBAL" ]]; then
            log_status "NetworkManager state changed to: $status"
            echo "$status" > "$STATE_FILE"
            LAST_LOGGED_STATE="$status"
            if [ -f /lib/rdk/logMilestone.sh ]; then
                 sh /lib/rdk/logMilestone.sh "INTERNET_FULLY_CONNECTED"
            fi
        fi
    fi
done
