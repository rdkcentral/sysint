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

. /etc/include.properties
. /etc/device.properties

if [ -f "$RDK_PATH/utils.sh" ]; then
    . $RDK_PATH/utils.sh
fi

# override evn if RFC desires
if [ -f $RDK_PATH/rfcOverrides.sh ]; then
    . $RDK_PATH/rfcOverrides.sh
fi

if [ -f $RDK_PATH/t2Shared_api.sh ]; then
    source $RDK_PATH/t2Shared_api.sh
fi

LOG_FILE=$LOG_PATH/"swupdate.log"
TLS_LOG_FILE="$LOG_PATH/tlsError.log"

IARM_EVENT_BINARY_LOCATION=/usr/bin
if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
fi

#Firmware Download states
IMAGE_FWDNLD_UNINITIALIZED=0
IMAGE_FWDNLD_DOWNLOAD_INPROGRESS=1
IMAGE_FWDNLD_DOWNLOAD_COMPLETE=2
IMAGE_FWDNLD_DOWNLOAD_FAILED=3
IMAGE_FWDNLD_FLASH_INPROGRESS=4
IMAGE_FWDNLD_FLASH_COMPLETE=5
IMAGE_FWDNLD_FLASH_FAILED=6

#Firmware Upgrade states
FW_STATE_REQUESTING=1
FW_STATE_DOWNLOADING=2
FW_STATE_FAILED=3
FW_STATE_DOWNLOAD_COMPLETE=4
FW_STATE_VALIDATION_COMPLETE=5
FW_STATE_PREPARING_TO_REBOOT=6

#Upgrade events
FirmwareStateEvent="FirmwareStateEvent"
ImageDwldEvent="ImageDwldEvent"

## Flag to indicate RCDL is in progress
RCDL_FLAG="/tmp/device_initiated_rcdl_in_progress"       
DNDL_INPROGRESS_FLAG="/tmp/.imageDnldInProgress"         

# File to save http code
CURL_INFO="/tmp/rcdl_curl_info"

DnldURLvalue="/opt/.dnldURL"

RETRY_COUNT=3
CB_RETRY_COUNT=1
DIRECT_BLOCK_FILENAME="/tmp/.lastdirectfail_userdl"
CB_BLOCK_FILENAME="/tmp/.lastcodebigfail_userdl"

IMAGE_FILE_NAME="/tmp/rcdlImageName.txt"
IMAGE_PATH="/tmp/rcdlImageLocation.txt"

DEFER_REBOOT_STATUS_FILE="/tmp/rcdldeferReboot.txt"
DEFER_REBOOT=0

cloudProto="http"
REBOOT_PENDING_DELAY=3
isMmgbleNotifyEnabled=$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.ManageableNotification.Enable 2>&1 > /dev/null)
DAC15_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.DAC15CDLUrl 2>&1)
WEBPACDL_TR181_NAME="Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.NonPersistent.WebPACDL.Enable"
if [ -z "$DAC15_URL" ]; then
    DAC15_URL="$DAC15DEFAULT"
fi

#setting TLS value only for Yocto builds
TLS=""
if [ -f /etc/os-release ]; then
    TLS="--tlsv1.2"
fi

CURL_TLS_TIMEOUT=30

#Support for firmware download via codebig
REQUEST_TYPE_FOR_CODEBIG_URL=14

FOUR_CMDLINE_PARAMS=4

#Log framework to print timestamp and source script name
swupdateLog()
{
    echo "`/bin/timestamp` : $0: $*" >> $LOG_FILE
}

tlsLog()
{
    echo "`/bin/timestamp` : $0: $*" >> $TLS_LOG_FILE
}

#Cert ops STB Red State recovery RDK-30717
stateRedFlag="/tmp/stateRedEnabled"
stateRedSprtFile="/lib/rdk/stateRedRecovery.sh"

#isStateRedSupported; check if state red supported
isStateRedSupported()
{
    stateRedSupport=0
    if [ -f $stateRedSprtFile ]; then
        stateRedSupport=1
    else
        stateRedSupport=0
    fi
    return $stateRedSupport
}

