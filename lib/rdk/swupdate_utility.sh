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
## Script to do Device Initiated Firmware Download
## Once box gets IP, check for DCMSettings.conf
## If DCMSettings.conf file is present schedule a cron job using schedule time from conf file
## Invoke deviceInitiated with no retries in this case
## If DCMSettings.conf is not present, Invoke DeviceInitiated with retry (1hr)
##################################################################

. /etc/include.properties
. /etc/device.properties

IARM_EVENT_BINARY_LOCATION=/usr/bin
if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
fi

. $RDK_PATH/utils.sh

if [ -f $RDK_PATH/t2Shared_api.sh ]; then
    source $RDK_PATH/t2Shared_api.sh
fi

#RETRY DELAY in secs
RETRY_DELAY=60
DCM_SKIP_RETRY_FLAG='/tmp/dcm_not_configured'
DCM_CONF="/tmp/DCMSettings.conf"
#Preserve active image name in /tmp/currently_running_image_name
CDL_FLASHED_IMAGE="/opt/cdl_flashed_file_name"
PREVIOUS_FLASHED_IMAGE="/opt/previous_flashed_file_name"
CURRENTLY_RUNNING_IMAGE="/tmp/currently_running_image_name"
WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"
FW_STATE_UNINITIALIZED=0
MAINT_FWDOWNLOAD_ERROR=9
MAINT_FWDOWNLOAD_INPROGRESS=15
MIB_STATUS_FILE="/opt/fwdnldstatus.txt"
WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"
SCRIPTFUNC="sh $RDK_PATH/deviceInitiatedFWDnld.sh"
## Download in progress flags
if [ "$HTTP_CDL_FLAG" == "" ]; then
    HTTP_CDL_FLAG="/tmp/device_initiated_rcdl_in_progress"
fi
dnldInProgressFlag="/tmp/.imageDnldInProgress"
DOWNLOAD_IN_PROGRESS="Download In Progress"
UPGRADE_IN_PROGRESS="Flashing In Progress"
ESTB_IN_PROGRESS="ESTB in progress"

#Log framework to print timestamp and source script name
swupdateLog()
{
    echo "`/bin/timestamp` : $0: $*"
}

eventSender()
{
    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ]; then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender $1 $2
    fi
}

if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
    abort_trap_func()
    {
       swupdateLog "Caught ABORT signal, exiting"
       if [ "x$SCRIPT_METHOD_DOWNLOAD" = "xfalse" ]; then
           cdlpid=`pidof rdkvfwupgrader`
           sig="-USR1"
       else
           # look for PID with name in $SCRIPTFUNC that has this func as parent
           cdlpid=`pgrep -d' ' -P $$ -f "$SCRIPTFUNC"`
           sig="-ABRT"
       fi
       if [ "$cdlpid" != "" ]; then
           swupdateLog "Killing $cdlpid with $sig"
           kill $sig $cdlpid
       else
           # if the downloader (rdkvfwupgrader or $SCRIPTFUNC) wasn't found and killed
           # we need to send events from here. Otherwise, the downloader sends it.
           eventSender "FirmwareStateEvent" $FW_STATE_UNINITIALIZED
           eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_ERROR
           swupdateLog "NOT Killing cdlpid"
       fi

       trap - SIGABRT
       exit 0
    }
    trap 'abort_trap_func' SIGABRT

fi

swupdateLog "Starting SoftwareUpdate Utility Script..."
triggerType=1
retry=0

