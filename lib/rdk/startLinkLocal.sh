#!/bin/sh

####################################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2024 Comcast Cable Communications Management, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
####################################################################################
# Called by udev on:
#   - Interface add (boot/hotplug)
#   - Carrier up (cable plugged in)
#   - Carrier down (cable unplugged)

LOG_FILE="/opt/logs/NMMonitor.log"

Log()
{
    echo "$(/bin/timestamp) : $0: $*" >> $LOG_FILE
}

INTERFACE="$1"
ACTION="$2"  # "add", "up", or "down"

# Validate input
if [ -z "$INTERFACE" ]; then
    Log "ERROR: No interface specified"
    exit 1
fi

PIDFILE="/var/run/avahi-autoipd.$INTERFACE.pid"

case "$ACTION" in
    add)
        # Interface just appeared - start if not running
        if pgrep -f "avahi-autoipd.*$INTERFACE" > /dev/null 2>&1; then
            Log "avahi-autoipd already running for $INTERFACE"
            exit 0
        fi
        
        # Start avahi-autoipd
        /usr/sbin/avahi-autoipd --daemonize --syslog "$INTERFACE"
        Log "Started avahi-autoipd for $INTERFACE (initial)"
        ;;
        
    up)
        # Carrier came back up (cable plugged in)
        # Kill any stale process and restart fresh for immediate IP recovery
        
        Log "Carrier UP for $INTERFACE, restarting avahi-autoipd"
       
        /usr/sbin/avahi-autoipd --kill "$INTERFACE" 2>/dev/null
 
        # Kill existing process
        if [ -f "$PIDFILE" ]; then
            OLD_PID=$(cat "$PIDFILE" 2>/dev/null)
            if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
                kill "$OLD_PID" 2>/dev/null
            fi
        fi
        sleep 0.5
        
        # Start fresh - will re-probe saved address if available
        /usr/sbin/avahi-autoipd --daemonize --syslog "$INTERFACE"
        
        if [ $? -eq 0 ]; then
            Log "Restarted avahi-autoipd for $INTERFACE (carrier up)"
        else
            Log "ERROR: Failed to restart avahi-autoipd for $INTERFACE"
        fi
        ;;
        
    down)
        # Carrier went down (cable unplugged)
        # Stop avahi-autoipd to save resources, but keep state file for fast recovery
        
        Log "Carrier DOWN for $INTERFACE, stopping avahi-autoipd"
        
        # Use avahi-autoipd's own kill (preserves state file)
        /usr/sbin/avahi-autoipd --kill "$INTERFACE" 2>/dev/null
        
        # Fallback: kill via PID file
        if [ -f "$PIDFILE" ]; then
            PID=$(cat "$PIDFILE" 2>/dev/null)
            if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
                kill "$PID" 2>/dev/null
            fi
        fi
        
        Log "Stopped avahi-autoipd for $INTERFACE"
        ;;
        
    *)
        # Backwards compatibility: if no action specified, assume "add"
        if pgrep -f "avahi-autoipd.*$INTERFACE" > /dev/null 2>&1; then
            exit 0
        fi
        
        /usr/sbin/avahi-autoipd --daemonize --syslog "$INTERFACE"
        Log "Started avahi-autoipd for $INTERFACE (compat mode)"
        ;;
esac

exit 0