#isInStateRed state red status, if set ret 1
#stateRed is local to function
isInStateRed()
{
    stateRed=0
    isStateRedSupported
    stateSupported=$?
    if [ $stateSupported -eq 0 ]; then
         return $stateRed
    fi

    if [ -f $stateRedFlag ]; then
        stateRed=1
    fi
    return $stateRed
}

# checkAndEnterStateRed <curl return code> - enter state red on SSL related error code
checkAndEnterStateRed()
{
    curlReturnValue=$1

    isStateRedSupported
    stateSupported=$?
    if [ $stateSupported -eq 0 ]; then
         return
    fi

    isInStateRed
    stateRedflagset=$?
    if [ $stateRedflagset -eq 1 ]; then
        swupdateLog "checkAndEnterStateRed: Device State Red Recovery Flag already set"
        stateRedRecoveryUrl=$recoveryURL
        return
    fi

    #Enter state red on ssl or cert errors
    case $curlReturnValue in
    35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
        rm -f $DIRECT_BLOCK_FILENAME
        rm -f $CB_BLOCK_FILENAME
        touch $stateRedFlag
        swupdateLog "checkAndEnterStateRed: Curl SSL/TLS error ($curlReturnValue). Set state Red and Exit"
        t2ValNotify "CDLrdkportal_split" "$curlReturnValue"
        if [ -f $stateRedFlag ]; then 
             tlsLog "checkAndEnterStateRed: State Red Recovery Flag Set!!!"
             tlsLog "checkAndEnterStateRed: Triggering State Red Recovery Service!!!"
        fi
        exit 1
    ;;
    esac
}
#ends Red state recovery

IsDirectBlocked()
{
    directret=0
    if [ -f $DIRECT_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $DIRECT_BLOCK_FILENAME)))
        remtime=$(($modtime/3600))
        if [ "$modtime" -le "$DIRECT_BLOCK_TIME" ]; then
            swupdateLog "Last direct failed blocking is still valid for $remtime hrs, preventing direct"
            directret=1
        else
            swupdateLog "Last direct failed blocking has expired, removing $DIRECT_BLOCK_FILENAME, allowing direct"
            rm -f $DIRECT_BLOCK_FILENAME
        fi
    fi
    return $directret
}

IsCodeBigBlocked()
{
    codebigret=0
    if [ -f $CB_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $CB_BLOCK_FILENAME)))
        cbremtime=$(($modtime/60))
        if [ "$modtime" -le "$CB_BLOCK_TIME" ]; then
            swupdateLog "Last Codebig failed blocking is still valid for $cbremtime mins, preventing Codebig"
            codebigret=1
        else
            swupdateLog "Last Codebig failed blocking has expired, removing $CB_BLOCK_FILENAME, allowing Codebig"
            rm -f $CB_BLOCK_FILENAME
        fi
    fi
    return $codebigret
}

getCodebigUrl()
{
    request_type=$REQUEST_TYPE_FOR_CODEBIG_URL
    json_str='/Images''/$UpgradeFile'
    if [ "$domainName" == "$DAC15_URL" ]; then
        request_type=14
    fi
    sign_cmd="GetServiceUrl $request_type \"$json_str\""
    eval $sign_cmd > /tmp/.signedRequest
    if [ -s /tmp/.signedRequest ]
    then
        swupdateLog "GetServiceUrl success"
    else
        swupdateLog "GetServiceUrl failed"
        exit 1
    fi
    cb_signed_request=`cat /tmp/.signedRequest`
    rm -f /tmp/.signedRequest
}

eventManager()
{
    # Disable the event updates if PDRI upgrade
    if [ "$disableStatsUpdate" == "yes" ]; then
        return 0
    fi

    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ]; then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender $1 $2
    else
        swupdateLog "Missing the binary $IARM_EVENT_BINARY_LOCATION/IARM_event_sender"
    fi
}

Trigger_RebootPendingNotify()
{
    #Trigger RebootPendingNotification prior to device reboot for all software managed types of reboots
    swupdateLog "RDKV_REBOOT : Setting RebootPendingNotification before reboot"
    tr181 -s -v $REBOOT_PENDING_DELAY Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.RebootPendingNotification
    swupdateLog "RDKV_REBOOT  : RebootPendingNotification SET succeeded"
}

