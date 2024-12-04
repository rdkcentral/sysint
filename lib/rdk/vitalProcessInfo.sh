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
. /etc/env_setup.sh

LOG_FILE=/opt/logs/top_log.txt
count=0

# XRE-11056: Added rdkbrowser2, WPE* and rtrmfplayer to the list of dumped processes for XI and XG.
if [ "$DEVICE_TYPE" = "mediaclient" ]; then
        top_cmd="top -b -o +%CPU | head -n 17"
elif [ "$DEVICE_TYPE" = "hybrid" ]; then
     top_cmd="top | grep -E 'load|Tasks|Cpu|Mem|Swap|COMMAND|rmfStreamer|Receiver|lighttpd|IARMDaemonMain|dsMgrMain|runPod|Main|nrdPluginApp|rdkbrowser2|rtrmfplayer|WPE|fogcli' | grep -vE 'grep|run.sh'"
else
     top_cmd="top | grep -E 'load|Tasks|Cpu|Mem|Swap|COMMAND|mpeos|Receiver|uimgr_main|lighttpd|IARMDaemonMain|dsMgrMain|Main|nrdPluginApp|fogcli' | grep -vE 'grep|run.sh'"
fi

# adding sleep of 180 sec to reduce high load condition during bootup
if [ ! -f /etc/os-release ]; then
    sleep 180
fi

# Adding the Clock Frequency Info
echo "Clock Frequency Info:"
cat /proc/cpuinfo | grep MH | sed 's/[[:blank:]]*//g'

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

cpu_statistics()
{
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

# Logging to top_log.txt directly only for Legacy platforms.
# Making echo of all the logs so that it directly goes to journal buffer to support lightsleep on HDD enabled Yocto platforms.
echo "Logging for Yocto platforms..."
echo "`/bin/timestamp`"
	uptime
eval $top_cmd
echo "********** Disk Space Usage **********"
echo "`/bin/df -h`"
	
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

