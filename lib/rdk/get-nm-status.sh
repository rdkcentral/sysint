#!/bin/bash

LOG_FILE="/tmp/nm-conn-status.log"

log_status() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}


dbus-monitor --system "type='signal',interface='org.freedesktop.NetworkManager',member='StateChanged'" |
while read -r line; do
    if echo "$line" | grep -q "uint32"; then
        state=$(echo "$line" | awk '{print $NF}')

        # Only log for the first time
        if [ "$state" -eq 70 ]; then
            log_status "NetworkManager state changed to: $state"
            if [ -f /lib/rdk/logMilestone.sh ]; then
                 sh /lib/rdk/logMilestone.sh "INTERNET_FULLY_CONNECTED"
            fi
            break;
        fi
    fi
done
