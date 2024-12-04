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


if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

IP_REMOTE_SUPPORT_INTERFACE_FILE='/tmp/ipremote_interface_info'
IP_REMOTE_INTERFACE_ENABLE_PREFIX='/tmp/ipremote_enabled'
IP_REMOTE_ENABLED_FLAG='/tmp/ipremote_boot_enabled'

cmd=$1
mode=$2
ifc=$3
addr=$4
flags=$5
pop_intf="NULL_INTF"
devtype=$DEVICE_TYPE
max_retries=5
retry_count=0

# Description: Populates the ip and macaddress
# for ipremote.
# args : interface
populate_interface_details()
{

    macaddress=`ifconfig $1 | grep HWaddr | tr -s ' ' | cut -d ' ' -f5`
    echo "Interface=$1" > $IP_REMOTE_SUPPORT_INTERFACE_FILE
    echo "Ipv4_Address=$addr" >> $IP_REMOTE_SUPPORT_INTERFACE_FILE
    echo "MAC_Address=$macaddress" >> $IP_REMOTE_SUPPORT_INTERFACE_FILE
}

# Wait for maximum of 10 seconds for the file
while [ $retry_count -lt $max_retries ]; do
    if [ -f ${IP_REMOTE_ENABLED_FLAG} ]; then
        break
    fi

    sleep 2
    retry_count=$((retry_count + 1))
done

if [ ! -f ${IP_REMOTE_ENABLED_FLAG} ];then
    exit 0
fi

(/bin/busybox kill -STOP $$; /bin/busybox kill -CONT $$)
# Global Address Add Event
if [ "$cmd" = "add" ] && [ "$mode" = "ipv4" ] && [ "$flags" = "global" ];then
    # Check for interface type, The ip remote uses virtual wifi interface
    if [ "$ifc" = "$WIFI_INTERFACE:0" ] && [ "$IPREMOTE_WIFI" = "true" ] && [ -f ${IP_REMOTE_INTERFACE_ENABLE_PREFIX}_${WIFI_INTERFACE} ];then
        pop_intf=$WIFI_INTERFACE:0
        echo "IP Remote details populated for $pop_intf interface"
    elif [ "$IPREMOTE_ETHERNET" = "true" ] && [ -f ${IP_REMOTE_INTERFACE_ENABLE_PREFIX}_${ETHERNET_INTERFACE} ];then
         # Populate eth0:0 for mediaclient devices and eth0 for hybrid devices
         if [ "$ifc" = "$ETHERNET_INTERFACE:0" ] && [ "$devtype" = "mediaclient" ]; then
             pop_intf=$ETHERNET_INTERFACE:0
         elif [ "$ifc" = "$ETHERNET_INTERFACE" ] && [ "$devtype" = "hybrid" ]; then
             pop_intf=$ETHERNET_INTERFACE
         fi
         echo "IP Remote details populated for $pop_intf interface"
    fi

    if [ "$pop_intf" != "NULL_INTF" ]; then
        populate_interface_details "$pop_intf"
    fi
    
fi
