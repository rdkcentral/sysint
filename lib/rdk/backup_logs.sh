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

# Purpose: This script is used to backup the Logs
# Scope: RDK devices
# Usage: This script is triggered by systemd service 
##############################################################################

. /etc/include.properties
. /etc/device.properties

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

PREV_LOG_PATH="$LOG_PATH/PreviousLogs"
PREV_LOG_BACKUP_PATH="$LOG_PATH/PreviousLogs_backup"

backupLog() {
    timestamp=$(/bin/timestamp)
    echo "$timestamp $0: $*"
}

# create log workspace if not there
if [ ! -d "$LOG_PATH" ];then 
    mkdir -p "$LOG_PATH"
fi

# create intermediate log workspace if not there
if [ ! -d $PREV_LOG_PATH ];then
    mkdir -p $PREV_LOG_PATH
fi

# create log backup workspace if not there
if [ ! -d $PREV_LOG_BACKUP_PATH ];then
    mkdir -p $PREV_LOG_BACKUP_PATH
else
    rm  -rf $PREV_LOG_BACKUP_PATH/*
fi

if [ $APP_PERSISTENT_PATH ];then 
    PERSISTENT_PATH=$APP_PERSISTENT_PATH
else
    PERSISTENT_PATH=/opt/persistent
fi

touch $PERSISTENT_PATH/logFileBackup

# disk size check for recovery if /opt size > 90%
if  [ -f /lib/rdk/disk_threshold_check.sh ];then
    sh /lib/rdk/disk_threshold_check.sh 0
fi

backupAndRecoverLogs()
{
    source=$1
    destn=$2
    operation=$3
    s_extn=$4
    d_extn=$5

    backupLog "backupAndRecoverLogs:start source=$source, destn=$destn, operation=$operation"

    for file in $(find $source -mindepth 1 -maxdepth 1 -type f -name "$s_extn*");
    do
        $operation "$file" "$destn$d_extn${file/$source$s_extn/}"
    done
    backupLog "backupAndRecoverLogs:end"
}

last_bootfile=$(find "$PREV_LOG_PATH" -name last_reboot)
if [ -f "$last_bootfile" ];then
    rm -rf "$last_bootfile"
fi

sysLog="messages.txt"
sysLogBAK1="bak1_messages.txt"
sysLogBAK2="bak2_messages.txt"
sysLogBAK3="bak3_messages.txt"

if [ "$HDD_ENABLED" = "false" ]; then
    backupLog "HDD disabled device"
    BAK1="bak1_"
    BAK2="bak2_"
    BAK3="bak3_"
    if [ ! -f "$PREV_LOG_PATH/$sysLog" ]; then
            find $LOG_PATH -maxdepth 1 -mindepth 1 \( -type l -o -type f \) \( -iname "*.txt*" -o -iname "*.log*" -o -iname "*.bin*" -o -name "bootlog" \) -exec mv '{}' $PREV_LOG_PATH \; 
            if [ $? -ne 0 ]; then
                backupLog "Error:Failed to Move the logs from  $LOG_PATH to $PREV_LOG_PATH"
            fi
    elif [ ! -f "$PREV_LOG_PATH/$sysLogBAK1" ]; then
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" $BAK1
    elif [ ! -f "$PREV_LOG_PATH/$sysLogBAK2" ]; then
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" $BAK2
    elif [ ! -f "$PREV_LOG_PATH/$sysLogBAK3" ]; then
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" $BAK3
    else
        # box reboot within 8 minutes after reboot
        backupAndRecoverLogs "$PREV_LOG_PATH/" "$PREV_LOG_PATH/" mv "$BAK1" ""
        backupAndRecoverLogs "$PREV_LOG_PATH/" "$PREV_LOG_PATH/" mv "$BAK2" "$BAK1"
        backupAndRecoverLogs "$PREV_LOG_PATH/" "$PREV_LOG_PATH/" mv "$BAK3" "$BAK2"
        backupAndRecoverLogs "$LOG_PATH/" "$PREV_LOG_PATH/" mv "" "$BAK3"
    fi
  
   /bin/touch "$PREV_LOG_PATH/last_reboot"
   
    # logs cleanup after backup
    backupLog "Clean up $LOG_PATH"
    rm -rf $LOG_PATH/*.*
    find $LOG_PATH -name "*-*-*-*-*M-" -exec rm -rf {} \;
else
    backupLog "HDD enabled device"
    if [ ! -f "$PREV_LOG_PATH/$sysLog" ]; then
       backupLog "Move logs from $LOG_PATH to $PREV_LOG_PATH"
       find $LOG_PATH -maxdepth 1 -mindepth 1 \( -type l -o -type f \) \( -iname "*.txt*" -o -iname "*.log*" -o -name "bootlog" \) -exec mv '{}' $PREV_LOG_PATH \;
       /bin/touch $PREV_LOG_PATH/last_reboot
    else
       find "$PREV_LOG_PATH" -name last_reboot | xargs rm >/dev/null
       timestamp=$(date "+%m-%d-%y-%I-%M-%S%p")
       LogFilePathPerm="$PREV_LOG_PATH/logbackup-$timestamp"
       mkdir -p "$LogFilePathPerm"
       backupLog "Move logs from $LOG_PATH to $LogFilePathPerm"
       find "$LOG_PATH" -maxdepth 1 -mindepth 1 \( -type l -o -type f \) \( -iname "*.txt*" -o -iname "*.log*" -o -name "bootlog" \)  -exec mv '{}' "$LogFilePathPerm" \;
       /bin/touch "$LogFilePathPerm/last_reboot"
    fi
fi

if [ -f /tmp/disk_cleanup.log ];then
    mv /tmp/disk_cleanup.log "$LOG_PATH"
fi

if [ -f /tmp/mount_log.txt ];then
    mv /tmp/mount_log.txt "$LOG_PATH"
fi

if [ -f /tmp/mount-ta_log.txt ];then
    mv /tmp/mount-ta_log.txt "$LOG_PATH"
fi

cp /version.txt "$LOG_PATH"
cp /etc/skyversion.txt "${LOG_PATH}/skyversion.txt"
cp /etc/rippleversion.txt "${LOG_PATH}/rippleversion.txt"

backupLog "Send systemd notification ..."
/bin/systemd-notify --ready --status="Logs Backup Done..!"

