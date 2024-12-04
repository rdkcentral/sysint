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


# exit if an instance is already running
if [ ! -f /tmp/.hdd-status.pid ];then
    echo $$ > /tmp/.hdd-status.pid
else
    pid=`cat /tmp/.hdd-status.pid`
    if [ -d /proc/$pid ];then
         exit 0
    fi
fi

pidCleanup()
{
  if [ -f /tmp/.hdd-status.pid ];then rm -rf /tmp/.hdd-status.pid ; fi
}

if [ -f /tmp/.standby ]; then
   # No logging or HDD access during standby mode
   pidCleanup
   exit 0
fi

. /etc/include.properties
. /etc/device.properties

HDD_LOG_FILE=$LOG_PATH/diskinfo.log

PATH="${PATH}:/bin:/usr/bin"

hddNode=`/bin/mount | grep 'rtdev' | head -n1 | sed -e "s|.*rtdev=||g" -e "s|,.*||g"`

if [ ! "$hddNode" ]; then
   echo "`/bin/timestamp` No HDD or SD card attached !!!" >> $HDD_LOG_FILE
   pidCleanup
   exit 0
fi

if [ ! -f $HDD_LOG_FILE ]; then
     echo "" > $HDD_LOG_FILE
fi

echo "===================== `/bin/timestamp` =========================" >> $HDD_LOG_FILE
/usr/sbin/smartctl -a "$hddNode" >> $HDD_LOG_FILE
echo "==============================================================" >> $HDD_LOG_FILE

pidCleanup
