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

if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

if [ -f /etc/common.properties ];then
    . /etc/common.properties
fi

if [ -f /lib/rdk/utils.sh ]; then
    source /lib/rdk/utils.sh
fi

DT_TIME=$(date +'%Y-%m-%d:%H:%M:%S:%6N')
echo "$DT_TIME From NM_Dispatcher.sh $1 $2" >> /opt/logs/NMMonitor.log

NM_LOG_FILE="/opt/logs/NMMonitor.log"
FILE=/tmp/.GatewayIP_dfltroute

NMdispatcherLog()
{
    echo "$(/bin/timestamp) : $0: $*" >> $NM_LOG_FILE
}

checkDefaultRoute_Delete() {
        #Condition to check for arguments are 7 and not 0.
        if [ $# -eq 0 ] || [ $# -ne 7 ];then
                echo "No. of arguments supplied are not satisfied, Exiting..!!!"
                echo "Arguments accepted are [ family | interface | destinationip | gatewayip | preferred_src | metric | add/delete]"
                return 1
        fi

        NMdispatcherLog "Input Arguments : $* "
        opern="$7"
        gtwip="$4"

        if [ "$opern" = "delete" ]; then
                #Remove flag and IP for delete operation
                NMdispatcherLog "Deleting Route Flag"
                sed -i "/$gtwip/d" $FILE
                [ -s $FILE ] || rm -rf /tmp/route_available
        else
                NMdispatcherLog "Received operation:$opern is Invalid..!!"
        fi
}

updateGlobalIPInfo_delete() {
    cmd=$1
    mode=$2
    ifc=$3
    addr=$4
    flags=$5
    
    NMdispatcherLog "Arguments: cmd:$1, mode:$2, ifc:$3, addr:$4, flags:$5" 

    if [ "x$cmd" == "xdelete" ] && [ "x$flags" == "xglobal" ]; then

        if [[ "$ifc" == "$ESTB_INTERFACE" || "$ifc" == "$DEFAULT_ESTB_INTERFACE" || "$ifc" == "$ESTB_INTERFACE:0" ]]; then
            check_valid_IPaddress
            NMdispatcherLog "Updating Box/ESTB IP"
            rm /tmp/.$mode$ESTB_INTERFACE
            refresh_devicedetails "estb_ip"
        elif [[ "$ifc" == "$MOCA_INTERFACE" || "$ifc" == "$MOCA_INTERFACE:0" ]]; then
            NMdispatcherLog "Updating MoCA IP"
            rm /tmp/.$mode$MOCA_INTERFACE
            refresh_devicedetails "moca_ip"
        elif [[ "$ifc" == "$WIFI_INTERFACE" || "$ifc" == "$WIFI_INTERFACE:0" ]]; then
            check_valid_IPaddress
            NMdispatcherLog "Updating Wi-Fi IP"
            rm /tmp/.$mode$WIFI_INTERFACE
            refresh_devicedetails "boxIP"
        fi
    fi
}

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

        sh /lib/rdk/ipv6addressChange.sh "delete" $mode4 $interfaceName $ipaddr4 "global"
        sh /lib/rdk/ipv6addressChange.sh "delete" $mode6 $interfaceName $ipaddr6 "global"
        echo "$DT_TIME ipv6addressChange.sh" >> /opt/logs/NMMonitor.log

        checkDefaultRoute_Delete  $imode4 $interfaceName $ipaddr4 $gwip4 $interfaceName "metric" "delete"
        checkDefaultRoute_Delete  $imode6 $interfaceName $ipaddr6 $gwip6 $interfaceName "metric" "delete"
        echo "$DT_TIME checkDefaultRoute_Delete" >> /opt/logs/NMMonitor.log

        updateGlobalIPInfo_delete "delete" $mode4 $interfaceName $ipaddr4 "global"
        updateGlobalIPInfo_delete "delete" $mode6 $interfaceName $ipaddr6 "global"
        echo "$DT_TIME updateGlobalIPInfo_delete" >> /opt/logs/NMMonitor.log
fi
