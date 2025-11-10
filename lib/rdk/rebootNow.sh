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
. /etc/env_setup.sh

# The reboot cmd is aliased to "reboot -f" in env_setup.sh. Remove force reboot as it causing HDD corruption.
if [ -f /etc/os-release ];then
    alias reboot='/sbin/reboot'
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

REBOOT_REASON_LOGFILE="/opt/logs/rebootreason.log"
rebootLog() {
    echo "`/bin/timestamp` :$0: $*" >> $REBOOT_REASON_LOGFILE
}

#Usage: rebootNow.sh [-c "<crash>" | -s "<source>"][-r "<custom reason>"][-o "<other reason>"]
usage()
{
    rebootLog "USAGE: rebootNow.sh -c/-s <crash/source> -r <custom reason> -o <other reason>"
    rebootLog " -s <source> : Source Module or Script Name"
    rebootLog " -c <crash> : Crash Process Name"
    rebootLog " -r <custom reason> : Reason to specify for any particular reason: default=Unknown"
    rebootLog " -o <other reason> : Reason to request for the reboot: default=Unknown"
}

if [ $# -lt 2 ]; then
   rebootLog "Exiting as no argument specified to identify source of reboot!!!"
   usage
   exit 1
elif [[ "$3" == "-s" || "$3" == "-c" ]]; then
   rebootLog "Exiting as invalid arguments found!!!"
   usage
   exit 1
fi

# Save reboot details in /opt/secure/reboot folder.
REBOOT_INFO_DIR="/opt/secure/reboot"
REBOOT_INFO_FILE="/opt/secure/reboot/reboot.info"
PREVIOUSREBOOT_INFO_FILE="/opt/secure/reboot/previousreboot.info"
PARODUS_REBOOT_INFO_FILE="/opt/secure/reboot/parodusreboot.info"
REBOOTINFO_LOGFILE="/opt/logs/rebootInfo.log"
REBOOTNOW_FLAG="/opt/secure/reboot/rebootNow"
REBOOTSTOP_FLAG="/opt/secure/reboot/rebootStop"
REBOOT_COUNTER="/opt/secure/reboot/rebootCounter"
REBOOTSTOP_DURATION=$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.RebootStop.Duration 2>&1 > /dev/null)
REBOOTSTOP_DETECTION=$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.RebootStop.Detection 2>&1 > /dev/null)
REBOOT_WINDOW=10
REBOOT_WINDOW_SECS=$((REBOOT_WINDOW * 60))
REBOOT_CYCLE_THRESHOLD=5
CYCLIC_REBOOT_SOURCE="rebootNow.sh"
CYCLIC_REBOOT_REASON="Rebooting device after expiry of Cyclic reboot pause window"
CDLFILE=$(cat /opt/cdl_flashed_file_name)
PREV_CDLFILE=$(cat /tmp/currently_running_image_name)
# Define Reasons for APP_TRIGGERED, OPS_TRIGGERED and MAINTENANCE_TRIGGERED cases
APP_TRIGGERED_REASONS=(Servicemanager systemservice_legacy WarehouseReset WarehouseService HrvInitWHReset HrvColdInitReset HtmlDiagnostics InstallTDK StartTDK TR69Agent SystemServices Bsu_GUI SNMP CVT_CDL Nxserver DRM_Netflix_Initialize hrvinit PaceMFRLibrary)
OPS_TRIGGERED_REASONS=(ScheduledReboot RebootSTB.sh FactoryReset UpgradeReboot_firmwareDwnld.sh UpgradeReboot_restore XFS wait_for_pci0_ready websocketproxyinit NSC_IR_EventReboot host_interface_dma_bus_wait usbhotplug Receiver_MDVRSet Receiver_VidiPath_Enabled Receiver_Toggle_Optimus S04init_ticket Network-Service monitor.sh ecmIpMonitor.sh monitorMfrMgr.sh vlAPI_Caller_Upgrade ImageUpgrade_rmf_osal ImageUpgrade_mfr_api ImageUpgrade_updateNewImage.sh ImageUpgrade_userInitiatedFWDnld.sh ClearSICache tr69hostIfReset hostIf_utils hostifDeviceInfo HAL_SYS_Reboot UpgradeReboot_deviceInitiatedFWDnld.sh UpgradeReboot_rdkvfwupgrader UpgradeReboot_ipdnl.sh PowerMgr_Powerreset PowerMgr_coldFactoryReset DeepSleepMgr PowerMgr_CustomerReset PowerMgr_PersonalityReset Power_Thermmgr PowerMgr_Plat HAL_CDL_notify_mgr_event vldsg_estb_poll_ecm_operational_state BcmIndicateEcmReset SASWatchDog BP3_Provisioning eMMC_FW_UPGRADE BOOTLOADER_UPGRADE cdl_service BCMCommandHandler BRCM_Image_Validate docsis_mode_check.sh tch_nvram.sh Receiver CANARY_Update boot_FSR)
MAINTENANCE_TRIGGERED_REASONS=(AutoReboot.sh PwrMgr)
pid_file="/tmp/.rebootNow.pid"
customReason="Unknown"
otherReason="Unknown"

