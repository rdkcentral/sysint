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
## Script to Start Maintenance Tasks (RFC, SWUpdate, LogUpload).
##################################################################

# Sourcing
. /etc/include.properties
. /etc/device.properties
. /lib/rdk/utils.sh

COMMON_BIN_LOCATION="/usr/bin"

# Script Path
if [ -z $RDK_PATH ]; then
    RDK_PATH="/lib/rdk"
fi

# IARM Events
IARM_EVENT_BINARY_LOCATION="$COMMON_BIN_LOCATION"
if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
fi

eventSender() {
    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ]; then
        "$IARM_EVENT_BINARY_LOCATION/IARM_event_sender" "$1" "$2"
    fi
}

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib

if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
      . /opt/dcm.properties
else
      . /etc/dcm.properties
fi

# Maintenance RFC Events
MAINT_RFC_COMPLETE=2
MAINT_RFC_ERROR=3
MAINT_RFC_INPROGRESS=14

# Maintenance SWUpdate Events
MAINT_FWDOWNLOAD_COMPLETE=8
MAINT_FWDOWNLOAD_ERROR=9
MAINT_FWDOWNLOAD_INPROGRESS=15

# Maintenance LogUpload Events
MAINT_LOGUPLOAD_COMPLETE=4
MAINT_LOGUPLOAD_ERROR=5
MAINT_LOGUPLOAD_INPROGRESS=16

if [ -z "$LOG_PATH" ]; then
    if [ "$DEVICE_TYPE" = "broadband" ]; then
        LOG_PATH="/rdklogs/logs"
    else
        LOG_PATH="/opt/logs"
    fi
fi

# Log Paths
if [ "$DEVICE_TYPE" = "broadband" ]; then
    RFC_LOG_FILE="$LOG_PATH/dcmrfc.log"
else
    RFC_LOG_FILE="$LOG_PATH/rfcscript.log"
fi
LOGUPLOAD_LOG_FILE="$LOG_PATH/dcmscript.log"
SWUPDATE_LOG_FILE="$LOG_PATH/swupdate.log"

# Task Paths
RFC_BIN="$COMMON_BIN_LOCATION/rfcMgr"
RFC_SCRIPT="$RDK_PATH/RFCbase.sh"
SWUPDATE_BIN="$COMMON_BIN_LOCATION/rdkvfwupgrader"
LOGUPLOAD_SCRIPT="$RDK_PATH/uploadSTBLogs.sh"

# Log Functions
rfcLog ()
{
    echo "`/bin/timestamp` : $0: $*" >> $RFC_LOG_FILE
}

swupdateLog()
{
    echo "`/bin/timestamp` : $0: $*" >> $SWUPDATE_LOG_FILE
}

logUploadLog()
{
    echo "`/bin/timestamp` : $0: $*" >> $LOGUPLOAD_LOG_FILE
}

# On Demand Log Upload and other initializations
ON_DEMAND_LOG_UPLOAD=5
useXpkiMtlsLogupload=false
TriggerType=$2 # Marked OnDemand LogUpload for second arg
reboot_flag=0  # same as dcm log service
tftp_server=$LOG_SERVER # from dcm.properties

checkXpkiMtlsBasedLogUpload()
{
    if [ "$DEVICE_TYPE" = "broadband" ]; then
        dycredpath="/nvram/lxy"
    else
        dycredpath="/opt/lxy"
    fi

    if [ -d "$dycredpath" ] && [ -f "/usr/bin/rdkssacli" ] && { [ -f "/opt/certs/devicecert_1.pk12" ] || [ -f "/etc/ssl/certs/staticXpkiCrt.pk12" ]; }; then
        useXpkiMtlsLogupload="true"
    else
        useXpkiMtlsLogupload="false"
    fi
    logUploadLog "xpki based mtls support = $useXpkiMtlsLogupload"
}

runMaintenanceRFCTask()
{
    if [ -f "$RFC_BIN" ]; then
        rfcLog "Starting rfcMgr Binary"
        "$RFC_BIN" >> "$RFC_LOG_FILE"
        result=$?
    elif [ -f "$RFC_SCRIPT" ]; then
        rfcLog "Starting RFCBase.sh"
        sh "$RFC_SCRIPT"
        result=$?
    else
        rfcLog "No RFC Bin/ Script"
        result=-1
    fi
    # Error handling for unexpected exit codes
    if [ "$result" -ne 0 ] && [ "$result" -ne 1 ]; then
        eventSender "MaintenanceMGR" "$MAINT_RFC_ERROR"
    fi
}

