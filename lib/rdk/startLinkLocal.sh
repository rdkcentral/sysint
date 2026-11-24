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

# Include File check
if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

LOG_FILE="/opt/logs/NMMonitor.log"

Log()
{
    echo "$(/bin/timestamp) : $0: $*" >> "$LOG_FILE"
}

INTERFACE="$1"

# Validate input and restrict to eth0 or wlan0
if [ -z "$INTERFACE" ]; then
    Log "ERROR: No interface specified"
    exit 1
fi

if [ "$INTERFACE" != "$ETHERNET_INTERFACE" ] && [ "$INTERFACE" != "$WIFI_INTERFACE" ]; then
    Log "INFO: Link-local not started for $INTERFACE (only eth0 and wlan0 allowed)"
    exit 0
fi

# Interface just appeared - start if not running
if pgrep -f "avahi-autoipd.*$INTERFACE" > /dev/null 2>&1; then
    Log "avahi-autoipd already running for $INTERFACE"
    exit 0
fi

# Start avahi-autoipd
/usr/sbin/avahi-autoipd --daemonize --syslog "$INTERFACE"
Log "Started avahi-autoipd for $INTERFACE"
exit 0