touch $REBOOTINFO_LOGFILE

rebootLog "Start of rebootNow script"

pidCleanup()
{
    if [ -f "$pid_file" ];then
        rm -rf "$pid_file"
    fi
}

trap pidCleanup EXIT

# exit if an instance is already running
rebootLog "Checking multiple instance of rebootNow.sh script"
if [ -f $pid_file ];then
    pid=`cat $pid_file`
    if [ -d /proc/$pid -a -f /proc/$pid/cmdline ]; then
        processName=`cat /proc/$pid/cmdline`
        currentprocessName=`cat /proc/$$/cmdline`
        rebootLog "proc entry process name: $processName and running process name $currentprocessName"
        if echo "$processName" | grep -q `basename $0`; then
            rebootLog "An instance of "$0" with pid $pid is already running.."
            rebootLog "Exiting script!!!"
            exit 1
        fi
    fi
fi
echo $$ > $pid_file

while getopts ":s:c:r:o:" opt; do
    case $opt in
        s)
            source=$OPTARG
            rebootLogReason="Triggered from $source process"
            case $source in
                runPodRecovery)
                    t2CountNotify "SYST_ERR_RunPod_reboot"
                    ;;
                CardNotResponding)
                    t2CountNotify "SYST_ERR_CCNotRepsonding_reboot"
                    ;;
                *)
                    t2CountNotify "SYST_ERR_$source"
                    ;;
            esac
            ;;
        c)
            source=$OPTARG
            rebootLogReason="Triggered from $source process failure or crash..!"
            case $source in
                dsMgrMain)
                    t2CountNotify "SYST_ERR_DSMGR_reboot"
                    ;;
                IARMDaemonMain)
                    t2CountNotify "SYST_ERR_IARMDEMON_reboot"
                    ;;
                rmfStreamer)
                    t2CountNotify "SYST_ERR_Rmfstreamer_reboot"
                    ;;
                runPod)
                    t2CountNotify "SYST_ERR_RunPod_reboot"
                    ;;
                *)
                    t2CountNotify "SYST_ERR_$source_reboot"
                    ;;
            esac
            ;;
        r)
            customReason=$OPTARG
            ;;
        o)
            otherReason=$OPTARG
            ;;
        \?)
            rebootLog "Invalid option: -$OPTARG"
            ;;
    esac
done

rebootLog "Reboot requested on the device from Source:$source Reason:$otherReason"

# Assign rebootreason from source category.
if [[ "${APP_TRIGGERED_REASONS[@]}" == *"$source"* ]];then
    rebootReason="APP_TRIGGERED"
    if [ $customReason == "MAINTENANCE_REBOOT" ];then
         rebootReason="MAINTENANCE_REBOOT"
    fi
elif [[ "${OPS_TRIGGERED_REASONS[@]}" == *"$source"* ]];then
    rebootReason="OPS_TRIGGERED"
