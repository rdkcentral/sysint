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

# Usage: rebootNow.sh [-c "<crash>" | -s "<source>"][-r "<custom reason>"][-o "<other reason>"]
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

# Save reboot details in /opt/secure/reboot folder.
REBOOT_INFO_DIR="/opt/secure/reboot"
REBOOT_INFO_FILE="/opt/secure/reboot/reboot.info"
PARODUS_REBOOT_INFO_FILE="/opt/secure/reboot/parodusreboot.info"
REBOOTINFO_LOGFILE="/opt/logs/rebootInfo.log"
REBOOT_REASON_LOGFILE="/opt/logs/rebootreason.log"

rebootLog() {
    echo "`/bin/timestamp` :$0: $*" >> $REBOOT_REASON_LOGFILE
}

rebootLog "Start of rebootNow script"

# Define Reasons for APP_TRIGGERED, OPS_TRIGGERED and MAINTENANCE_TRIGGERED cases 
APP_TRIGGERED_REASONS=(Servicemanager systemservice_legacy WarehouseReset WarehouseService HrvInitWHReset HrvColdInitReset HtmlDiagnostics InstallTDK StartTDK TR69Agent SystemServices Bsu_GUI SNMP CVT_CDL Nxserver DRM_Netflix_Initialize hrvinit )
OPS_TRIGGERED_REASONS=(ScheduledReboot RebootSTB.sh FactoryReset UpgradeReboot_restore XFS wait_for_pci0_ready websocketproxyinit NSC_IR_EventReboot host_interface_dma_bus_wait usbhotplug Receiver_MDVRSet Receiver_VidiPath_Enabled Receiver_Toggle_Optimus S04init_ticket Network-Service monitorMfrMgr.sh vlAPI_Caller_Upgrade ImageUpgrade_rmf_osal ImageUpgrade_mfr_api ImageUpgrade_userInitiatedFWDnld.sh ClearSICache tr69hostIfReset hostIf_utils hostifDeviceInfo HAL_SYS_Reboot UpgradeReboot_deviceInitiatedFWDnld.sh UpgradeReboot_rdkvfwupgrader UpgradeReboot_ipdnl.sh PowerMgr_Powerreset PowerMgr_coldFactoryReset DeepSleepMgr PowerMgr_CustomerReset PowerMgr_PersonalityReset Power_Thermmgr PowerMgr_Plat HAL_CDL_notify_mgr_event vldsg_estb_poll_ecm_operational_state SASWatchDog BP3_Provisioning eMMC_FW_UPGRADE BOOTLOADER_UPGRADE cdl_service   docsis_mode_check.sh  Receiver)
MAINTENANCE_TRIGGERED_REASONS=(AutoReboot.sh PwrMgr)

touch $REBOOTINFO_LOGFILE
process=`cat /proc/$PPID/cmdline`

# exit if an instance is already running
rebootLog "Checking multiple instance of rebootNow.sh script"
pid_file="/tmp/.rebootNow.pid"

if [ -f $pid_file ]
then
    pid=`cat $pid_file`
    if [ -d /proc/$pid ]
    then
        rebootLog "An instance of "$0" with pid $pid is already running.."
        rebootLog "Exiting script"
        exit 0
    fi
fi

echo $$ > $pid_file

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

    echo "PreviousRebootInfo:$timestamp,$customReason,$source,$reason" >> $PARODUS_REBOOT_INFO_FILE
    rebootLog "${FUNCNAME[0]}: Updated Reboot Reason information in $REBOOT_INFO_FILE and $PARODUS_REBOOT_INFO_FILE"
}

customReason="Unknown"
otherReason="Unknown"

# Decide the reboot reason based on source and reason    
if [[ $1 == "" ]]; then
    source=$process
    rebootReason="Triggered from $source process"
else
    while getopts ":s:c:r:o:" opt; do
      case $opt in
        s)
             source=$OPTARG
             rebootReason="Triggered from $source"
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
             rebootReason="Triggered from $source crash..!"
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
fi

# Log reboot information to rebootInfo.log file
rebootTime=`date -u`

if [ "$otherReason" == "Unknown" ]; then
    echo "RebootReason: $rebootReason" >> $REBOOTINFO_LOGFILE
else
    echo "RebootReason: $rebootReason $otherReason" >> $REBOOTINFO_LOGFILE
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

