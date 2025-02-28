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

DT_TIME=$(date +'%Y-%m-%d:%H:%M:%S:%6N')
echo "$DT_TIME From NM_Dispatcher.sh $1 $2" >> /opt/logs/NMMonitor.log

interfaceName=$1
interfaceStatus=$2

if [ "x$interfaceName" != "x" ] && [ "$interfaceName" != "lo" ]; then
        if [ "$interfaceName" == "wlan0" ]; then
                rm /tmp/wifi-on
        fi
        mode4="ipv4"
        gwip4=$(/sbin/ip -4 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}')
        imode4=2
        ipaddr4=$(ifconfig $interfaceName | grep -w inet | awk -F ' ' '{print $2}' | awk -F ':' '{print $2}')
        echo "IPADDR4 = $ipaddr4" >> /opt/logs/NMMonitor.log
        mode6="ipv6"
        ipaddr6=$(ifconfig $interfaceName | grep -w inet6 | grep Global | awk -F " " '{print $3}' | tail -n1 | cut -d '/' -f1)
        echo "IPADDR6 = $ipaddr6" >> /opt/logs/NMMonitor.log
        imode6=10
        gwip6=$(/sbin/ip -6 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}')


        sh /lib/rdk/networkLinkEvent.sh $interfaceName "delete"
        echo "$DT_TIME networkLinkEvent.sh" >> /opt/logs/NMMonitor.log

        sh /lib/rdk/ipv6addressChange.sh "delete" $mode4 $interfaceName $ipaddr4 "global"
        sh /lib/rdk/ipv6addressChange.sh "delete" $mode6 $interfaceName $ipaddr6 "global"
        echo "$DT_TIME ipv6addressChange.sh" >> /opt/logs/NMMonitor.log

        sh /lib/rdk/checkDefaultRoute.sh  $imode4 $interfaceName $ipaddr4 $gwip4 $interfaceName "metric" "delete"
        sh /lib/rdk/checkDefaultRoute.sh  $imode6 $interfaceName $ipaddr6 $gwip6 $interfaceName "metric" "delete"
        echo "$DT_TIME checkDefaultRoute.sh" >> /opt/logs/NMMonitor.log

        sh -x /lib/rdk/updateGlobalIPInfo.sh "delete" $mode4 $interfaceName $ipaddr4 "global"
        sh -x /lib/rdk/updateGlobalIPInfo.sh "delete" $mode6 $interfaceName $ipaddr6 "global"
        echo "$DT_TIME updateGlobalIPInfo.sh" >> /opt/logs/NMMonitor.log

        sh /lib/rdk/ipmodechange.sh $imode4 $interfaceName $ipaddr4 $gwip4 $interfaceName "metric" "delete"
        sh /lib/rdk/ipmodechange.sh $imode6 $interfaceName $ipaddr6 $gwip6 $interfaceName "metric" "delete"
        echo "$DT_TIME ipmodechange.sh" >> /opt/logs/NMMonitor.log
fi