## Function to update firmware download status
updateFWDnldStatus()
{
    FW_DNLD_STATUS_FILE="/opt/fwdnldstatus.txt"

    proto=$1
    status=$2
    failureReason=$3
    DnldVersn=$4
    DnldFile=$5
    LastRun=$6
    Codebig=$7
    DnldPercent=""
    LastSuccessfulRun=`grep LastSuccessfulRun $FW_DNLD_STATUS_FILE | cut -d '|' -f2`
    CurrentVersion=`grep imagename /version.txt | cut -d':' -f2`
    CurrentFile=`cat /tmp/currently_running_image_name`
    LastSuccessfulUpgradeFile=`cat /opt/cdl_flashed_file_name`
    reboot="true"
    fwUpdateState=$8
    if [ "$DEFER_REBOOT" = "1" ];then
        reboot="false"
    fi

    if [ -f $FW_DNLD_STATUS_FILE ]
    then
        rm $FW_DNLD_STATUS_FILE
    fi
    touch $FW_DNLD_STATUS_FILE

    echo "Proto|$proto" >> $FW_DNLD_STATUS_FILE
    echo "Status|$status" >> $FW_DNLD_STATUS_FILE
    echo "Reboot|$reboot" >> $FW_DNLD_STATUS_FILE
    echo "FailureReason|$failureReason" >> $FW_DNLD_STATUS_FILE
    echo "DnldVersn|$DnldVersn" >> $FW_DNLD_STATUS_FILE
    echo "DnldFile|$DnldFile" >> $FW_DNLD_STATUS_FILE
    echo "DnldURL|`cat $DnldURLvalue`" >> $FW_DNLD_STATUS_FILE
    echo "DnldPercent|$DnldPercent" >> $FW_DNLD_STATUS_FILE
    echo "LastRun|$LastRun" >> $FW_DNLD_STATUS_FILE
    echo "Codebig_Enable|$Codebig" >> $FW_DNLD_STATUS_FILE
    echo "LastSuccessfulRun|$LastSuccessfulRun" >> $FW_DNLD_STATUS_FILE
    echo "CurrentVersion|$CurrentVersion" >> $FW_DNLD_STATUS_FILE
    echo "CurrentFile|$CurrentFile" >> $FW_DNLD_STATUS_FILE
    echo "LastSuccessfulUpgradeFile|$LastSuccessfulUpgradeFile" >> $FW_DNLD_STATUS_FILE
    echo "FwUpdateState|$fwUpdateState" >> $FW_DNLD_STATUS_FILE
}

sendTLSRequest()
{
  #send TLS Request to download the image
   return 1;
}