runMaintenanceSWUpdateTask()
{
    if [ -f "$SWUPDATE_BIN" ]; then
        swupdateLog "Starting software update"
        "$SWUPDATE_BIN" 0 1 >> "$SWUPDATE_LOG_FILE" 2>&1 &
        result=$?
    else
        swupdateLog "SWUPDATE binary not found"
        result=-1
    fi
    if [ "$result" -ne 0 ] && [ "$result" -ne 1 ]; then
        eventSender "MaintenanceMGR" "$MAINT_FWDOWNLOAD_ERROR"
    fi
}

runMaintenanceLogUploadTask()
{
    if [ -f "$LOGUPLOAD_SCRIPT" ]; then
        logUploadLog "Starting log upload"
        upload_protocol=$(grep 'LogUploadSettings:UploadRepository:uploadProtocol' /tmp/DCMSettings.conf | cut -d '=' -f2 | sed 's/^"//; s/"$//')
        [ -z "$upload_protocol" ] && upload_protocol='HTTP'
        logUploadLog "upload_protocol: $upload_protocol"

        httplink=$(grep 'LogUploadSettings:UploadRepository:URL' /tmp/DCMSettings.conf | cut -d '=' -f2 | sed 's/^"//; s/"$//')
        if [ -n "$httplink" ]; then
            upload_httplink="$httplink"
        else
            logUploadLog "'LogUploadSettings:UploadRepository:URL' is not found in DCMSettings.conf"
        fi

        checkXpkiMtlsBasedLogUpload
        if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
            logUploadLog "opt override is present. Ignore settings from Bootstrap config"
        else
            logUploadEndpointUrl=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.LogUploadEndpoint.URL 2>/dev/null)
            [ -n "$logUploadEndpointUrl" ] && upload_httplink="$logUploadEndpointUrl"
        fi
        logUploadLog "upload_httplink: $upload_httplink"

        uploadOnReboot=0
        uploadCheck=$(grep 'urn:settings:LogUploadSettings:UploadOnReboot' /tmp/DCMSettings.conf | cut -d '=' -f2 | sed 's/^"//; s/"$//')
        if [ "$uploadCheck" = "true" ] && [ "$reboot_flag" -eq 0 ]; then
            logUploadLog "The value of 'UploadOnReboot' is 'true', executing script uploadSTBLogs.sh"
            uploadOnReboot=1
        elif [ "$uploadCheck" = "false" ] && [ "$reboot_flag" -eq 0 ]; then
            logUploadLog "The value of 'UploadOnReboot' is 'false', executing script uploadSTBLogs.sh"
        else
            logUploadLog "Nothing to do here for uploadCheck value = $uploadCheck"
        fi

        if [ -n "$TriggerType" ] && [ "$TriggerType" -eq "$ON_DEMAND_LOG_UPLOAD" ]; then
            logUploadLog "Application triggered on demand log upload"
            /bin/busybox sh $LOGUPLOAD_SCRIPT "$tftp_server" 1 1 "$uploadOnReboot" "$upload_protocol" "$upload_httplink" "$TriggerType" 2>/dev/null
            result=$?
        else
            logUploadLog "Log upload triggered from regular execution"
            nice -n 19 /bin/busybox sh $LOGUPLOAD_SCRIPT "$tftp_server" 1 1 "$uploadOnReboot" "$upload_protocol" "$upload_httplink" &
            result=$?
        fi
    else
        logUploadLog "LOGUPLOAD script not found"
        result=-1
    fi

    if [ "$result" -ne 0 ] && [ "$result" -ne 1 ]; then
        eventSender "MaintenanceMGR" "$MAINT_LOGUPLOAD_ERROR"
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
    "LOGUPLOAD")
        # Handle LOGUPLOAD Task
        runMaintenanceLogUploadTask
        logUploadLog "Log Upload Task execution done"
        ;;
    *)
        # Handle invalid arguments
        echo "Invalid Task: $1"
        echo "Usage: $0 [RFC|SWUPDATE|LOGUPLOAD]"
        exit 2
        ;;
esac