elif [[ "${MAINTENANCE_TRIGGERED_REASONS[@]}" == *"$source"* ]];then
     rebootReason="MAINTENANCE_REBOOT"
else
    rebootReason="FIRMWARE_FAILURE"
fi

NewCronHr=0
NewCronMin=0
SECS_THRESHOLD=29
MINS_THRESHOLD=59
HOUR_THRESHOLD=23

getNewCronTime() {
    # date is defined as alias of date -u. Due to this on llama uk delay download is not working.
    # So removed alias and use only date for cron job schedule.
    now=$(\date +"%T")
    rebootLog "current time: $now"
    NewCronHr=$(echo $now | cut -d':' -f1)
    NewCronMin=$(echo $now | cut -d':' -f2)
    Sec=$(echo $now | cut -d':' -f3)

    if [ $Sec -gt $SECS_THRESHOLD ]; then
        NewCronMin=`expr $NewCronMin + 1`
    fi

    NewCronMin=`expr $NewCronMin + $1`

    while [ $NewCronMin -gt $MINS_THRESHOLD ]
    do
        NewCronMin=`expr $NewCronMin - 60`
        NewCronHr=`expr $NewCronHr + 1`
        if [ $NewCronHr -gt $HOUR_THRESHOLD ]; then
            NewCronHr=0
        fi
    done

    echo "*/$NewCronMin $NewCronHr * * *"
}

