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


mountpoints=$(mount | grep mmc | cut -d " " -f1 | sort | uniq)

for mountpoint in $mountpoints
do
    partition_name=`echo $mountpoint | cut -d "/" -f3`
    declare filesystem_$partition_name=`mount | grep $mountpoint | cut -d " " -f5`
done


unmount()
{
     mount | grep $1
     if [ $? -eq 0 ]; then
          fuser -mk $1
          umount -l $1
     fi
     
}

unmount /opt/secure
unmount /var/lib
unmount /opt/persistent
unmount /opt/www
unmount /opt/drm
unmount /opt/wifi
unmount /opt/gp
unmount /opt/CDL
unmount /opt/oem
unmount /var/lib
unmount /opt
unmount /mnt/crit_nvs
unmount /mnt/critical
unmount /var/volatile/log
unmount /media/apps
unmount /nvram
unmount /tmp/data

for mountpoint in $mountpoints
do
    echo "Formatting $mountpoint"
    partition_name=`echo $mountpoint | cut -d "/" -f3`
    partition_type=filesystem_$partition_name
    formatoption=""
    if [ "${!partition_type}" == "ext4" ]; then
        formatoption="-F"
    elif [ "${!partition_type}" == "btrfs" ]; then
        formatoption="-f"
    fi
    mkfs.${!partition_type} $formatoption $mountpoint
    if [ $? -ne 0 ]; then
        echo "$mountpoint formatting failed with $?"
    else
        echo "$mountpoint formatting successful"
    fi

done
