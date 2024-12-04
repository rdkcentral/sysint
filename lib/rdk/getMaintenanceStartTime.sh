#!/bin/sh
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
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
##############################################################################

######################################################################
##    * Get maintenance start time from RDK maintenance conf file
########################################################################

. /etc/include.properties
. /etc/device.properties

#############################################################
##                  Variables
#############################################################

OPT_START_TIME_FILE="${PERSISTENT_PATH}/maintainence_start_time.txt"
RDK_MAINTENANCE_CONF="${PERSISTENT_PATH}/rdk_maintenance.conf"

IARM_EVENT_BINARY_LOCATION="/usr/bin"
IARM_BUS_DCM_NEW_START_TIME_EVENT=1

#############################################################
##                 Function
##############################################################

notify_MaintenanceMGR()
{
    if [ -f "${IARM_EVENT_BINARY_LOCATION}/IARM_event_sender" ]; then
        ${IARM_EVENT_BINARY_LOCATION}/IARM_event_sender "MaintenanceMGR" $1 $2
    fi
}

calculate_start_time()
{
    # Convert cron time to seconds
    cron_time_in_sec=$((start_hr*60*60 + start_min*60))

    if [ -n "$tz_mode" -a "$tz_mode" = "Local time" ]; then
        # echo "`/bin/timestamp` Timezone mode is ${tz_mode}" >> $LOG_PATH/dcmscript.log

        # Fetch the required offset based on timezone
        tz_offset=$(sh -c "TZ=\"$zoneValue\" date +'%z'")
        tz_offset_pos="$(echo $tz_offset | cut -c1)"
        tz_offset_hr="$(echo $tz_offset | cut -c2-3)"
        tz_offset_min="$(echo $tz_offset | cut -c4-)"

        # Remove leading zeros if any to avoid bash expression errors
        tz_offset_hr=$(echo $tz_offset_hr | awk '{print $1 + 0}')
        tz_offset_min=$(echo $tz_offset_min | awk '{print $1 + 0}')

        # Convert offset to seconds
        tz_offset_in_sec=$((tz_offset_hr*60*60+tz_offset_min*60))

        # Apply offset to cron time
        if [ "$tz_offset_pos" = "-" ]; then
            # echo "`/bin/timestamp` UTC is ahead of device timezone. Hence adding offset to cron time" >> $LOG_PATH/dcmscript.log
            start_time_in_sec=$((cron_time_in_sec+tz_offset_in_sec))
        else
            # echo "`/bin/timestamp` UTC is behind device timezone. Hence removing offset from cron time" >> $LOG_PATH/dcmscript.log
            start_time_in_sec=$((cron_time_in_sec-tz_offset_in_sec))
        fi
    else
        # echo "`/bin/timestamp` Timezone mode is UTC" >> $LOG_PATH/dcmscript.log

        if [ "$DEVICE_NAME" = "PLATCO" ]; then
            tz_offset=$timeZoneOffset
            tz_offset_in_sec=$(($timeZoneOffset*60*60))
        fi

        start_time_in_sec=$((cron_time_in_sec+tz_offset_in_sec))
    fi

    # Avoid cron to be set beyond 24 hr clock limit
    # NOTE: In ideal scenarios, this is not expected but still handling it
    if [ "$start_time_in_sec" -ge 86400 ]
    then
        start_time_in_sec=$((start_time_in_sec-86400))
    elif [ "$start_time_in_sec" -le 0 ]
    then
        start_time_in_sec=$((start_time_in_sec+86400))
    fi

    start_time=$start_time_in_sec
    start_time_sec=$((start_time%60))
    start_time=$((start_time/60))
    start_time_min=$((start_time%60))
    start_time=$((start_time/60))
    start_time_hr=$((start_time%60))

    echo "`/bin/timestamp` timeZoneOffset: $tz_offset , start_time_hr: $start_time_hr, start_time_min: $start_time_min, start_time_sec: $start_time_sec" >> $LOG_PATH/dcmscript.log

    calc_epoch=$(date -u "+%s" -d $start_time_hr:$start_time_min:$start_time_sec)
    curr_epoch=$(date -u "+%s")
    sec=$((calc_epoch-curr_epoch))

    if [ $sec -le 0 ]; then
        echo "`/bin/timestamp` Calculated start time ($calc_epoch) is in the past, bumping by 24hrs" >> $LOG_PATH/dcmscript.log
        calc_epoch=$((calc_epoch+86399))
    fi

    echo "`/bin/timestamp` Maintenance start time: $calc_epoch" >> $LOG_PATH/dcmscript.log
    echo $calc_epoch
}


#############################################################
##                  Main
############################################################

if [ -f "$OPT_START_TIME_FILE" ]; then
    # echo "`/bin/timestamp` Removing $OPT_START_TIME_FILE file since it is obsolete" >> $LOG_PATH/dcmscript.log
    rm -rf "$OPT_START_TIME_FILE"
fi

if [ -f "$RDK_MAINTENANCE_CONF" ]; then
    . $RDK_MAINTENANCE_CONF
else
    echo "`/bin/timestamp` $RDK_MAINTENANCE_CONF file not found. Cannot fetch maintenance start time" >> $LOG_PATH/dcmscript.log
    echo -1
    exit -1
fi

. ${RDK_PATH}/getTimeZone.sh &> /dev/null
echo "`/bin/timestamp` Start time got from persistent file : $start_hr:$start_min tz_mode: $tz_mode timezone: $zoneValue" >> $LOG_PATH/dcmscript.log
start_epoch=$(calculate_start_time)
#notify_MaintenanceMGR "$IARM_BUS_DCM_NEW_START_TIME_EVENT" "$start_epoch" >> $LOG_PATH/dcmscript.log 2>&1
echo $start_epoch
exit 0
