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


check_empty()
{
    value=$1
    if [ -z "$1" ]; then
        value=0 #set as 0 to avoid expr syntax error
    fi
    return $value
}

flash_fail_count=`[ -r /tmp/flash_mount_failure_count ] && cat /tmp/flash_mount_failure_count`
check_empty $flash_fail_count
flash_fail_count=$?
count=`[ -r /opt/flash_mount_failure_count ] && cat /opt/flash_mount_failure_count`
check_empty $count
count=$?
count=`expr $count + $flash_fail_count`
echo $count > /opt/flash_mount_failure_count

disk_fail_count=`[ -r /tmp/disk_mount_failure_count ] && cat /tmp/disk_mount_failure_count`
check_empty $disk_fail_count
disk_fail_count=$?
count=`[ -r /opt/disk_mount_failure_count ] && cat /opt/disk_mount_failure_count`
check_empty $count
count=$?
count=`expr $count + $disk_fail_count`
echo $count > /opt/disk_mount_failure_count

if [ -f /tmp/flash_mount_failure_count ]; then
        rm /tmp/flash_mount_failure_count
fi

if [ -f /tmp/disk_mount_failure_count ]; then
        rm /tmp/disk_mount_failure_count
fi
