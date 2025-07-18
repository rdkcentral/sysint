#!/bin/sh

####################################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2024 Comcast Cable Communications Management, LLC
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
####################################################################################

NM_LOG_FILE="/opt/logs/NMMonitor.log"
NMdispatcherLog()
{
    echo "$(/bin/timestamp) : $0: $*" >> $NM_LOG_FILE
}
NMdispatcherLog "From NM_Dispatcher.sh $1 $2"

interfaceName=$1
interfaceStatus=$2

if [ "$interfaceStatus" = "up" ]; then
    CON_STATE=$(nmcli -t -f GENERAL.STATE device show "$interfaceName" 2>/dev/null | cut -d: -f2)
    NMdispatcherLog "Connection state of interface $interfaceName=$CON_STATE"
fi

if [ "x$interfaceName" != "x" ] && [ "$interfaceName" != "lo" ]; then
    if [ "$interfaceStatus" == "dhcp4-change" ]; then
        mode="ipv4"
        gwip=$(/sbin/ip -4 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}')
        imode=2
        ipaddr=$(ifconfig $interfaceName | grep -w inet | awk -F ' ' '{print $2}' | awk -F ':' '{print $2}')
    elif [ "$interfaceStatus" == "dhcp6-change" ]; then
        mode="ipv6"
        ipaddr=$(ifconfig $interfaceName | grep -w inet6 | grep Global | awk -F " " '{print $3}' | tail -n1 | cut -d '/' -f1)
        imode=10
        gwip=$(/sbin/ip -6 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}')
    fi

    if [ "$interfaceStatus" == "dhcp6-change" ] || [ "$interfaceStatus" == "dhcp4-change" ]; then
        sh /lib/rdk/networkLinkEvent.sh $interfaceName "add"
        NMdispatcherLog "networkLinkEvent.sh"

        sh -x /lib/rdk/updateGlobalIPInfo.sh "add" $mode $interfaceName $ipaddr "global"
        NMdispatcherLog "updateGlobalIPInfo.sh"
        
        sh /lib/rdk/ipv6addressChange.sh "add" $mode $interfaceName $ipaddr "global"
        NMdispatcherLog "ipv6addressChange.sh"

        sh /lib/rdk/networkInfoLogger.sh "add" $mode $interfaceName $ipaddr "global"
        NMdispatcherLog "networkInfoLogger.sh"

        sh /lib/rdk/checkDefaultRoute.sh  $imode $interfaceName $ipaddr $gwip $interfaceName "metric" "add"
        NMdispatcherLog "checkDefaultRoute.sh"

        sh /lib/rdk/ipmodechange.sh $imode $interfaceName $ipaddr $gwip $interfaceName "metric" "add"
        NMdispatcherLog "ipmodechange.sh"
    fi
    if [ "$interfaceName" == "wlan0" ]; then
        touch /tmp/wifi-on
    fi
    if [[ "$interfaceName" == "wlan0" || "$interfaceName" == "eth0" ]]; then
       if [ "$interfaceStatus" == "dhcp6-change" ] || [ "$interfaceStatus" == "dhcp4-change" ]; then 
           sh /lib/rdk/getRouterInfo.sh $interfaceName
           NMdispatcherLog "getRouterInfo.sh"
       fi
    fi
fi
