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

##################################################################
## Script to Start Maintenance Tasks (RFC, SWUpdate).
##################################################################

# Sourcing
. /etc/include.properties
. /etc/device.properties
. /lib/rdk/utils.sh

# RDK Paths
if [ -z $RDK_PATH ]; then
    RDK_PATH="/lib/rdk"
fi
if [ -z "$LOG_PATH" ]; then
    LOG_PATH="/opt/logs"
fi
COMMON_BIN_LOCATION="/usr/bin"

# IARM Events
eventSender() {
    if [ -f $COMMON_BIN_LOCATION/IARM_event_sender ]; then
        "$COMMON_BIN_LOCATION/IARM_event_sender" "$1" "$2"
    fi
}

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib

# Maintenance RFC Events
MAINT_RFC_COMPLETE=2
MAINT_RFC_ERROR=3
MAINT_RFC_INPROGRESS=14

# Maintenance SWUpdate Events
MAINT_FWDOWNLOAD_COMPLETE=8
MAINT_FWDOWNLOAD_ERROR=9
MAINT_FWDOWNLOAD_INPROGRESS=15

# Log files
RFC_LOG_FILE="$LOG_PATH/rfcscript.log"
SWUPDATE_LOG_FILE="$LOG_PATH/swupdate.log"

# Task binaries/ scripts
RFC_BIN="$COMMON_BIN_LOCATION/rfcMgr"
SWUPDATE_BIN="$COMMON_BIN_LOCATION/rdkvfwupgrader"

# Log Functions
rfcLog ()
{
    echo "`/bin/timestamp` : $0: $*" >> $RFC_LOG_FILE
}

swupdateLog()
{
    echo "`/bin/timestamp` : $0: $*" >> $SWUPDATE_LOG_FILE
}

# Utility Function
runMaintenanceRFCTask()
{
    if [ -f "$RFC_BIN" ]; then
        rfcLog "Starting rfcMgr Binary"
        "$RFC_BIN" >> "$RFC_LOG_FILE"
        result=$?
    else
        rfcLog "No RFC Bin/ Script"
        result=-1
    fi
    # Handle both success (0) and acceptable warning (1) exit codes, flag other results as errors
    if [ "$result" -ne 0 ] && [ "$result" -ne 1 ]; then
        eventSender "MaintenanceMGR" "$MAINT_RFC_ERROR"
    fi
}

runMaintenanceSWUpdateTask()
{
    if [ -f "$SWUPDATE_BIN" ]; then
        swupdateLog "Starting software update"
        "$SWUPDATE_BIN" 0 1 >> "$SWUPDATE_LOG_FILE" 2>&1 &
        sleep 1
        cdlpid=$(pidof rdkvfwupgrader)
        wait $cdlpid
        result=$?
        if [ "$result" -eq 1 ]; then
            result=-1
        else
            result=1
        fi
    else
        swupdateLog "SWUPDATE binary not found"
        result=-1
    fi
    # Handle both success (0) and acceptable warning (1) exit codes, flag other results as errors
    if [ "$result" -ne 0 ] && [ "$result" -ne 1 ]; then
        eventSender "MaintenanceMGR" "$MAINT_FWDOWNLOAD_ERROR"
    fi
}

################
# Main App
################
case "$1" in
    "RFC")
        # RFC Task
        runMaintenanceRFCTask
        rfcLog "RFC Task execution done"
        ;;
    "SWUPDATE")
        # Handle SWUPDATE Task
        runMaintenanceSWUpdateTask
        swupdateLog "SWUpdate Task execution done"
        ;;
    *)
        # Handle invalid arguments
        echo "Invalid Task: $1"
        echo "Usage: $0 [RFC|SWUPDATE]"
        exit 2
        ;;
esac


