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
PREV_LOG_PATH="$LOG_PATH/PreviousLogs"

verifyProcess ()
{
    processpid=$(pidof $1)
    if [ ! "$processpid" ];then
         exit 0
    fi
}

mode=$1
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
    echo "Reading Reboot information from rebootInfo.log file"
    last_reboot_file=""
    last_bootfile=$(find $PREV_LOG_PATH -name last_reboot)
    last_log_path=$(echo ${last_bootfile%/*})
    echo "LOG PATH: $last_log_path"
    if [ -f "$last_log_path/rebootInfo.log" ] && [ "$last_log_path" ];then
          last_reboot_file=$last_log_path/rebootInfo.log
    elif [ -f /opt/logs/PreviousLogs/rebootInfo.log ];then
          last_reboot_file=/opt/logs/PreviousLogs/rebootInfo.log
    else
          echo "Missing last reboot reason log file..!"
    fi
    
    # If box gets rebooted before 8mins from bootup on Non HDD devices
    if [ "$last_reboot_file" = "$PREV_LOG_PATH/rebootInfo.log" ]; then
         for file in $PREV_LOG_PATH/bak[1-3]_rebootInfo.log; do
             [ -f "$file" ] && last_reboot_file="$file"
         done
    fi
    echo "Last reboot File = $last_reboot_file"

    if [ -f "$last_reboot_file" ]; then
            rebootReason=$(grep "RebootReason:" "$last_reboot_file" | grep -v -E "HAL_SYS_Reboot|PreviousRebootReason")
            rebootInitiatedBy=$(awk -F 'RebootInitiatedBy:' '/RebootInitiatedBy:/ && !/PreviousRebootInitiatedBy/ {gsub(/ /, "", $2); print $2}' "$last_reboot_file")
            rebootTime=$(awk -F 'RebootTime:' '/RebootTime:/ && !/PreviousRebootTime/ {print $2}' "$last_reboot_file")
            customReason=$(awk -F 'CustomReason:' '/CustomReason:/ && !/PreviousCustomReason/ {print $2}' "$last_reboot_file")
          if [ "$rebootInitiatedBy" = "HAL_SYS_Reboot" ]; then
              rebootInitiatedBy=$(awk -F 'Triggered from ' '/RebootReason:/ && !/HAL_SYS_Reboot/ && !/PreviousRebootReason/ {print $2}' "$last_reboot_file" | awk '{print $1}')
              otherReason=$(awk -F 'Triggered from ' '/RebootReason:/ && !/HAL_SYS_Reboot/ && !/PreviousRebootReason/ {sub(/^[^ ]* /, "", $2); sub(/\(.*$/, "", $2); print $2}' "$last_reboot_file")
          else
              otherReason=$(awk -F 'OtherReason:' '/OtherReason:/ && !/PreviousOtherReason/ {print $2}' "$last_reboot_file")
          fi
    fi

    echo "$(/bin/timestamp) PreviousRebootReason: $rebootReason" > $LOG_FILE
    echo "$(/bin/timestamp) PreviousRebootInitiatedBy: $rebootInitiatedBy" >> $LOG_FILE
    echo "$(/bin/timestamp) PreviousRebootTime: $rebootTime" >> $LOG_FILE
    echo "$(/bin/timestamp) PreviousCustomReason: $customReason" >> $LOG_FILE
    echo "$(/bin/timestamp) PreviousOtherReason: $otherReason" >> $LOG_FILE
    touch /tmp/rebootInfo_Updated
    sh /lib/rdk/update_previous_reboot_info.sh
else
    echo "Usage: $0 <bootup/shutdown>"
fi
exit 0