if [ $# -eq 2 ]; then
    triggerType=$2
    retry=$1
fi
swupdateLog "trigger type=$triggerType and retry=$retry"

#this is to avoid posting events and state changes when deviceInitiatedFWDnld.sh is already in progress.
if [ -f /tmp/DIFD.pid ]; then
    pid=`cat /tmp/DIFD.pid`
    if [ -d /proc/$pid -a -f /proc/$pid/cmdline ]; then
        processName=`cat /proc/$pid/cmdline`
        swupdateLog "proc entry process name: $processName"
        if echo "$processName" | grep -q "deviceInitiatedFWDnld.sh\|rdkvfwupgrader"; then
            swupdateLog "[$0]: proc entry cmdline and process name matched."
            swupdateLog "device initiated firmware download is already in progress.."
            swupdateLog "So Exiting without triggering device initiated firmware download."
            t2CountNotify "SYST_INFO_FWUpgrade_Exit"
            if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
               eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_INPROGRESS
            fi
            #file lock /tmp/DIFD.pid will be cleared once first instance of deviceInitiatedFWDnld.sh is complete
            exit 0
        fi
    fi
fi

#Skip Swupdate and exit the script if any other CDL in progress
skipUpgrade=0
if [ "$DEVICE_TYPE" != "mediaclient" ] && [ -f $HTTP_CDL_FLAG ]; then
    skipUpgrade=1
elif [ "$DEVICE_TYPE" == "mediaclient" ]; then
    if [ -f $MIB_STATUS_FILE ]; then
        status=`cat $MIB_STATUS_FILE | grep "Status" | cut -d '|' -f2`
        if [ "$status" == "$DOWNLOAD_IN_PROGRESS" ] || [ "$status" == "$UPGRADE_IN_PROGRESS" ] || [ "$status" == "$ESTB_IN_PROGRESS" ]; then
            if [ -f $HTTP_CDL_FLAG ] || [ -f $dnldInProgressFlag ]; then
                skipUpgrade=1
            fi
        fi
    fi
fi

if [ $skipUpgrade -eq 1 ]; then
    swupdateLog "Device/ECM/Previous initiated firmware upgrade in progress..."
    t2CountNotify "SYST_ERR_PrevCDL_InProg"
    swupdateLog "Exiting without triggering software update utility download."
    if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
        eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_INPROGRESS
    fi
    exit 0
fi

#this is to avoid starting of deviceInitiatedFWDnld.sh from Maintenance when SW update complete from AS.
if [ -f /tmp/fw_preparing_to_reboot ]; then
    if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
        swupdateLog "Software Update is completed by AS/EPG, Exiting from device initiated firmware download."
        MAINT_FWDOWNLOAD_COMPLETE=8
        eventSender "MaintenanceMGR" $MAINT_FWDOWNLOAD_COMPLETE
    fi
    rm -rf /tmp/fw_preparing_to_reboot
    exit 0
fi

#sending the IARM event initially to set the firmware upgrade state to Uninitialized
eventSender "FirmwareStateEvent" $FW_STATE_UNINITIALIZED

if [ -f /opt/curl_progress ]; then
    rm /opt/curl_progress
fi

sed -i '/FwUpdateState|.*/d' $MIB_STATUS_FILE
echo "FwUpdateState|Uninitialized" >> $MIB_STATUS_FILE

if [ -f $CDL_FLASHED_IMAGE ]
then
    myFWVersion=`grep "^imagename" /version.txt | cut -d ':' -f2`
    cdlFlashedFileName=`cat $CDL_FLASHED_IMAGE`
    echo "$cdlFlashedFileName" | grep -q "$myFWVersion"
    if [ $? -ne 0 ]; then
        swupdateLog "Looks like previous upgrade failed but flashed image status is showing success"
        if [ -f $PREVIOUS_FLASHED_IMAGE ]; then
            prevCdlFlashedFileName=`cat $PREVIOUS_FLASHED_IMAGE`
            echo "$prevCdlFlashedFileName" | grep -q "$myFWVersion"
            if [ $? -eq 0 ]; then
                swupdateLog "Updating /tmp/currently_running_image_name with previous successful flashed imagename"
                cp $PREVIOUS_FLASHED_IMAGE $CURRENTLY_RUNNING_IMAGE
            fi
        else
            swupdateLog "Previous flashed file name not found !!! "
            swupdateLog "Updating currently_running_image_name with cdl_flashed_file_name ... "
            cp $CDL_FLASHED_IMAGE $CURRENTLY_RUNNING_IMAGE
        fi
    else
        #Save succesfully flashed file name to identify the previous flashed image for next upgrades
        cp $CDL_FLASHED_IMAGE $PREVIOUS_FLASHED_IMAGE
        cp $CDL_FLASHED_IMAGE $CURRENTLY_RUNNING_IMAGE
    fi
else
    #DELIA-20725: During  bootup with PCI image, it tries to create /tmp/currently_running_image_name from /opt/cdl_flashed_file_name which is missing results to perform CDL again for same image.
    #Hence, update the currently running imagename with from the imagename in version.txt.
    swupdateLog "cdl_flashed_file_name file not found !!! "
    swupdateLog "Updating currently_running_image_name with version.txt ..."
    currentImage=`grep "^imagename" /version.txt | cut -d ':' -f2`
    currentImage=$currentImage-signed.bin
    echo $currentImage > $PREVIOUS_FLASHED_IMAGE
    echo $currentImage > $CURRENTLY_RUNNING_IMAGE
fi

# ESTB IP address check
loop=1
while [ $loop -eq 1 ]
do
    estbIp=`getIPAddress`
    if [ "X$estbIp" == "X" ]; then
        sleep 10
    else
        if [ "$IPV6_ENABLED" = "true" ]; then
            if [ "Y$estbIp" != "Y$DEFAULT_IP" ] && [ -f $WAREHOUSE_ENV ]; then
                loop=0
            elif [ ! -f /tmp/estb_ipv4 ] && [ ! -f /tmp/estb_ipv6 ]; then
                sleep 10
            elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv4 ]; then
                sleep 10
            else
                loop=0
            fi
        else
            if [ "Y$estbIp" == "Y$DEFAULT_IP" ]; then
                 sleep 10
            else
                 loop=0
            fi
        fi
    fi
