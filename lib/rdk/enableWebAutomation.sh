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
. /etc/rfc.properties
. /etc/include.properties
NET_SYS_PATH='/sys/class/net'

if [ -z $LOG_PATH ]; then
    LOG_PATH="/opt/logs"
fi

if [ -z $RDK_PATH ]; then
    RDK_PATH="/lib/rdk"
fi

if [ -z $RFC_PATH ]; then
    RFC_PATH="/opt/secure/RFC"
fi

webLogging ()
{
    echo "`/bin/timestamp` WEB_INSPECTOR : $1" >> $LOG_PATH/NMMonitor.log
}

webLogging "Executing enableWebAutomation.sh !!"


if [ ! -f /etc/os-release ]; then
     IPV6_BIN="/sbin/ip6tables -w "
     IPV4_BIN="/sbin/iptables -w "
     IPV6_BIN_PATH=/sbin/ip6tables
     IPV4_BIN_PATH=/sbin/iptables
else
     IPV6_BIN="/usr/sbin/ip6tables -w "
     IPV4_BIN="/usr/sbin/iptables -w "
     IPV6_BIN_PATH=/usr/sbin/ip6tables
     IPV4_BIN_PATH=/usr/sbin/iptables
fi
ip_event=$2
iface=$1

enable_interface()
{
    iface=$1
    iface_status="down"
    count=0
    max_retry=5
    timeout=3
    while [ true ]
    do
        if [ -f $NET_SYS_PATH/$iface/operstate ];then
            iface_status=`cat $NET_SYS_PATH/$iface/operstate`
        fi

        if [ "$iface_status" = "up" ] || [ $count -ge $max_retry ];then
            break
        fi
        /sbin/ip link set dev $iface up
        count=`expr $count + 1`
        sleep $timeout
    done
    echo "$iface_status"
}

get_interface_type()
{
    iface=$1
    iface_type=0
    if [ "$iface" = "$WIFI_INTERFACE" ];then
        iface_type=1 #WIFI Interface
    elif [ "$iface" = "$ETHERNET_INTERFACE" ];then
        iface_type=2 #Ethernet Interface
    elif [ "$iface" = "$MOCA_INTERFACE" ];then
        iface_type=3 #MOCA Interface
    elif [ -f $NET_SYS_PATH/$iface/device/modalias ];then
        iface_modalias=`cat $NET_SYS_PATH/$iface/device/modalias |  cut -d ':' -f1`
        if [ "$iface_modalias" = "usb" ];then
            iface_type=4 #USB to Ethernet Interface
        fi
    fi
    return $iface_type
}


#Get the value of RFC_ENABLE_WEBKIT_INSPECTOR
if [ -f  /lib/rdk/getRFC.sh ]; then
    . /lib/rdk/getRFC.sh WEBAUTOMATION
fi

webLogging "RFC_ENABLE_WEBAUTOMATION is $RFC_ENABLE_WEBAUTOMATION"
if [ "$RFC_ENABLE_WEBAUTOMATION" == "true" ]; then

    iface_type=0
    get_interface_type $iface
    iface_type=$?

    if [ 2 -le $iface_type ] && [ $iface_type -le 4 ] ;then
        webLogging "RFC_ENABLE_WEBAUTOMATION Valid Interface !!"
        if [ "$ip_event" = "delete" ];then

            webLogging "RFC_ENABLE_WEBAUTOMATION ip_event : delete!!"
            if [ -x $IPV4_BIN_PATH ]; then
                $IPV4_BIN -D INPUT -i $iface -p tcp --dport 9517 -j ACCEPT
            else
                webLogging " $IPV4_BIN not found. Not applying ipv4 firewall rules"
            fi
            if [ -x $IPV6_BIN_PATH ]; then
                #enable Web Automation for WPE
                $IPV6_BIN -D INPUT -i $iface -p tcp --dport 9517 -j ACCEPT
            else
                webLogging " $IPV6_BIN not found. Not applying ipv6 firewall rules"
            fi
        else
           iface_status=$(enable_interface $iface)
           webLogging "[$0]:Interface = $iface Status = $iface_status"
           if [ "$iface_status" = "up" ] && [ "$ip_event" = "add" ];then
                webLogging "RFC_ENABLE_WEBAUTOMATION add!!"
                sleep 5
                if [ -x $IPV4_BIN_PATH ]; then
                        #enable Web Automaion for WPE
                        $IPV4_BIN -I INPUT -i $iface -p tcp --dport 9517 -j ACCEPT
                else
                        webLogging " $IPV4_BIN not found. Not applying ipv4 firewall rules"
                fi
                if [ -x $IPV6_BIN_PATH ]; then
                        #enable Web Automation for WPE
                        $IPV6_BIN -I INPUT -i $iface -p tcp --dport 9517 -j ACCEPT
                else
                        webLogging " $IPV6_BIN not found. Not applying ipv6 firewall rules"
                fi
            fi
         fi
    fi
fi

