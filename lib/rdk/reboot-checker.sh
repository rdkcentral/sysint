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

# Purpose: This script handles reboot information logging and updating.
# Scope: This script is used during bootup and shutdown to log and update reboot information in RDK devices
# Usage: $0 <bootup/shutdown> 
##############################################################################


. /etc/include.properties
. /etc/device.properties

if [ ! -f /tmp/set_crash_reboot_flag -a "$1" != "bootup" ];then
     touch /tmp/set_crash_reboot_flag
fi
LOG_FILE=/opt/logs/rebootInfo.log
verifyProcess ()
{
    processpid=$(pidof $1)
    if [ ! "$processpid" ];then
         exit 0
    fi
}

boot_mode=$1
process=$2

if [ "$1" = "shutdown" ];then
    case "$process" in
         iarmbusd)
               verifyProcess "IARMDaemonMain"
                ;;
         dsmgr)
               verifyProcess "dsMgrMain"
                ;;
         *)
                echo "Unknown process (not in the reboot list)..!"
                ;;
     esac
elif [ "$1" = "bootup" ];then
    if [ -f /opt/.rebootInfo.log ];then
          rebootReason=`cat /opt/.rebootInfo.log | grep "RebootReason:" | grep -v "HAL_SYS_Reboot" | grep -v "PreviousRebootReason" | grep -v grep`
          rebootInitiatedBy=`cat /opt/.rebootInfo.log | grep "RebootInitiatedBy:" | grep -v "PreviousRebootInitiatedBy" | grep -v grep | awk -F 'RebootInitiatedBy:' '{print $2}' | sed 's/ //g'`
          rebootTime=`cat /opt/.rebootInfo.log | grep "RebootTime:" | grep -v "PreviousRebootTime" | grep -v grep | awk -F 'RebootTime:' '{print $2}'`
          customReason=`cat /opt/.rebootInfo.log | grep "CustomReason:" | grep -v "PreviousCustomReason" | grep -v grep | awk -F 'CustomReason:' '{print $2}'`
          if [ "$rebootInitiatedBy" == "HAL_SYS_Reboot" ]; then
              rebootInitiatedBy=`cat /opt/.rebootInfo.log | grep "RebootReason:" | grep -v "HAL_SYS_Reboot" | grep -v "PreviousRebootReason" | grep -v grep | sed -n 's/.* Triggered from \([^ ]*\).*/\1/p'`
              otherReason=`cat /opt/.rebootInfo.log | grep "RebootReason:" | grep -v "HAL_SYS_Reboot" | grep -v "PreviousRebootReason" | grep -v grep | awk -F 'Triggered from ' '{print $2}' | sed 's/[^ ]* *//' | sed 's/(.*//'`
          else
              otherReason=`cat /opt/.rebootInfo.log | grep "OtherReason:" | grep -v "PreviousOtherReason" | grep -v grep | awk -F 'OtherReason:' '{print $2}'`
          fi
          echo "`/bin/timestamp` PreviousRebootReason: $rebootReason" >> $LOG_FILE
          echo "`/bin/timestamp` PreviousRebootInitiatedBy: $rebootInitiatedBy" >> $LOG_FILE
          echo "`/bin/timestamp` PreviousRebootTime: $rebootTime" >> $LOG_FILE
          echo "`/bin/timestamp` PreviousCustomReason: $customReason" >> $LOG_FILE
          echo "`/bin/timestamp` PreviousOtherReason: $otherReason" >> $LOG_FILE
          rm /opt/.rebootInfo.log
    fi
    last_reboot_file=""
    last_bootfile=`find /opt/logs/PreviousLogs/ -name last_reboot`
    last_log_path=`echo ${last_bootfile%/*}`
    echo "LOG PATH: $last_log_path"
    if [ -f "$last_log_path/rebootInfo.log" ] && [ "$last_log_path" ];then
          last_reboot_file=$last_log_path/rebootInfo.log
    elif [ -f /opt/logs/PreviousLogs/rebootInfo.log ];then
          last_reboot_file=/opt/logs/PreviousLogs/rebootInfo.log
    else
          echo "Missing last reboot reason log file..!"
    fi

    # If box gets rebooted before 8mins from bootup on Non HDD devices
    if [ "$last_reboot_file" = "/opt/logs/PreviousLogs/rebootInfo.log" ];then
        if [ -f /opt/logs/PreviousLogs/bak1_rebootInfo.log ];then
            last_reboot_file=/opt/logs/PreviousLogs/bak1_rebootInfo.log
        fi
        if [ -f /opt/logs/PreviousLogs/bak2_rebootInfo.log ];then
            last_reboot_file=/opt/logs/PreviousLogs/bak2_rebootInfo.log
        fi
        if [ -f /opt/logs/PreviousLogs/bak3_rebootInfo.log ];then
            last_reboot_file=/opt/logs/PreviousLogs/bak3_rebootInfo.log
        fi
    fi
    echo "Last reboot File = $last_reboot_file"

    if [ -f "$last_reboot_file" ]; then
            rebootReason=`cat $last_reboot_file | grep "RebootReason:" | grep -v "HAL_SYS_Reboot" | grep -v "PreviousRebootReason" | grep -v grep`
            rebootInitiatedBy=`cat $last_reboot_file | grep "RebootInitiatedBy:" | grep -v "PreviousRebootInitiatedBy" | grep -v grep | awk -F 'RebootInitiatedBy:' '{print $2}' | sed 's/ //g'`
            rebootTime=`cat $last_reboot_file | grep "RebootTime:" | grep -v "PreviousRebootTime" | grep -v grep | awk -F 'RebootTime:' '{print $2}'`
            customReason=`cat $last_reboot_file | grep "CustomReason:" | grep -v "PreviousCustomReason" | grep -v grep | awk -F 'CustomReason:' '{print $2}'`
          if [ "$rebootInitiatedBy" == "HAL_SYS_Reboot" ]; then
              rebootInitiatedBy=`cat $last_reboot_file | grep "RebootReason:" | grep -v "HAL_SYS_Reboot" | grep -v "PreviousRebootReason" | grep -v grep | sed -n 's/.* Triggered from \([^ ]*\).*/\1/p'`
              otherReason=`cat $last_reboot_file | grep "RebootReason:" | grep -v "HAL_SYS_Reboot" | grep -v "PreviousRebootReason" | grep -v grep | awk -F 'Triggered from ' '{print $2}' | sed 's/[^ ]* *//' | sed 's/(.*//'`
          else
              otherReason=`cat $last_reboot_file | grep "OtherReason:" | grep -v "PreviousOtherReason" | grep -v grep | awk -F 'OtherReason:' '{print $2}'`
          fi
    fi

    echo "`/bin/timestamp` PreviousRebootReason: $rebootReason" >> $LOG_FILE
    echo "`/bin/timestamp` PreviousRebootInitiatedBy: $rebootInitiatedBy" >> $LOG_FILE
    echo "`/bin/timestamp` PreviousRebootTime: $rebootTime" >> $LOG_FILE
    echo "`/bin/timestamp` PreviousCustomReason: $customReason" >> $LOG_FILE
    echo "`/bin/timestamp` PreviousOtherReason: $otherReason" >> $LOG_FILE
    touch /tmp/rebootInfo_Updated
    sh /lib/rdk/updatePreviousRebootInfo.sh
else
    echo "Usage: $0 <bootup/shutdown>"
fi
exit 0

