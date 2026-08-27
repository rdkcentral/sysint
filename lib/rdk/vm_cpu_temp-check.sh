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
TEMP_LOG="/tmp/logs/messages.txt"
RTL_LOG_FILE="$LOG_PATH/dcmscript.log"
SYSTEM_METRIC_CRON_INTERVAL="*/15 * * * *"

if [ "$LIGHTSLEEP_ENABLE" == "true" ] && [ -f /tmp/.standby ]; then
    if [ ! -d /tmp/logs ] ;then
        mkdir /tmp/logs
    fi
    if [ -f /lib/rdk/cpu-statistics.sh ];then
        sh /lib/rdk/cpu-statistics.sh >> $TEMP_LOG
    fi
    if [ -f /lib/rdk/vm-statistics.sh ];then
        sh /lib/rdk/vm-statistics.sh >> $TEMP_LOG
    fi
    if [ -f /lib/rdk/temperature-telemetry.sh ];then
        sh /lib/rdk/temperature-telemetry.sh >> $TEMP_LOG
    fi
    exit 0
else
    if [ -f $TEMP_LOG ] && [ -f /etc/os-release ]; then
        cat $TEMP_LOG >> $LOG_PATH/messages.txt
        rm $TEMP_LOG
    fi
    if [ -f /lib/rdk/cpu-statistics.sh ];then
        echo "Retrieving CPU instantaneous information for telemetry support" >> $RTL_LOG_FILE
        sh /lib/rdk/cpu-statistics.sh >> $LOG_PATH/messages.txt
    fi
    if [ -f /lib/rdk/vm-statistics.sh ];then
        echo "Retrieving virtual memory information for telemetry support" >> $RTL_LOG_FILE
        sh /lib/rdk/vm-statistics.sh >> $LOG_PATH/messages.txt
    fi
    if [ -f /lib/rdk/temperature-telemetry.sh ];then
        echo "Retrieving CPU Temperature for telemetry support" >> $RTL_LOG_FILE
        sh /lib/rdk/temperature-telemetry.sh >> $LOG_PATH/messages.txt
    fi
fi

systemHealthLog=`sh /lib/rdk/cronjobs_update.sh "check-entry" "vm_cpu_temp-check.sh"`
if [ "$systemHealthLog" != "0" ]; then
    echo "Remove existing cron Update VM and CPU stats to the messages.txt file"
    sh /lib/rdk/cronjobs_update.sh "remove" "vm_cpu_temp-check.sh"
fi
echo "Scheduling Cron Update VM and CPU stats to the messages.txt file"
sh /lib/rdk/cronjobs_update.sh "update" "vm_cpu_temp-check.sh" "$SYSTEM_METRIC_CRON_INTERVAL nice -n 10 /bin/sh $RDK_PATH/vm_cpu_temp-check.sh"
echo "Created/Updated CRONJOB to run the script on every $SYSTEM_METRIC_CRON_INTERVAL" >> $LOG_PATH/messages.txt