done

### main app
retryCount=0
if [ -f $DCM_SKIP_RETRY_FLAG ]; then
     swupdateLog "Device is not configured for DCM. Ignoring attemps for retrieving urn:settings:CheckSchedule:cron "
fi

RDKVFW_UPGRADER=$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.RDKFirmwareUpgrader.Enable 2>&1)
if [ -z "$RDKVFW_UPGRADER" ]; then
    RDKVFW_UPGRADER="false"
fi
DIRECTCDN=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.SWDLDirect.Enable 2>&1)
if [ -z "$DIRECTCDN" ]; then
    DIRECTCDN="false"
fi
swupdateLog "RDKFirmwareUpgrader rfc Status=$RDKVFW_UPGRADER and DIRECTCDN=$DIRECTCDN"
XCONF_BIN="/usr/bin/rdkvfwupgrader"
SCRIPT_METHOD_DOWNLOAD="true"
if [ "x$RDKVFW_UPGRADER" = "xtrue" ] && [ "$DIRECTCDN" != "true"  ]; then
    if [ -f $XCONF_BIN ]; then
        SCRIPT_METHOD_DOWNLOAD="false"
    else
        swupdateLog "Missing $XCONF_BIN, failover to script"
    fi
fi
while [ $retryCount -le 10 ] && [ ! -f $DCM_SKIP_RETRY_FLAG ] && [ "x$ENABLE_MAINTENANCE" != "xtrue" ]
do
    retryCount=$((retryCount + 1))
      if [ -f "$DCM_CONF" ] ; then
        cron=`cat $DCM_CONF | grep 'urn:settings:CheckSchedule:cron' | cut -d '=' -f2`
        if [ -n "$cron" ]; then
            if [ "x$SCRIPT_METHOD_DOWNLOAD" = "xfalse" ]; then
                $XCONF_BIN $retry $triggerType >> /opt/logs/swupdate.log 2>&1 &
                sleep 1
