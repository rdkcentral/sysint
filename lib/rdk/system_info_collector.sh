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
#############################################################################

# Purpose: Collect system information and log it to a file
# Scope: This script is used to collect system information on RDK devices
# Usage: This script should be run periodically to collect system information

. /etc/include.properties
. /etc/device.properties
. /etc/env_setup.sh

count=0

log_disk_usage() {
    echo "********** Disk Space Usage **********" 
    /bin/df -h 
}

# Function to run the appropriate top command based on device type
run_top_command() {
        top -b -o +%CPU | head -n 17 
}

# Function to collect CPU statistics
cpu_statistics() {
        iostat -c 1 2 > /tmp/.intermediate_calc
	sed -i '/^$/d' /tmp/.intermediate_calc
	echo "INSTANTANEOUS CPU INFORMATIONS"
	values=`sed '5q;d' /tmp/.intermediate_calc| tr -s " " | cut -c2-| tr ' ' ','`
	echo cpuInfoHeader: %user,%nice,%system,%iowait,%steal,%idle
	echo cpuInfoValues: $values
	t2ValNotify "cpuinfo_split" "$values"
	free | awk '/Mem/{printf("USED_MEM:%d\nFREE_MEM:%d\n"),$3,$4}'
	mem=`free | awk '/Mem/{printf $4}'`
	t2ValNotify "FREE_MEM_split" "$mem"
}


# Adding the Clock Frequency Info
echo "Clock Frequency Info:"
grep 'MHz' /proc/cpuinfo | sed 's/[[:blank:]]*//g' 

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    . /lib/rdk/t2Shared_api.sh
fi

# Logging to top_log.txt directly only for Legacy platforms.
# Making echo of all the logs so that it directly goes to journal buffer to support lightsleep on HDD enabled Yocto platforms.
    echo "Logging for Yocto platforms..."
    /bin/timestamp 
    uptime 
    run_top_command
    log_disk_usage
    cpu_statistics

    if [ -f /tmp/.top_count ]; then
	curr_count=`cat /tmp/.top_count`
        count=$(( curr_count + 1 ))
	if [ $count -eq 6 ]; then
		top -b -n1 | grep -vE 'grep|run.sh'
		cat /proc/meminfo
		count=0
	fi
fi
echo "$count" > /tmp/.top_count