#Add the reboot reason check here
reboot_counter_reset=0
if [ -f $REBOOTNOW_FLAG ] && [ "$REBOOTSTOP_DETECTION" != "false" ];then
    rebootLog "Previous Reboot happened on the device was triggred by RDK software"
    rebootLog "Reboot Loop Detection enabled to check cyclic reboot scenarios:$REBOOTSTOP_DETECTION"
    rm -rf $REBOOTNOW_FLAG
    if [ -f $PREVIOUSREBOOT_INFO_FILE ];then
        prev_reboot_source=$(grep '"source"' "$PREVIOUSREBOOT_INFO_FILE" | sed -E 's/.*"source":"([^"]+)".*/\1/')
        prev_reboot_reason=$(grep '"reason"' "$PREVIOUSREBOOT_INFO_FILE" | sed -E 's/.*"reason":"([^"]+)".*/\1/')
        prev_reboot_customreason=$(grep '"customReason"' "$PREVIOUSREBOOT_INFO_FILE" | sed -E 's/.*"customReason":"([^"]+)".*/\1/')
        prev_reboot_otherreason=$(grep '"otherReason"' "$PREVIOUSREBOOT_INFO_FILE" | sed -E 's/.*"otherReason":"([^"]+)".*/\1/')
        prev_reboot_time=$(grep '"timestamp"' "$PREVIOUSREBOOT_INFO_FILE" | sed -E 's/.*"timestamp":"([^"]+)".*/\1/')
        rebootLog "Previous Reboot Information of the Device:"
        rebootLog "Time:$prev_reboot_time"
        rebootLog "Source:$prev_reboot_source"
        rebootLog "Reason:$prev_reboot_reason"
        rebootLog "customReason:$prev_reboot_customreason"
        rebootLog "otherReason:$prev_reboot_otherreason"

        current_reboot_source="$source"
        current_reboot_reason="$rebootReason"
        current_reboot_customreason="$customReason"
        current_reboot_otherreason="$otherReason"
        current_device_uptime=`cat /proc/uptime | awk '{print $1}' | sed "s/\..*//"`
        rebootLog "Device Uptime from last reboot: $current_device_uptime secs"

        rebootLog "Current Requested Reboot Information:"
        rebootLog "Source:$current_reboot_source"
        rebootLog "Reason:$current_reboot_reason"
        rebootLog "customReason:$current_reboot_customreason"
        rebootLog "otherReason:$current_reboot_otherreason"
        if [[ $current_device_uptime -le "$REBOOT_WINDOW_SECS" ]]; then
            rebootLog "Reboot requested before the $REBOOT_WINDOW mins, checking reboot reason"
            if [ "$current_reboot_source" == "$prev_reboot_source" ] && [ "$current_reboot_reason" == "$prev_reboot_reason" ] &&
                [ "$current_reboot_customreason" == "$prev_reboot_customreason" ] && [ "$current_reboot_otherreason" == "$prev_reboot_otherreason" ]; then
                rebootLog "Reboot Reason for current and previous reboot is same"
                if [ -f $REBOOTSTOP_FLAG ]; then
                    rebootLog "Reboot Operation Halted in the device to avoid continous reboots with same reason!!!"
                    touch $REBOOTNOW_FLAG
                    rebootLog "Exiting without rebooting the device"
                    exit 0
                else
                    reboot_count=`cat $REBOOT_COUNTER`
                    rebootLog "Checking device is stuck in cyclic reboot loop with same reboot reason, Current Iteration:$reboot_count"
                    if [ $reboot_count -ge $REBOOT_CYCLE_THRESHOLD ];then
                        rebootLog "Detected Reboot Loop in device, Halting reboot for next $REBOOTSTOP_DURATION mins to perform operations!!!"
                        touch $REBOOTSTOP_FLAG
                        tr181 -s -v true Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.RebootStop.Enable
                        rebootstopvalue=`tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.RebootStop.Enable 2>&1 > /dev/null`
                        rebootLog "Publishing Reboot Stop Enable Event:$rebootstopvalue"
                        t2CountNotify "SYST_ERR_Cyclic_reboot"
                        # Remove any old Reboot Cron Jobs
                        sh /lib/rdk/cronjobs_update.sh "remove" "rebootNow.sh"
                        REBOOT_CRON_INTERVAL_TIME=$(getNewCronTime $REBOOTSTOP_DURATION)
                        rebootLog "Scheduling Cron for rebootNow.sh as a part of Cyclic reboot operations: $REBOOT_CRON_INTERVAL_TIME"
                        sh /lib/rdk/cronjobs_update.sh "add" "rebootNow.sh" "$REBOOT_CRON_INTERVAL_TIME /bin/sh /lib/rdk/rebootNow.sh -s \"$CYCLIC_REBOOT_SOURCE\" -o \"$CYCLIC_REBOOT_REASON\""
                        rebootLog "Device will reboot in $REBOOTSTOP_DURATION mins after expiry of Cyclic reboot pause window!!!"
                        touch $REBOOTNOW_FLAG
                        exit 0
                    else
                        reboot_count=$((reboot_count + 1))
                        echo $reboot_count > $REBOOT_COUNTER
                    fi
                fi
            else
                rebootLog "Reboot requested before the $REBOOT_WINDOW mins reboot loop window with different reason"
                reboot_counter_reset=1
            fi
        else
            rebootLog "Reboot requested after the $REBOOT_WINDOW mins reboot loop window"
            reboot_counter_reset=1
        fi
    else
        rebootLog "$PREVIOUSREBOOT_INFO_FILE file not found, proceed without reboot reason check!!!"
        reboot_counter_reset=1
    fi
else
    if [ ! -f $REBOOTNOW_FLAG ]; then
        rebootLog "Last reboot was not triggered by rebootNow.sh script"
    else
        rebootLog "Reboot Loop Detection disabled to check cyclic reboot scenarios:$REBOOTSTOP_DETECTION"
    fi
    reboot_counter_reset=1
fi

#Reset cyclic reboot counter
if [ $reboot_counter_reset == 1 ];then
    rebootLog "Publishing Reboot Stop Disable Event"
    tr181 -s -v false Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.RebootStop.Enable
    rebootLog "Reboot Loop Detection counter reset as device not in reboot loop"
    echo 0 > $REBOOT_COUNTER
    rm -rf $REBOOTSTOP_FLAG
fi

