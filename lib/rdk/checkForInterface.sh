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

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
    . /lib/rdk/commonUtils.sh
fi
if [ "$DEVICE_TYPE" = "mediaclient" ]; then
    . /lib/rdk/utils.sh
fi

DROPBEAR_LOG_FILE=$LOG_PATH/dropbear.log

dropbearLog () {
    echo "`/bin/timestamp` : $0: $*" >> $DROPBEAR_LOG_FILE
}

ipAddress=""
checkForInterface()
{
    interface=$1
    if [ -f /tmp/estb_ipv6 ]; then
        ipAddress=`ip addr show dev $interface | grep -i global | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d'`
    else 
        ipAddress=`ip addr show dev $interface | grep -i global | sed -e's/^.*inet \([^ ]*\)\/.*$/\1/;t;d'`
    fi
}

#RFC check for MOCA SSH enable/not.
isMOCASSHEnable=$(/usr/bin/tr181Set -d  Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MOCASSH.Enable 2>&1 > /dev/null)

dropbearLog "RFC_ENABLE_MOCASSH:$isMOCASSHEnable" 

# We'll only do this for 5 iterations before we give up.
loop=5
address=""
# mediaclient code
if [ "$DEVICE_TYPE" = "mediaclient" ]; then
    while [ $loop -gt 0 ]
    do
        if [ "$WIFI_INTERFACE" ] && [ ! "$ipAddress" ];then
            dropbearLog "Checking for wifi interface"
            checkForInterface "$WIFI_INTERFACE"
            if [ "$ipAddress" ]; then
                ipAddress+=" "
                ipAddress+=`ifconfig $WIFI_INTERFACE |grep inet | grep -v inet6 | grep -v localhost | grep -v 127.0.0.1 |tr -s ' '| cut -d ' ' -f3 | sed -e 's/addr://g'`
                dropbearLog "WiFi IP address available"
                loop=0
            fi
        fi
        Interface=`getMoCAInterface`
        if [ ! "$ipAddress" ];then
            dropbearLog "Wifi interface not available. Checking for eth"
            checkForInterface "$Interface"

            if [ "$ipAddress" ]; then
                ipAddress+=" "
                ipAddress+=`ifconfig $Interface |grep inet | grep -v inet6 | grep -v localhost | grep -v 127.0.0.1 |tr -s ' '| cut -d ' ' -f3 | sed -e 's/addr://g'`
                dropbearLog "Eth IP address available"
                loop=0
            fi
        fi
        if [ "$isMOCASSHEnable" = "true" ];then
            ipAddress+=" "
            ipAddress+=`ifconfig $MOCA_INTERFACE |grep 169.254.* |tr -s ' '| cut -d ' ' -f3 | sed -e 's/addr://g'`
            dropbearLog "IP address available from MOCA interface"
        fi
      sleep 5
      loop=$((loop-1))
   done
fi

dropbearLog "Exiting successfully"
exit 0