## trigger image download to the box
imageDownloadToLocalServer ()
{
    swupdateLog "imageDownloadToLocalServer: Triggering the Image CDL ..."

    UPGRADE_LOCATION=$1
    swupdateLog "UPGRADE_LOCATION = $UPGRADE_LOCATION"

    #Enforce https
    UPGRADE_LOCATION=`echo $UPGRADE_LOCATION | sed "s/http:/https:/g"`

    UPGRADE_FILE=$2
    swupdateLog "UPGRADE_FILE = $UPGRADE_FILE"

    CodebigFlag=$3
    swupdateLog "DIFW_PATH = $DIFW_PATH"

    if [ ! -d $DIFW_PATH ]; then
         mkdir -p $DIFW_PATH
    fi

    cd $DIFW_PATH
    if [ $CodebigFlag -eq 1 ]; then
        imageHTTPURL="$UPGRADE_LOCATION"
    else
        # Change to support whether full http URL
        imageHTTPURL="$UPGRADE_LOCATION/$UPGRADE_FILE"
    fi
    swupdateLog "imageHTTPURL = $imageHTTPURL"
    echo "$imageHTTPURL" > $DnldURLvalue

    ret=1
    model_num=$MODEL_NUM
    FILE_EXT=$model_num*.bin
    rm -f $FILE_EXT
    cloudfile_model=`echo $UPGRADE_FILE | cut -d '_' -f1`
    if [[ "$cloudfile_model" != *"$model_num"* ]]; then
        swupdateLog "Image configured is not of model $model_num.. Skipping the upgrade"
        swupdateLog "Exiting from Image Upgrade process..!"
        updateFWDnldStatus "$cloudProto" "Failure" "Cloud FW Version is invalid" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Failed"
        eventManager $FirmwareStateEvent $FW_STATE_FAILED
        exit 0
    fi
    updateFWDnldStatus "$cloudProto" "ESTB in progress" "" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Downloading"
    swupdateLog "imageDownloadToLocalServer: Started image download ..."

    #Set FirmwareDownloadStartedNotification before starting of firmware download
    if [ "${isMmgbleNotifyEnabled}" == "true" ]; then
        current_time=`date +%s`
        swupdateLog "current_time calculated as $current_time"
        tr181 -s -v $current_time  Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.FirmwareDownloadStartedNotification
        swupdateLog "FirmwareDownloadStartedNotification SET succeeded"
    fi
    if [ "$Protocol" = "usb" ]; then
	DEFER_REBOOT=1
	# Overwrite the path to program directly from the USB
        DIFW_PATH=$UPGRADE_LOCATION
        if [ ! -f $DIFW_PATH/$UPGRADE_FILE ]; then
	    swupdateLog "Error: $DIFW_PATH/$UPGRADE_FILE not found"
            http_code="404"
        else
            ret=0
            http_code="200"
        fi
    else
        sendTLSRequest $CodebigFlag
        ret=$?
        http_code=$(awk '{print $1}' $CURL_INFO)
    fi

    if [ $ret -ne 0 ] || [ "$http_code" != "200" ]; then
        swupdateLog "Local image Download Failed ret:$ret, httpcode:$http_code, Retrying"
        failureReason="ESTB Download Failure"
        if [ "$DEVICE_TYPE" == "mediaclient" ]; then
            if [ "x$http_code" = "x000" ]; then
               failureReason="Image Download Failed - Unable to connect"
            elif [ "x$http_code" = "x404" ]; then
               failureReason="Image Download Failed - Server not Found"
            elif [[ "$http_code" -ge 500 ]] && [[ "$http_code" -le 511 ]]; then
               failureReason="Image Download Failed - Error response from server"
            else
               failureReason="Image Download Failed - Unknown"
            fi
        fi
        t2ValNotify "SYST_ERR_FWdnldFail" "$failureReason"
        updateFWDnldStatus "$cloudProto" "Failure"  "$failureReason" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Failed"
        eventManager $FirmwareStateEvent $FW_STATE_FAILED

        if [ "${isMmgbleNotifyEnabled}" == "true" ]; then
            #Set FirmwareDownloadCompletedNotification after firmware download
            tr181 -s -v false  Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.FirmwareDownloadCompletedNotification
            swupdateLog "FirmwareDownloadCompletedNotification SET to false succeeded"
        fi
        return $ret
    else
        swupdateLog "Local image Download Success ret:$ret"
        updateFWDnldStatus "$cloudProto" "Flashing In Progress" "" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Download complete"
        eventManager $FirmwareStateEvent $FW_STATE_DOWNLOAD_COMPLETE

        if [ "${isMmgbleNotifyEnabled}" == "true" ]; then
            #Set FirmwareDownloadCompletedNotification after firmware download
            tr181 -s -v true  Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.FirmwareDownloadCompletedNotification
            swupdateLog "FirmwareDownloadCompletedNotification SET to true succeeded"
        fi
    fi
    swupdateLog "$UPGRADE_FILE Local Image Download Completed with status=$ret!"
    t2ValNotify "SYST_INFO_FWCOMPLETE" "$UPGRADE_FILE"

    # Set reboot flag to true
    REBOOT_FLAG=1
    if [ "$DEFER_REBOOT" = "1" ];then
        REBOOT_FLAG=0
    fi

    if [ "$DEVICE_TYPE" = "mediaclient" ]
    then
        # invoke device/soc specific flash app
        /lib/rdk/imageFlasher.sh $cloudProto $UPGRADE_LOCATION $DIFW_PATH $UPGRADE_FILE
        ret=$?
        if [ "$ret" -ne 0 ]; then
            updateFWDnldStatus "$cloudProto" "Failure" "Flashing failed" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Failed"
            eventManager $FirmwareStateEvent $FW_STATE_FAILED
        else
            updateFWDnldStatus "$cloudProto" "Success" "" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Validation complete"
	    eventManager $FirmwareStateEvent $FW_STATE_VALIDATION_COMPLETE
            echo "$UPGRADE_FILE" > /opt/cdl_flashed_file_name
            if [ "$REBOOT_FLAG" = "1" ] && [ "$Protocol" != "usb" ]; then
		eventManager $FirmwareStateEvent $FW_STATE_PREPARING_TO_REBOOT
                rm -rf /opt/.gstreamer
                if [ "${isMmgbleNotifyEnabled}" == "true" ]; then
                    swupdateLog "Trigger RebootPendingNotification in background"
                    Trigger_RebootPendingNotify &
                fi
                swupdateLog "sleep for $REBOOT_PENDING_DELAY sec to send reboot pending notification"
                (sleep $REBOOT_PENDING_DELAY; /rebootNow.sh -s ImageUpgrade_"`basename $0`" -o "Rebooting the box after RCDL Image Upgrade...") & # reboot explicitly. imageFlasher.sh only flashes, will not reboot device.
            fi
        fi
        # image file can be deleted now
        if [ "$Protocol" != "usb" ]; then
            rm -rf $DIFW_PATH/$UPGRADE_FILE
        fi
    else
        imagePath="\"$DIFW_PATH/"$UPGRADE_FILE"\""
        swupdateLog "imagePath = $imagePath"
        if [ "$CPU_ARCH" == "x86" ]; then
             updateFWDnldStatus "$cloudProto" "Triggered ECM download" "" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" ""
        fi
        if [ "$DEVICE_TYPE" = "hybrid" ]
        then
            # invoke rmfAPICaller here
            /usr/bin/rmfapicaller vlMpeosCdlUpgradeToImage 0 2 $REBOOT_FLAG $imagePath
        else
            # invoke vlAPICaller here
            /mnt/nfs/bin/vlapicaller vlMpeosCdlUpgradeToImage 0 2 $REBOOT_FLAG $imagePath
        fi
        ret=$?
        if [ $ret -ne 0 ]; then
            if [ "$CPU_ARCH" != "x86" ]; then
               updateFWDnldStatus "$cloudProto" "Failure" "RCDL Upgrade Failed" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Failed"
            else
               updateFWDnldStatus "$cloudProto" "Failure" "ECM trigger failed" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "Failed"
            fi
        fi
    fi
    return $ret
}