syncLog()
{
    if [ -d "$TEMP_LOG_PATH" ]; then
        rebootLog "${FUNCNAME[0]}: Find and move the logs from $TEMP_LOG_PATH to $LOG_PATH"
        cWD=`pwd`
        syncPath=`find $TEMP_LOG_PATH -type l -exec ls -l {} \; | cut -d ">" -f2 | tr -d ' '`
        if [ "$syncPath" != "$LOG_PATH" ];then
            cd "$TEMP_LOG_PATH"
            for file in `ls *.txt *.log`
            do
                cat $file >> $LOG_PATH/$file
                cat /dev/null > $file
            done
            cd $cWD
        else
            rebootLog "${FUNCNAME[0]}: Sync Not needed, Same log folder"
        fi
    else
        rebootLog "${FUNCNAME[0]}: $TEMP_LOG_PATH not found!!!"
    fi
}

# Save the reboot info with all the fields
setPreviousRebootInfo()
{
    rebootLog "${FUNCNAME[0]}: Saving reboot info in $REBOOT_INFO_FILE file"
    timestamp=$1
    source=$2
    reason=$3
    custom=$4
    other=$5
    echo "{" > $REBOOT_INFO_FILE
    echo "\"timestamp\":\"$timestamp\"," >> $REBOOT_INFO_FILE
    echo "\"source\":\"$source\"," >> $REBOOT_INFO_FILE
    echo "\"reason\":\"$reason\"," >> $REBOOT_INFO_FILE
    echo "\"customReason\":\"$custom\"," >> $REBOOT_INFO_FILE
    echo "\"otherReason\":\"$other\"" >> $REBOOT_INFO_FILE
    echo "}" >> $REBOOT_INFO_FILE

    echo "PreviousRebootInfo:$timestamp,$custom,$source,$reason" >> $PARODUS_REBOOT_INFO_FILE
    rebootLog "${FUNCNAME[0]}: Updated Reboot Reason information in $REBOOT_INFO_FILE and $PARODUS_REBOOT_INFO_FILE"
}

# Log reboot information to rebootInfo.log file
rebootTime=`date -u`

if [ "$otherReason" == "Unknown" ]; then
    echo "RebootReason: $rebootLogReason" >> $REBOOTINFO_LOGFILE
else
    echo "RebootReason: $rebootLogReason $otherReason" >> $REBOOTINFO_LOGFILE
fi
echo "RebootInitiatedBy: $source" >> $REBOOTINFO_LOGFILE
echo "RebootTime: $rebootTime" >> $REBOOTINFO_LOGFILE
echo "CustomReason: $customReason" >> $REBOOTINFO_LOGFILE
echo "OtherReason: $otherReason" >> $REBOOTINFO_LOGFILE

# Create /opt/secure/reboot/ folder before reboot/shutdown.
if [ ! -d $REBOOT_INFO_DIR ]; then
    rebootLog "Creating $REBOOT_INFO_DIR folder"
    mkdir $REBOOT_INFO_DIR
fi

# Added check for Hal_SYS_reboot source
multipleSource=`grep -E HAL_SYS_Reboot $REBOOTINFO_LOGFILE`
if [ -z "$multipleSource" ];then
    rebootSource=$source
else
    rebootSource=`grep RebootReason $REBOOTINFO_LOGFILE | grep -v HAL_SYS_Reboot | grep -v grep | awk -F " " '{print $5}'`
    otherReason=`grep RebootReason $REBOOTINFO_LOGFILE | grep -v HAL_SYS_Reboot | grep -v grep | awk -F 'HAL_CDL_notify_mgr_event' '{print $NF}' | sed 's/(.*//'`
fi

# Save reboot details in reboot.info file under /opt/secure/reboot folder
rebootLog "Invoke setPreviousRebootInfo to save reboot information under $REBOOT_INFO_DIR folder"
setPreviousRebootInfo "$rebootTime" "$rebootSource" "$rebootReason" "$customReason" "$otherReason"

isMmgbleNotifyEnabled=$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.ManageableNotification.Enable 2>&1 > /dev/null)
rebootLog "Value of Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.ManageableNotification.Enable: $isMmgbleNotifyEnabled"
if [ "${isMmgbleNotifyEnabled}" == "true" ];then
    tr181 -s -v 10 Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.RebootPendingNotification
