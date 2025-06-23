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

if [ -f /lib/rdk/t2Shared_api.sh ]; then
      source /lib/rdk/t2Shared_api.sh
fi

CONNCHECK_LOG_FILE="$LOG_PATH/NMMonitor.log"
CONNCHECK_FILE="/tmp/connectivity_check_done
"
CONNCHECK_TIMEOUT=120   # 2 minutes
CONNCHECK_RETRY_INTERVAL=10    # 10 seconds

connectivityCheckLog()
{
    echo "$(/bin/timestamp) : $0: $*" >> $CONNCHECK_LOG_FILE
}

if [ -n "$CONNECTIVITY_CHECK_URL" ]; then
    URL="$CONNECTIVITY_CHECK_URL"
else
    connectivityCheckLog "CONNECTIVITY_CHECK_URL not set. Exiting."
    if [ ! -f $CONNCHECK_FILE ]; then
        touch $CONNCHECK_FILE
    fi
    t2CountNotify "SYST_WARN_connectivitycheck_nourl_set"
    exit 0
fi

# Get start time from /proc/uptime (integer part only)
START=$(cut -d. -f1 /proc/uptime)

while true; do
    NOW=$(cut -d. -f1 /proc/uptime)
    ELAPSED=$((NOW - START))

    if [ "$ELAPSED" -ge "$CONNCHECK_TIMEOUT" ]; then
        connectivityCheckLog "Failed to get HTTP 204 within $CONNCHECK_TIMEOUT seconds."
        if [ ! -f $CONNCHECK_FILE ]; then
            touch $CONNCHECK_FILE
        fi
        t2CountNotify "SYST_WARN_connectivitycheck_time_expire"
        exit 0
    fi

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")

    if [ "$HTTP_CODE" -eq 204 ]; then
        connectivityCheckLog "Connected: Received HTTP 204"
        if [ ! -f $CONNCHECK_FILE ]; then
            touch $CONNCHECK_FILE
        fi
        t2CountNotify "SYST_INFO_connectivitycheck_success"
        exit 0
    else
        connectivityCheckLog "connectivitycheck.sh Not connected yet (HTTP $HTTP_CODE). Retrying in $INTERVAL seconds..."
    fi

    sleep $CONNCHECK_RETRY_INTERVAL
done
