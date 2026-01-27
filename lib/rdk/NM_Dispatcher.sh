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

# Include File check
if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

if [ -f /etc/common.properties ];then
    . /etc/common.properties
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

NM_LOG_FILE="/opt/logs/NMMonitor.log"
LOG_FILE="/opt/logs/ipSetupLogs.txt"
FILE=/tmp/.GatewayIP_dfltroute

NMdispatcherLog()
{
    echo "$(/bin/timestamp) : $0: $*" >> $NM_LOG_FILE
}

# Refactored from updateGlobalIPInfo.sh
refresh_devicedetails()
{
    #Refresh device cache info
    if [ -f /lib/rdk/getDeviceDetails.sh ]; then
        sh /lib/rdk/getDeviceDetails.sh refresh $1
    else
        NMdispatcherLog "DeviceDetails file not present"
    fi
}

check_valid_IPaddress()
{
    local mode=$1
    local addr=$2
    # Neglect IPV6 ULA address and autoconfigured IPV4 address
    if [ "x$mode" == "xipv6" ]; then
        if [[ $addr == fc* || $addr == fd* ]]; then
            return 1
        fi
    elif [ "x$mode" == "xipv4" ]; then
        autoIPTrunc=$(echo $addr | cut -d "." -f1-2)
        if [ "$autoIPTrunc" == "169.254" ]; then
            return 1
        fi
    fi
    return 0
}

update_global_ip_info_add()
{
    local cmd=$1
    local mode=$2
    local ifc=$3
    local addr=$4
    local flags=$5

    NMdispatcherLog "update_global_ip_info: cmd:$cmd, mode:$mode, ifc:$ifc, addr:$addr, flags:$flags"

    if [ "x$cmd" == "xadd" ] && [ "x$flags" == "xglobal" ]; then
        if ! check_valid_IPaddress "$mode" "$addr"; then
            return
        fi

        if [[ "$ifc" == "$ESTB_INTERFACE" || "$ifc" == "$DEFAULT_ESTB_INTERFACE" || "$ifc" == "$ESTB_INTERFACE:0" ]]; then
            NMdispatcherLog "Updating Box/ESTB IP"
            echo "$addr" > /tmp/.$mode$ESTB_INTERFACE
            refresh_devicedetails "estb_ip"
        elif [[ "$ifc" == "$MOCA_INTERFACE" || "$ifc" == "$MOCA_INTERFACE:0" ]]; then
            NMdispatcherLog "Updating MoCA IP"
            echo "$addr" > /tmp/.$mode$MOCA_INTERFACE
            refresh_devicedetails "moca_ip"
        elif [[ "$ifc" == "$WIFI_INTERFACE" || "$ifc" == "$WIFI_INTERFACE:0" ]]; then
            NMdispatcherLog "Updating Wi-Fi IP"
            echo "$addr" > /tmp/.$mode$WIFI_INTERFACE
            refresh_devicedetails "boxIP"
        fi
    fi
}

NMdispatcherLog "From NM_Dispatcher.sh $1 $2"

netInfoLog() {
    echo "`/bin/timestamp` :$0: $*" >> "$LOG_FILE"
    echo "`/bin/timestamp` :$0: $*" >> "$NM_LOG_FILE"
}

networkInfoLogger() {
    # Arguments: $1 event, $2 ipaddress type, $3 interface name, $4 ipaddress, $5 ipaddress scope
    local cmd="$1"
    local flags="$5"

    netInfoLog "Input Parameters : $*"
    if [ "x$cmd" = "xadd" ] && [ "x$flags" = "xglobal" ]; then
        netInfoLog "IP Informations `ifconfig`"
        wifiMac=$(grep 'wifi_mac=' /tmp/.deviceDetails.cache | sed -e "s/wifi_mac=//g")
        t2ValNotify "Xi_wifiMAC_split" "$wifiMac"
        netInfoLog "Route Informations `route -n`"
        netInfoLog "DNS Servers Informations"
        netInfoLog "DNS Masq File: /etc/resolv.dnsmasq `cat /etc/resolv.dnsmasq`"
        netInfoLog "DNS Resolve: /etc/resolv.conf `cat /etc/resolv.conf`"
    fi
}