# wait requires the child PID for $XCONF_BIN return value to be valid
                cdlpid=`pidof rdkvfwupgrader`
                wait $cdlpid
                result=$?
                if [ $result -eq 1 ]; then
                    swupdateLog "rdkvfwupgrader return 1 so exiting"
                    exit 0
                fi
                if [ $result -ne 0 ]; then
                    swupdateLog "curl_result = $result, failover to script"
		    # Below code is reuired when download is in progress and rdkvfwupgrader crashed.
		    # In this case fall back to script is happening but it is exiting because flag is not removed
		    if [ -f $dnldInProgressFlag ]; then
			swupdateLog "rdkvfwupgrader fail or crashed. Clean $dnldInProgressFlag"
			rm -rf $dnldInProgressFlag
		    fi
		    sed -i '/FwUpdateState|.*/d' $MIB_STATUS_FILE
                    echo "FwUpdateState|Uninitialized" >> $MIB_STATUS_FILE
                    swupdateLog "Triggering failover to deviceInitiatedFWDnld.sh with no retries"
                    $SCRIPTFUNC 0 1 >> /opt/logs/swupdate.log 2>&1 &
                    wait
                    exit 0
                else
                    swupdateLog "Download return curl_result=$result"
                    exit 0
                fi
            else
                swupdateLog "Triggering deviceInitiatedFWDnld.sh with no retries"
                $SCRIPTFUNC $retry $triggerType >> /opt/logs/swupdate.log 2>&1 &
                wait
                exit 0
            fi
        else
            swupdateLog "Failed to read  'urn:settings:CheckSchedule:cron' from /tmp/DCMSettings.conf."
            if [ "x$SCRIPT_METHOD_DOWNLOAD" = "xfalse" ]; then
                $XCONF_BIN $retry $triggerType >> /opt/logs/swupdate.log 2>&1 &
                sleep 1
# wait requires the child PID for $XCONF_BIN return value to be valid
                cdlpid=`pidof rdkvfwupgrader`
                wait $cdlpid
                result=$?
                if [ $result -eq 1 ]; then
                    swupdateLog "rdkvfwupgrader return 1 so exiting"
                    exit 0
                fi
                if [ $result -ne 0 ]; then
                    swupdateLog "curl_result = $result, failover to script"
		    if [ -f $dnldInProgressFlag ]; then
			swupdateLog "rdkvfwupgrader fail or crashed. Clean $dnldInProgressFlag"
			rm -rf $dnldInProgressFlag
		    fi
		    sed -i '/FwUpdateState|.*/d' $MIB_STATUS_FILE
                    echo "FwUpdateState|Uninitialized" >> $MIB_STATUS_FILE
                    swupdateLog "Triggering failover to deviceInitiatedFWDnld.sh with no retries"
                    $SCRIPTFUNC 0 1 >> /opt/logs/swupdate.log 2>&1 &
                    wait
                    exit 0
                else
                    swupdateLog "Download return curl_result=$result"
                    exit 0
                fi
            else
                swupdateLog "Triggering deviceInitiatedFWDnld.sh with 3 retries"
                $SCRIPTFUNC $retry $triggerType >> /opt/logs/swupdate.log 2>&1 &
                wait
                exit 0
            fi
        fi
    elif [ -f $WAREHOUSE_ENV ]; then
        break
    else
        swupdateLog "$DCM_CONF file is missing."
        sleep $RETRY_DELAY
    fi
done

if [ "x$SCRIPT_METHOD_DOWNLOAD" = "xfalse" ]; then
    $XCONF_BIN $retry $triggerType >> /opt/logs/swupdate.log 2>&1 &
    sleep 1
# wait requires the child PID for $XCONF_BIN return value to be valid
    cdlpid=`pidof rdkvfwupgrader`
    wait $cdlpid
    result=$?
    if [ $result -eq 1 ]; then
        swupdateLog "rdkvfwupgrader return 1 so exiting"
        exit 0
    fi
    if [ $result -ne 0 ]; then
        swupdateLog "curl_result = $result, failover to script"
	if [ -f $dnldInProgressFlag ]; then
	    swupdateLog "rdkvfwupgrader fail or crashed. Clean $dnldInProgressFlag"
	    rm -rf $dnldInProgressFlag
	fi
	sed -i '/FwUpdateState|.*/d' $MIB_STATUS_FILE
        echo "FwUpdateState|Uninitialized" >> $MIB_STATUS_FILE
        swupdateLog "Triggering failover to deviceInitiatedFWDnld.sh with no retries"
        $SCRIPTFUNC $retry $triggerType >> /opt/logs/swupdate.log 2>&1 &
        wait
        exit 0
    fi
else
    swupdateLog "Triggering deviceInitiatedFWDnld.sh with 3 retries"
    $SCRIPTFUNC $retry $triggerType >> /opt/logs/swupdate.log 2>&1 &
    wait
    exit 0
fi