fi

####
#  All housekeeping before actual device reboot starts from here
####

# Signal telemetry2_0 to send out any pending messages before reboot
rebootLog "Signal telemetry2_0 to send out any pending messages before reboot"
killall -s SIGUSR1 telemetry2_0

# Kill the Parodus Process; So that it can close the WebSocket Connection with Server.
rebootLog "Properly shutdown parodus by sending SIGUSR1 kill signal"
killall -s SIGUSR1 parodus

if [ -f /etc/rdm/rdm-manifest.xml ];then
    if [[ ${CDLFILE} != *"${PREV_CDLFILE}"* ]]; then
        if [ -d /media/apps ];then
            rebootLog "Removing the RDM Apps content from Secondary Storage before Reboot (After IMage Upgrade)"
            cd /media/apps
            if [ $? -eq 0 ];then
                for i in `ls -d */`
                do
                    rm -rf $i
                    sleep 1
                done
            fi
            sleep 5
        fi
    fi
fi

if [ ! -f $PERSISTENT_PATH/.lightsleepKillSwitchEnable ];then
    syncLog
    if [ -f $TEMP_LOG_PATH/.systime ];then
        cp $TEMP_LOG_PATH/.systime $PERSISTENT_PATH/
    fi
fi

if [ "$DEVICE_NAME" = "XI6"  ] || [ "$DEVICE_NAME" = "XiOne"  ] || [ "$DEVICE_NAME" = "XiOne-SCB" ];then
    if [ "$DEVICE_NAME" = "XI6"  ];then
        # Get eMMC Health report
        if [ -f /lib/rdk/emmc_health_diag.sh ];then
            sh /lib/rdk/emmc_health_diag.sh "reboot"
            rebootLog "Updated eMMC Health report"
        fi
    fi
    # See if we need to Upgrade the eMMC FW
    if [ -f /lib/rdk/eMMC_Upgrade.sh ];then
        rebootLog "Upgrade eMMC FW if required"
        sh /lib/rdk/eMMC_Upgrade.sh
    fi
fi

if [ -f /lib/rdk/aps4_reset.sh ];then
    rebootLog "Executing /lib/rdk/aps4_reset.sh"
    sh /lib/rdk/aps4_reset.sh
fi

if [ -f /lib/rdk/update_www-backup.sh ];then
    rebootLog "Executing /lib/rdk/update_www-backup.sh"
    sh /lib/rdk/update_www-backup.sh
fi

#If bluetooth is enabled, gracefully shutdown the bluetooth related services
if [ "$BLUETOOTH_ENABLED" = "true" ];then
    services=("sky-bluetoothrcu" "btmgr" "bluetooth" "bt-hciuart" "btmac-preset" "bt" "syslog-ng")
    rebootLog "Shutting down the bluetooth and syslog-ng services gracefully"
    for service in "${services[@]}"; do
        rebootLog "Shutting down the $service service"
        if /bin/systemctl --quiet is-active "$service"; then
            /bin/systemctl stop "$service"
            if [[ $? -eq 0 ]]; then
                rebootLog "$service service stopped successfully"
            else
                rebootLog "Failed to stop $service service"
            fi
        else
            rebootLog "$service service is not active"
        fi
    done
fi

rebootLog "Start the sync"
sync
rebootLog "End of the sync"

rebootLog "Creating $REBOOTNOW_FLAG as the reboot was triggred by RDK software"
touch $REBOOTNOW_FLAG
rm -rf $pid_file

rebootLog "Rebooting the Device Now"
reboot &
REBOOT_PID=$!

sleep 90
rebootLog "System still running after reboot command, Reboot Failed for $REBOOT_PID..."
systemctl reboot
if [ $? -eq 1 ]; then
    rebootLog "Reboot failed due to systemctl hang or connection timeout"
fi
kill $REBOOT_PID 2>/dev/null
rebootLog "Triggering force Reboot after standard soft reboot failure"
reboot -f