ProcessImageUpgradeRequest()
{
    ret=1
    UpgradeLocation=$1
    UpgradeFile=$2
    CodebigFlag=$3
    http_code="000"
    retries=0
    cbretries=0

    if [ -f /tmp/currently_running_image_name ]
    then
        myFWFile=`cat /tmp/currently_running_image_name`
        currentFile=$myFWFile
        myFWFile=`echo $myFWFile | tr '[A-Z]' '[a-z]'`
    fi
    swupdateLog "myFWFile = $myFWFile"

    if [ -f /opt/cdl_flashed_file_name ]
    then
        lastDnldFile=`cat /opt/cdl_flashed_file_name`
        lastDnldFileName=$lastDnldFile
        lastDnldFile=`echo $lastDnldFile | tr '[A-Z]' '[a-z]'`
    fi
    swupdateLog "lastDnldFile = $lastDnldFile "

    if [ "$Protocol" = "usb" ]; then
        imageDownloadToLocalServer $UpgradeLocation $UpgradeFile 0
        resp=$?
    elif [ "$myFWFile" = "$dnldFile" ]; then
        swupdateLog "FW version of the active image and the image to be upgraded are the same. No upgrade required."
        t2CountNotify "SYST_INFO_swdlSameImg"
        updateFWDnldStatus "$cloudProto" "No upgrade needed" "Versions Match" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "No upgrade needed"
    elif [ "$lastDnldFile" = "$dnldFile" ]; then
        swupdateLog "FW version of the standby image and the image to be upgraded are the same. No upgrade required."
        t2CountNotify "fwupgrade_failed"
        updateFWDnldStatus "$cloudProto" "No upgrade needed" "Versions Match" "$dnldVersion" "$UpgradeFile" "$runtime" "$CodebigFlag" "No upgrade needed"
    else
        if [ $CodebigFlag -eq 1 ]; then
            swupdateLog "ProcessImageUpgradeRequest: Codebig is enabled UseCodebig=$CodebigFlag"
            # Use Codebig connection connection on XI platforms
            # When codebig is set, use the DAC15 signed codebig URL for firmware download
            IsCodeBigBlocked
            skipcodebig=$?
            if [ $skipcodebig -eq 0 ]; then
                while [ "$cbretries" -le $CB_RETRY_COUNT ]
                do
                    swupdateLog "ProcessImageUpgradeRequest: Attempting Codebig firmware download"
                    getCodebigUrl
                    imageDownloadToLocalServer $cb_signed_request $UpgradeFile $CodebigFlag
                    resp=$?
                    http_code=$(awk '{print $1}' $CURL_INFO)
                    if [ $resp -eq 0 ] && [ "$http_code" = "200" ]; then
                        swupdateLog "ProcessImageUpgradeRequest: Codebig firmware download Success - ret:$resp, httpcode:$http_code"
                        t2CountNotify "SYS_INFO_CodBPASS"
                        IsDirectBlocked
                        skipDirect=$?
                        if [ $skipDirect -eq 0 ]; then
                            CodebigFlag=0
                        fi
                        break
                    elif [ "$http_code" = "404" ]; then
                        swupdateLog "ProcessImageUpgradeRequest: Received 404 response for Codebig firmware download, Retry logic not needed"
                        break
                    fi
                    swupdateLog "ProcessImageUpgradeRequest: Codebig firmware download return - retry:$cbretries, ret:$resp, httpcode:$http_code"
                    cbretries=`expr $cbretries + 1`
                    sleep 10
                done
            fi

            if [ "$http_code" = "000" ]; then
                IsDirectBlocked
                skipdirect=$?
                if [ $skipdirect -eq 0 ]; then
                    swupdateLog "ProcessImageUpgradeRequest: Codebig firmware download failed - httpcode:$http_code, Using Direct"
                    CodebigFlag=0
                    imageDownloadToLocalServer $UpgradeLocation $UpgradeFile $CodebigFlag
                    resp=$?
                    http_code=$(awk '{print $1}' $CURL_INFO)
                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        swupdateLog "ProcessImageUpgradeRequest: Direct failover firmware download failed - ret:$resp, httpcode:$http_code"
                    else
                        swupdateLog "ProcessImageUpgradeRequest: Direct failover firmware download received- ret:$resp, httpcode:$http_code"
                    fi
                fi
                IsCodeBigBlocked
                skipCodeBig=$?
                if [ $skipCodeBig -eq 0 ]; then
                    swupdateLog "ProcessImageUpgradeRequest: Codebig block released"
                fi
            elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                swupdateLog "ProcessImageUpgradeRequest: Codebig firmware download failed with httpcode:$http_code"
            fi
        else
            swupdateLog "ProcessImageUpgradeRequest: Codebig is disabled UseCodebig=$CodebigFlag"
            IsDirectBlocked
            skipdirect=$?
            if [ $skipdirect -eq 0 ]; then
                while [ "$retries" -lt $RETRY_COUNT ]
                do
                    swupdateLog "ProcessImageUpgradeRequest: Attempting Direct firmware download"
                    CodebigFlag=0
                    imageDownloadToLocalServer $UpgradeLocation $UpgradeFile $CodebigFlag
                    resp=$?
                    http_code=$(awk '{print $1}' $CURL_INFO)
                    if [ $resp -eq 0 ] && [ "$http_code" = "200" ]; then
                       swupdateLog "ProcessImageUpgradeRequest: Direct firmware download success - ret:$resp, httpcode:$http_code"
                       break
                    elif [ "$http_code" = "404" ]; then
                       swupdateLog "ProcessImageUpgradeRequest: Received 404 response for Direct firmware download, Retry logic not needed"
                       break
                    fi
                    swupdateLog "ProcessImageUpgradeRequest: Direct firmware download return - retry:$retries, ret:$resp, httpcode:$http_code"
                    t2ValNotify "SYST_SWDL_Retry_split" "$TLSRet"
                    retries=`expr $retries + 1`
                    sleep 60
                done
            fi

            if [ "$http_code" = "000" ]; then
                if [ "$DEVICE_TYPE" == "mediaclient" ]; then
                    swupdateLog "ProcessImageUpgradeRequest: Direct firmware download failed - httpcode:$http_code, attempting Codebig"
                    IsCodeBigBlocked
                    skipcodebig=$?
                    if [ $skipcodebig -eq 0 ]; then
                        while [ $cbretries -le $CB_RETRY_COUNT ]
                        do
                            swupdateLog "ProcessImageUpgradeRequest: Attempting Codebig firmware download"
                            CodebigFlag=1
                            getCodebigUrl
                            imageDownloadToLocalServer $cb_signed_request $UpgradeFile $CodebigFlag
                            resp=$?
                            http_code=$(awk '{print $1}' $CURL_INFO)
                            if [ $resp -eq 0 ] && [ "$http_code" = "200" ]; then
                                swupdateLog "ProcessImageUpgradeRequest: Codebig firmware download success - ret:$resp, httpcode:$http_code"
                                t2CountNotify "SYS_INFO_CodBPASS"
                                CodebigFlag=1
                                if [ ! -f $DIRECT_BLOCK_FILENAME ]; then
                                    touch $DIRECT_BLOCK_FILENAME
                                    swupdateLog "ProcessImageUpgradeRequest: Use Codebig and Block Direct for 24 hrs "
                                fi
                                break
                            elif [ "$http_code" = "404" ]; then
                                swupdateLog "ProcessImageUpgradeRequest: Received 404 response for Codebig firmware download, Retry logic not needed"
                                break
                            fi
                            swupdateLog "ProcessImageUpgradeRequest: Codebig firmware download return - retry:$cbretries, ret:$resp, httpcode:$http_code"
                            cbretries=`expr $cbretries + 1`
                            sleep 10
                        done

                        if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                            swupdateLog "ProcessImageUpgradeRequest: Codebig firmware download failed - ret:$resp, httpcode:$http_code"
                            CodebigFlag=0
                            if [ ! -f $CB_BLOCK_FILENAME ]; then
                                touch $CB_BLOCK_FILENAME
                                swupdateLog "ProcessImageUpgradeRequest: Switch Direct and Blocking Codebig for 30mins"
                            fi
                        fi
                    fi
                else
                    swupdateLog "ProcessImageUpgradeRequest: Codebig firmware download is not supported"
                fi
            elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                swupdateLog "ProcessImageUpgradeRequest: Direct firmware download failed - ret:$resp, httpcode:$http_code"
            fi
        fi

        swupdateLog "ProcessImageUpgradeRequest: firmware upgrade codebig:$CodebigFlag method returned $resp httpcode:$http_code"

        if [ $resp = 0 ] && [ "$http_code" = "404" ]; then
            swupdateLog "ProcessImageUpgradeRequest: doCDL failed with HTTPS 404 Response from Xconf Server"
            swupdateLog "Exiting from Image Upgrade process..!"
            exit 0
        elif [ $resp != 0 ] || [ "$http_code" != "200" ]; then
            swupdateLog "ProcessImageUpgradeRequest: doCDL failed"
            t2CountNotify "SYST_ERR_CDLFail"
        else
            swupdateLog "ProcessImageUpgradeRequest: doCDL success"
            t2CountNotify "SYST_INFO_CDLSuccess"
            if [ "$DEFER_REBOOT" = "1" ];then
                swupdateLog "ProcessImageUpgradeRequest: Deferring reboot after firmware download."
            else
                swupdateLog "ProcessImageUpgradeRequest: Rebooting after firmware download."
            fi
            ret=0
        fi
    fi
    rm -f $RCDL_FLAG #Removing lock only after all the retries are failed
    return $ret
}