# Save reboot details in reboot.info file under /opt/secure/reboot folder
rebootLog "Invoke setPreviousRebootInfo to save reboot information under $REBOOT_INFO_DIR folder"
setPreviousRebootInfo "$rebootTime" "$rebootSource" "$rebootReason" "$customReason" "$otherReason"

isMmgbleNotifyEnabled=$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.ManageableNotification.Enable 2>&1 > /dev/null)
rebootLog "Value of Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.ManageableNotification.Enable: $isMmgbleNotifyEnabled"
if [ "${isMmgbleNotifyEnabled}" == "true" ]; then
    tr181 -s -v 10 Device.DeviceInfo.X_RDKCENTRAL-COM_xOpsDeviceMgmt.RPC.RebootPendingNotification
fi

####
#  All housekeeping before actual device reboot starts from here 
####

# Signal telemetry2_0 to send out any pending messages before reboot
rebootLog "Signal telemetry2_0 to send out any pending messages before reboot"
killall -s SIGUSR1 telemetry2_0

if [ -f /etc/rdm/rdm-manifest.xml ];then
     CDLFILE=$(cat /opt/cdl_flashed_file_name)
     PREV_CDLFILE=$(cat /tmp/currently_running_image_name)
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

# Kill the Parodus Process; So that it can close the WebSocket Connection with Server.
rebootLog "Properly shutdown parodus by sending SIGUSR1 kill signal"
killall -s SIGUSR1 parodus

# For Reboot Optimisation
#  * If Distro Feature use_legacy_shutdown is enabled sleep(5) will be executed as it is
#  * If Distro Feature use_legacy_shutdown is not enabled sleep(5) will not be executed .
if [ "$ENABLE_LEGACY_SHUTDOWN" = "1" ]; then
   echo "ENABLE_LEGACY_SHUTDOWN: $ENABLE_LEGACY_SHUTDOWN" >> $REBOOT_REASON_LOGFILE
   sleep 5
fi

if [ ! -f $PERSISTENT_PATH/.lightsleepKillSwitchEnable ]; then
      syncLog
      if [ -f $TEMP_LOG_PATH/.systime ]; then
            cp $TEMP_LOG_PATH/.systime $PERSISTENT_PATH/
      fi
fi

if [ -f /lib/rdk/do_eMMC_check.sh ]; then
    rebootLog "Upgrade eMMC FW if required"
    sh /lib/rdk/do_eMMC_check.sh
fi

if [ -f /lib/rdk/aps4_reset.sh ]; then
    rebootLog "Executing /lib/rdk/aps4_reset.sh"
    sh /lib/rdk/aps4_reset.sh
fi

if [ -f /lib/rdk/update_www-backup.sh ]; then
    rebootLog "Executing /lib/rdk/update_www-backup.sh"
    sh /lib/rdk/update_www-backup.sh
fi

#If bluetooth is enabled, gracefully shutdown the bluetooth related services
rebootLog "Shutting down the bluetooth services gracefully"
if [ "$BLUETOOTH_ENABLED" = "true" ];then
    rebootLog "Shutting down the btmgr service"
    /bin/systemctl --quiet is-active btmgr && /bin/systemctl stop btmgr    
    rebootLog "Shutting down the bluetooth service"
    /bin/systemctl --quiet is-active bluetooth && /bin/systemctl stop bluetooth
    rebootLog "Shutting down the bt-hciuart service"
    /bin/systemctl --quiet is-active bt-hciuart && /bin/systemctl stop bt-hciuart
    rebootLog "Shutting down the btmac-preset service"
    /bin/systemctl --quiet is-active btmac-preset && /bin/systemctl stop btmac-preset
    rebootLog "Shutting down the bt service"
    /bin/systemctl --quiet is-active bt && /bin/systemctl stop bt
fi

#stop syslog-ng service
rebootLog "Shutting down the syslog-ng services gracefully"
/bin/systemctl --quiet is-active syslog-ng && /bin/systemctl stop syslog-ng

rebootLog "Start the sync"
sync
rebootLog "End of the sync"

reboot
if [ $? -eq 1 ]; then #Force reboot when reboot fails
    rebootLog "Reboot Failed, trying force reboot..."
    if [ -f /tmp/systemd_freeze_reboot_on ];then
        rebootLog "Force Reboot After First Reboot Attempt Failure"
        reboot -f
    else
        rebootLog "Force Reboot with systemctl After First Reboot Attempt Failure"
        systemctl --force --force reboot
    fi
else    
    rebootLog "Reboot Success!!!"
fi


