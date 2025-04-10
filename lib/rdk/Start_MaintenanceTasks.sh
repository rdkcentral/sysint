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

COMMON_BIN_LOCATION=/usr/bin

# Script Path
if [ -z $RDK_PATH ]; then
    RDK_PATH="/lib/rdk"
fi

# IARM Events
IARM_EVENT_BINARY_LOCATION=$COMMON_BIN_LOCATION
if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
fi

eventSender() {
    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ]; then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender $1 $2
    fi
}

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib

if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
      . /opt/dcm.properties
else
      . /etc/dcm.properties
fi

# Maintenance Events
# RFC Events
MAINT_RFC_COMPLETE=2
MAINT_RFC_ERROR=3
MAINT_RFC_INPROGRESS=14

# SWUpdate Events
MAINT_FWDOWNLOAD_COMPLETE=8
MAINT_FWDOWNLOAD_ERROR=9
MAINT_FWDOWNLOAD_INPROGRESS=15

# LogUpload Events
MAINT_LOGUPLOAD_COMPLETE=4
MAINT_LOGUPLOAD_ERROR=5
MAINT_LOGUPLOAD_INPROGRESS=16

if [ -z $LOG_PATH ]; then
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
RFC_SCRIPT="$RDK_PATH/RFCbase.sh"
RFC_SCRIPT_CALL="sh $RFC_SCRIPT"
RFC_BIN="$COMMON_BIN_LOCATION/rfcMgr"

SWUPDATE_BIN="$COMMON_BIN_LOCATION/rdkvfwupgrader"
SWUPDATE_BIN_CALL="$SWUPDATE_BIN 0 1"

LOGUPLOAD_SCRIPT="$RDK_PATH/uploadSTBLogs.sh"
LOGUPLOAD_SCRIPT_CALL="sh $LOGUPLOAD_SCRIPT"

# Log Functions
rfcLog ()
{
    echo "`/bin/timestamp` : $0: $*" >> $RFC_LOG_FILE
}

logUploadLog()
{
    echo "`/bin/timestamp` : $0: $*" >> $LOGUPLOAD_LOG_FILE
}

swupdateLog()
{
    echo "`/bin/timestamp` : $0: $*" >> $SWUPDATE_LOG_FILE
}

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

    if [ -d $dycredpath ] && [ -f /usr/bin/rdkssacli ] && [ -f /opt/certs/devicecert_1.pk12 -o -f /etc/ssl/certs/staticXpkiCrt.pk12 ]; then
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
    elif [ -f "RFC_SCRIPT" ]; then
        rfcLog "Starting RFCBase.sh"
        "$RFC_SCRIPT_CALL"
        result=$?
    else
        rfcLog "No RFC Bin/ Script"
        result=-1
    fi
    # Error handling for unexpected exit codes
    if [ "$result" -ne 0 ] && [ "$result" -ne 1 ]; then
        eventSender "MaintenanceMGR" "$MAINT_RFC_ERROR"
    fi
    rfcLog "RFC Task execution done"
}

runMaintenanceSWUpdateTask()
{
    if [ -f "$SWUPDATE_BIN" ]; then
        swupdateLog "Starting software update"
        "$SWUPDATE_BIN" >> "$SWUPDATE_LOG_FILE"
        result=$?
    else
        swupdateLog "SWUPDATE binary not found"
        result=$?
    fi
    swupdateLog "swupdate script execution done"
}

runMaintenanceLogUploadTask()
{
    if [ -f "$LOGUPLOAD_SCRIPT" ]; then
        logUploadLog "Starting log upload"
        upload_protocol=`cat /tmp/DCMSettings.conf | grep 'LogUploadSettings:UploadRepository:uploadProtocol' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
        if [ -n "$upload_protocol" ]; then
            logUploadLog "upload_protocol: $upload_protocol"
        else
            upload_protocol='HTTP'
            logUploadLog "'urn:settings:LogUploadSettings:Protocol' is not found in DCMSettings.conf"
        fi

        if [ "$upload_protocol" == "HTTP" ]; then
            httplink=`cat /tmp/DCMSettings.conf | grep 'LogUploadSettings:UploadRepository:URL' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
            if [ -z "$httplink" ]; then
                logUploadLog "'LogUploadSettings:UploadRepository:URL' is not found in DCMSettings.conf, upload_httplink is '$upload_httplink'"
            else
                upload_httplink=$httplink
                logUploadLog "upload_httplink is $upload_httplink"
            fi
            logUploadLog "MTLS preferred"
            checkXpkiMtlsBasedLogUpload
            if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
                logUploadLog "opt override is present. Ignore settings from Bootstrap config"
            else
                logUploadEndpointUrl=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.LogUploadEndpoint.URL 2>&1 > /dev/null)
                if [ "$logUploadEndpointUrl" ]; then
                    upload_httplink="$logUploadEndpointUrl"
                    logUploadLog "Setting upload_httplink to $upload_httplink from Bootstrap config logUploadEndpointUrl:$logUploadEndpointUrl"
                fi
            fi
            logUploadLog "upload_httplink is $upload_httplink"
        fi
        uploadOnReboot=0
        uploadCheck=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:UploadOnReboot' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
        if [ "$uploadCheck" == "true" ] && [ "$reboot_flag" == "0" ]; then
            # Execute /sysint/uploadSTBLogs.sh with arguments $tftp_server and 1
            logUploadLog "The value of 'UploadOnReboot' is 'true', executing script uploadSTBLogs.sh"
            uploadOnReboot=1    
        elif [ "$uploadCheck" == "false" ] && [ "$reboot_flag" == "0" ]; then
            # Execute /sysint/uploadSTBLogs.sh with arguments $tftp_server and 1
            logUploadLog "The value of 'UploadOnReboot' is 'false', executing script uploadSTBLogs.sh"    
        else 
            logUploadLog "Nothing to do here for uploadCheck value = $uploadCheck" 
        fi
        if [ ! -z "$TriggerType" ] && [ $TriggerType -eq $ON_DEMAND_LOG_UPLOAD ]; then
            # Appp triggered log upload call waits for return status to determine SUCCESS or FAILURE
            # Run with priority in foreground as UI will be waiting for further steps
            logUploadLog "Application triggered on demand log upload"
            /bin/busybox $LOGUPLOAD_SCRIPT_CALL $tftp_server 1 1 $uploadOnReboot $upload_protocol $upload_httplink $TriggerType 2> /dev/null
            result=$?
        else
            logUploadLog "Log upload triggered from regular execution"
            nice -n 19 /bin/busybox $LOGUPLOAD_SCRIPT_CALL $tftp_server 1 1 $uploadOnReboot $upload_protocol $upload_httplink &
            result=$?
        fi
    else
        logUploadLog "LOGUPLOAD script not found"
        result=-1
    fi

    if [ $result -ne 0 ] && [ $result -ne 1 ]; then
        eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
    fi
    logUploadLog "Log Upload Task execution done"
}

################
# Main App
################
case "$1" in
    "RFC")
        # RFC Task
        runMaintenanceRFCTask
        ;;
    "SWUPDATE")
        # Handle SWUPDATE Task
        runMaintenanceSWUpdateTask
        ;;
    "LOGUPLOAD")
        # Handle LOGUPLOAD Task
        runMaintenanceLogUploadTask
        ;;
    *)
        # Handle invalid arguments
        echo "Invalid argument: $1"
        echo "Usage: $0 [RFC|SWUPDATE|LOGUPLOAD]"
        exit 2
        ;;
esac
