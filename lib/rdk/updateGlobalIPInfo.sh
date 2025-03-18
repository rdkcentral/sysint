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


. /etc/device.properties

cmd=$1
mode=$2
ifc=$3
addr=$4
flags=$5

refresh_devicedetails()
{
    #Refresh device cache info
    if [ -f /lib/rdk/getDeviceDetails.sh ]; then
        sh /lib/rdk/getDeviceDetails.sh refresh $1
    else
        echo "DeviceDetails file not present"
    fi
}

check_valid_IPaddress()
{
    # Neglect IPV6 ULA address and autoconfigured IPV4 address
    if [ "x$mode" == "xipv6" ]; then
        if [[ $addr == fc* || $addr == fd* ]]; then
            exit
        fi
    elif [ "x$mode" == "xipv4" ]; then
        autoIPTrunc=`echo $addr | cut -d "." -f1-2 `
        if [ "$autoIPTrunc" == "169.254" ]; then
            exit
        fi
    fi
}


echo "updateGlobalIPInfo.sh Arguments: cmd:$1, mode:$2, ifc:$3, addr:$4, flags:$5"
(/bin/busybox kill -STOP $$; /bin/busybox kill -CONT $$)

if [ "x$cmd" == "xadd" ] && [ "x$flags" == "xglobal" ]; then

    if [[ "$ifc" == "$ESTB_INTERFACE" || "$ifc" == "$DEFAULT_ESTB_INTERFACE" || "$ifc" == "$ESTB_INTERFACE:0" ]]; then
        check_valid_IPaddress
        echo "Updating Box/ESTB IP"
        echo "$addr" > /tmp/.$mode$ESTB_INTERFACE
        refresh_devicedetails "estb_ip"
    elif [[ "$ifc" == "$MOCA_INTERFACE" || "$ifc" == "$MOCA_INTERFACE:0" ]]; then
        echo "Updating MoCA IP"
        echo "$addr" > /tmp/.$mode$MOCA_INTERFACE
        refresh_devicedetails "moca_ip"
    elif [[ "$ifc" == "$WIFI_INTERFACE" || "$ifc" == "$WIFI_INTERFACE:0" ]]; then
        check_valid_IPaddress
        echo "Updating Wi-Fi IP"
        echo "$addr" > /tmp/.$mode$WIFI_INTERFACE
        refresh_devicedetails "boxIP"
    fi
fi

if [ "x$cmd" == "xdelete" ] && [ "x$flags" == "xglobal" ]; then

    if [[ "$ifc" == "$ESTB_INTERFACE" || "$ifc" == "$DEFAULT_ESTB_INTERFACE" || "$ifc" == "$ESTB_INTERFACE:0" ]]; then
        check_valid_IPaddress
        echo "Updating Box/ESTB IP"
        rm /tmp/.$mode$ESTB_INTERFACE
        refresh_devicedetails "estb_ip"
    elif [[ "$ifc" == "$MOCA_INTERFACE" || "$ifc" == "$MOCA_INTERFACE:0" ]]; then
        echo "Updating MoCA IP"
        rm /tmp/.$mode$MOCA_INTERFACE
        refresh_devicedetails "moca_ip"
    elif [[ "$ifc" == "$WIFI_INTERFACE" || "$ifc" == "$WIFI_INTERFACE:0" ]]; then
        check_valid_IPaddress
        echo "Updating Wi-Fi IP"
        rm /tmp/.$mode$WIFI_INTERFACE
        refresh_devicedetails "boxIP"
    fi
fi
