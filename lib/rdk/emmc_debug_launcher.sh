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


if [ -f /etc/include.properties ];then
    . /etc/include.properties
fi
if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

#Check whether data dump log is not desabled
if [ -f /opt/.disable_data_dump ]; then
      echo "`/bin/timestamp` Request to disable EMMC DEBUG or unsupported Platform, exiting.." >> /opt/logs/emmc_debug.log
      exit 0
fi

#eMMCMitigationDisabled=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.eMMCMitigation.Disable 2>&1 > /dev/null`
#echo "eMMCMitigationDisabled:$eMMCMitigationDisabled" >> /opt/logs/emmc_debug.log
#if [ "$eMMCMitigationDisabled" == "true" ]; then
#      echo "eMMCMitigation is disabled.. Exiting" >> /opt/logs/emmc_debug.log
#      exit 0
#fi
echo "`/bin/timestamp` eMMCMitigation is enabled " >> /opt/logs/emmc_debug.log

if [ -f /opt/emmc_debug_config -a -s /opt/emmc_debug_config ];then
    delimiter_count=`cat /opt/emmc_debug_config | awk -F' ' '{ print NF }'`
    echo "No: of Entries in Config File: $delimiter_count"
    if [ $delimiter_count -ge 2 ];then
         default_size=`cat /opt/emmc_debug_config | cut -d " " -f2`
         default_interval=`cat /opt/emmc_debug_config | cut -d " " -f1`
    else
         default_interval=`cat /opt/emmc_debug_config | cut -d " " -f1`
         echo $default_interval 4 > /opt/emmc_debug_config
    fi
fi

echo "`/bin/timestamp` Configuring EMMC Debug with Interval: $default_interval size= $default_size" >> /opt/logs/emmc_debug.log
if [ "x$default_interval" == "x" ];then
      default_interval=30
      echo "`/bin/timestamp` Configuring Default EMMC Debug Interval: $default_interval mins" >> /opt/logs/emmc_debug.log 
fi
if [ "x$default_size" == "x" ];then
      default_size=4
      echo "`/bin/timestamp` Configuring Default EMMC Debug size: $default_size" >> /opt/logs/emmc_debug.log 
fi
if [ ! -f /tmp/emmc_debug_config ];then
         echo "`/bin/timestamp` EMMC Debug Interval Backup" >> /opt/logs/emmc_debug.log
         echo "`/bin/timestamp` Configuring EMMC Debug with Interval: $default_interval size= $default_size" >> /opt/logs/emmc_debug.log
         echo $default_interval $default_size > /tmp/emmc_debug_config
fi

if [ -f /lib/rdk/dumpDummyData.sh ]; then
       output=`sh /lib/rdk/cronjobs_update.sh "check-entry" "dumpDummyData.sh"`
       if [ "$output" == "0" ]; then
             # Set new cron job from the file
             sh /lib/rdk/cronjobs_update.sh "add" "dumpDummyData.sh" "*/$default_interval * * * * sh /lib/rdk/dumpDummyData.sh $default_size"
       else
             echo "`/bin/timestamp` cron Job for dumpDummyData.sh is already configured" >> /opt/logs/emmc_debug.log  
             delimiter_count=`cat /tmp/emmc_debug_config | awk -F' ' '{ print NF }'`
             echo "No: of Entries in current Config File: $delimiter_count"
             if [ $delimiter_count -ge 2 ];then
                  current_size=`cat /tmp/emmc_debug_config | cut -d " " -f2`
                  current_interval=`cat /tmp/emmc_debug_config | cut -d " " -f1`
             else
                  current_interval=`cat /tmp/emmc_debug_config | cut -d " " -f1`
             fi
             echo `/bin/timestamp` TEST: $current_interval $current_size $default_interval $default_size >> /opt/logs/emmc_debug.log
             echo `/bin/timestamp` $current_interval $current_size $default_interval $default_size >> /opt/logs/emmc_debug.log
             if [ "x$current_interval" != "x" -o "y$current_size" != "y" ];then
                if [ $current_interval -ne $default_interval -o $current_size -ne $default_size ];then
                   echo "`/bin/timestamp` Interval change in dumpDummyData.sh configured" >> /opt/logs/emmc_debug.log  
                   cp /opt/emmc_debug_config /tmp/
                   # Set new cron job from the file
                   sh /lib/rdk/cronjobs_update.sh "update" "dumpDummyData.sh" "*/$default_interval * * * * sh /lib/rdk/dumpDummyData.sh $default_size"
                   echo "`/bin/timestamp` Listing cronjobs: `crontab -l -c /var/spool/cron/`" >> /opt/logs/emmc_debug.log
                fi
             fi
       fi
fi