IsWebpacdlEnabledForProd()
{
    if [ "$Protocol" = "usb" ]; then
        swupdateLog "USB S/W upgrade, skipping check for webPA CDL RFC value"
    else
        #For PROD images, RFC(Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.NonPersistent.WebPACDL.Enable) should be TRUE
        swupdateLog "Check for webPA CDL RFC value"
        if [ -f /usr/bin/tr181 ]; then
            WebPACDL=`/usr/bin/tr181 -g $WEBPACDL_TR181_NAME 2>&1 > /dev/null`
        else
            swupdateLog "tr181 BIN is not available at this time, setting WebPACDL to Default value(False)."
            WebPACDL=false
        fi
        swupdateLog "WebPACDL=$WebPACDL"
        Build_type=`echo $ImageName | grep -i "_PROD_" | wc -l`
        if [ "$Build_type" -ne 0 ] && [ "$WebPACDL" != "true" ]; then
            swupdateLog "Exiting!!! Either Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.NonPersistent.WebPACDL.Enable is FALSE or RFC sync not completed yet."
            t2CountNotify "SYST_ERR_FW_RFC_disabled"
            exit 1
        fi
    fi
}

### main app
swupdateLog "Starting UserInitiated Firmware Download..."
estbIp=`getIPAddress`

# Checking number of cmd line params passed to script file

