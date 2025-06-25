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
    # /usr/bin/nm-online -q -t 60 # If Network manager is not online wait for 60 sec. TODO: Revisit this during connectivity check enable time
    CON_STATE=$(nmcli -t -f GENERAL.STATE device show "$interfaceName" 2>/dev/null | cut -d: -f2)
    echo "$DT_TIME Connection state of interface $interfaceName=$CON_STATE" >> /opt/logs/NMMonitor.log
    if [ "$CON_STATE" = "100 (connected)" ] || [ "$CON_STATE" = "120 (connected (site only))" ]; then
        echo "$DT_TIME Connection state of $interfaceName is connected." >> /opt/logs/NMMonitor.log
        sh /lib/rdk/connectivitycheck.sh &
    else
        echo "$DT_TIME Connection state of $interfaceName Up But Not Fully connected." >> /opt/logs/NMMonitor.log
    fi
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
        echo "$DT_TIME networkLinkEvent.sh" >> /opt/logs/NMMonitor.log

        sh -x /lib/rdk/updateGlobalIPInfo.sh "add" $mode $interfaceName $ipaddr "global"
        echo "$DT_TIME updateGlobalIPInfo.sh" >> /opt/logs/NMMonitor.log
        
        sh /lib/rdk/ipv6addressChange.sh "add" $mode $interfaceName $ipaddr "global"
        echo "$DT_TIME ipv6addressChange.sh" >> /opt/logs/NMMonitor.log

        sh /lib/rdk/networkInfoLogger.sh "add" $mode $interfaceName $ipaddr "global"
        echo "$DT_TIME networkInfoLogger.sh" >> /opt/logs/NMMonitor.log

        sh /lib/rdk/checkDefaultRoute.sh  $imode $interfaceName $ipaddr $gwip $interfaceName "metric" "add"
        echo "$DT_TIME checkDefaultRoute.sh" >> /opt/logs/NMMonitor.log

        sh /lib/rdk/ipmodechange.sh $imode $interfaceName $ipaddr $gwip $interfaceName "metric" "add"
        echo "$DT_TIME ipmodechange.sh" >> /opt/logs/NMMonitor.log
    fi
    if [ "$interfaceName" == "wlan0" ]; then
        touch /tmp/wifi-on
    fi
    if [[ "$interfaceName" == "wlan0" || "$interfaceName" == "eth0" ]]; then
       if [ "$interfaceStatus" == "dhcp6-change" ] || [ "$interfaceStatus" == "dhcp4-change" ]; then 
           sh /lib/rdk/getRouterInfo.sh $interfaceName
           echo "$DT_TIME getRouterInfo.sh" >> /opt/logs/NMMonitor.log 
       fi
    fi
fi