checkDefaultRoute_Add() {
    #Condition to check for arguments are 7 and not 0.
    if [ $# -eq 0 ] || [ $# -ne 7 ];then
        echo "No. of arguments supplied are not satisfied, Exiting..!!!"
        echo "Arguments accepted are [ family | interface | destinationip | gatewayip | preferred_src | metric | add/delete]"
        return 1
    fi

    NMdispatcherLog "Input Arguments : $* "
    opern="$7"
    mode="$1"
    gtwip="$4"

    if [ "$opern" = "add" ]; then
        #Check and create the route flag
        route -n
        ip -6 route
        NMdispatcherLog "Route is available"
        if [ ! -f /tmp/route_available ];then
            NMdispatcherLog "Creating the Route Flag /tmp/route_available"
            touch /tmp/route_available
        fi

        #Add Default route IP to the /tmp/.GatewayIP_dfltroute file
        if ! grep -q "$gtwip" $FILE; then
            if [ "$mode" = "2" ]; then
                echo "IPV4 $gtwip" >> $FILE
            elif [ "$mode" = "10" ]; then
                echo "IPV6 $gtwip" >> $FILE
            else
                NMdispatcherLog "Invalid Mode"
                return 1
            fi
        fi
    else
        NMdispatcherLog "Received operation:$opern is Invalid..!!"
    fi
}

interfaceName=$1
interfaceStatus=$2

if [ "$interfaceStatus" = "connectivity-change" ] && [ -z "$interfaceName" ]; then
    NMdispatcherLog "Global connectivity-change - checking all interfaces"
    for iface in eth0 wlan0; do
        # Skip if interface doesn't exist
        if [ ! -e "/sys/class/net/$iface" ]; then
            continue
        fi
        # Check carrier state
        CARRIER=$(cat /sys/class/net/$iface/carrier 2>/dev/null || echo "0")
        if [ "$CARRIER" = "1" ]; then
                NMdispatcherLog "$iface - restarting avahi-autoipd"
                /usr/sbin/avahi-autoipd --kill "$iface" 2>/dev/null || true
                /usr/sbin/avahi-autoipd --daemonize --syslog "$iface"
        fi
    done
    exit 0
fi

if [ "$interfaceStatus" = "up" ]; then
   
    CON_STATE=$(nmcli -t -f GENERAL.STATE device show "$interfaceName" 2>/dev/null | cut -d: -f2)
    NMdispatcherLog "Connection state of interface $interfaceName=$CON_STATE"
fi

if [ "x$interfaceName" != "x" ] && [ "$interfaceName" != "lo" ]; then
    if [ "$interfaceStatus" == "dhcp4-change" ]; then
        /usr/sbin/avahi-autoipd --kill "$interfaceName" 2>/dev/null
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
        update_global_ip_info_add "add" "$mode" "$interfaceName" "$ipaddr" "global"
        NMdispatcherLog "update_global_ip_info completed"
        
        sh /lib/rdk/ipv6addressChange.sh "add" $mode $interfaceName $ipaddr "global"
        NMdispatcherLog "ipv6addressChange.sh"

        networkInfoLogger "add" $mode $interfaceName $ipaddr "global"
        NMdispatcherLog "networkInfoLogger"

        checkDefaultRoute_Add  $imode $interfaceName $ipaddr $gwip $interfaceName "metric" "add"
        NMdispatcherLog "checkDefaultRoute_Add"
    fi
    if [ "$interfaceName" == "wlan0" ]; then
        touch /tmp/wifi-on
    fi
    if [[ "$interfaceName" == "wlan0" || "$interfaceName" == "eth0" ]]; then
       if [ "$interfaceStatus" == "dhcp6-change" ] || [ "$interfaceStatus" == "dhcp4-change" ]; then 
           sh /lib/rdk/getRouterInfo.sh $interfaceName $interfaceStatus
           NMdispatcherLog "getRouterInfo.sh"
       fi
    fi
fi
