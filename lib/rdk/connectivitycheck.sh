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

. /etc/include.properties
. /etc/device.properties

if [ "$DEVICE_TYPE" == "mediaclient" ]; then
    . /etc/common.properties
fi 

# DT_TIME=$(date +'%Y-%m-%d:%H:%M:%S:%6N')
# echo "$DT_TIME From connectivitycheck.sh" >> /opt/logs/NMMonitor.log
CONNCHECK_LOG_FILE="$LOG_PATH/NMMonitor.log"
connectivityCheckLog()
{
    echo "$(/bin/timestamp) : $0: $*" >> $CONNCHECK_LOG_FILE
}

if [ -n "$CONNECTIVITY_CHECK_URL" ]; then
    URL="$CONNECTIVITY_CHECK_URL"
else
    connectivityCheckLog "CONNECTIVITY_CHECK_URL not set. Exiting."
    exit 0
fi

TIMEOUT=120   # 2 minutes
INTERVAL=10    # 10 seconds

# Get start time from /proc/uptime (integer part only)
START=$(cut -d. -f1 /proc/uptime)

while true; do
    NOW=$(cut -d. -f1 /proc/uptime)
    ELAPSED=$((NOW - START))
    #sleep 60 #Use for testing
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        connectivityCheckLog "connectivitycheck.sh Failed to get HTTP 204 within $TIMEOUT seconds."
        # Add Telemetry
        exit 0
    fi

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

    if [ "$HTTP_CODE" -eq 204 ]; then
        connectivityCheckLog "connectivitycheck.sh  Connected: Received HTTP 204"
        # Add Telemetry
        exit 0
    else
        connectivityCheckLog "connectivitycheck.sh Not connected yet (HTTP $HTTP_CODE). Retrying in $INTERVAL seconds..."
    fi

    sleep $INTERVAL
done