if [ $# -lt $FOUR_CMDLINE_PARAMS ]; then
     swupdateLog "Error: minimum $FOUR_CMDLINE_PARAMS params needed, so Exiting !!!"
     swupdateLog "USAGE: <Path to userInitiatedFWDnld.sh file> <protocol> <ImageServer_URL> <Image_Name> <Codebig_Flag> <Defer_Reboot>(To enable set 1, To disable set 0)"
     swupdateLog "Example (For Non-Cogent network): /lib/rdk/userInitiatedFWDnld.sh http <ImageServer_URL> <Image_Name> 0 0"
     swupdateLog "Example (For Cogent network): /lib/rdk/userInitiatedFWDnld.sh http <ImageServer_URL> <Image_Name> 1 1"
     exit 1
fi

cleanup()
{
    swupdateLog "cleanup..."
    if [ -f $CURL_INFO ]; then
        swupdateLog "http code file removed"
        rm -f $CURL_INFO
    fi
    if [ -f $RCDL_FLAG ]; then
        swupdateLog "Lock removed"
        rm -f $RCDL_FLAG
    fi
}

if [ "$estbIp" = "$DEFAULT_IP" ]; then
    swupdateLog "waiting for IP ..."
    sleep 15
else
    swupdateLog "--------- $interface got an ip $estbIp"

    ## Initialize the DIFD status/log file
    runtime=`date -u +%F' '%T`

    swupdateLog "Using script arguments $2 and $3 to download..."

    CodebigFlag=$4
    ImageName=$3
    ImagePath=$2
    Protocol=$1
    DEFER_REBOOT=$5

    if [ "$DEFER_REBOOT" != "1" ]; then
        DEFER_REBOOT=0;
    fi

    swupdateLog "ImageName = $ImageName"
    swupdateLog "ImagePath = $ImagePath"
    swupdateLog "DEFER_REBOOT = $DEFER_REBOOT"

    # Added flag to confirm Xconf Upgrade is not running to perform Webpa CDL
    if [ -f $RCDL_FLAG ] || [ -f $DNDL_INPROGRESS_FLAG ]; then
	swupdateLog "Image download already in progress, exiting!"
	exit 1
    elif [ ! -z "$ImageName" ] && [ ! -z "$ImagePath" ]; then
        IsWebpacdlEnabledForProd
        swupdateLog "Found download details, triggering download..."
        touch $RCDL_FLAG
        trap cleanup EXIT #Remove Lock upon exit
        dnldVersion=`echo $ImageName | sed  's/-signed.bin//g' | sed  's/.bin//g'`
        dnldFile=`echo $ImageName | tr '[A-Z]' '[a-z]'`
	eventManager $FirmwareStateEvent $FW_STATE_REQUESTING
        ProcessImageUpgradeRequest $ImagePath $ImageName $CodebigFlag
        exit $?
    else
        swupdateLog "rcdlUpgradeFile or rcdlUpgradeFilePath is empty. Exiting !!!"
        exit 1
    fi
fi
