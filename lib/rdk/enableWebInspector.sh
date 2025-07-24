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

webLogging "Executing enableWebInspector.sh with arguments - $*"


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
    . /lib/rdk/getRFC.sh WEBKIT_INSPECTOR
fi

webLogging "RFC_ENABLE_WEBKIT_INSPECTOR is $RFC_ENABLE_WEBKIT_INSPECTOR and BUILD_TYPE is $BUILD_TYPE"
if [ "$RFC_ENABLE_WEBKIT_INSPECTOR" == "true" ] || [ "$BUILD_TYPE" != "prod" ]; then

    iface_type=0
    get_interface_type $iface
    iface_type=$?

    RWI_PORTS=(9224 10000 10001 10002 10003 10004)

    if [ 1 -le $iface_type ] && [ $iface_type -le 4 ] ;then
        webLogging "$iface is a valid interface !!"
        if [ "$ip_event" = "delete" ];then

            webLogging "ip_event : $ip_event"
            if [ -x $IPV4_BIN_PATH ]; then
                for port in ${RWI_PORTS[@]}; do
                  $IPV4_BIN -D INPUT -i $iface -p tcp --dport $port -j ACCEPT
                done
            else
                webLogging " $IPV4_BIN not found. Not applying ipv4 firewall rules"
            fi
            if [ -x $IPV6_BIN_PATH ]; then 
                #enable Web Inspector for WPE
                for port in ${RWI_PORTS[@]}; do
                  $IPV6_BIN -D INPUT -i $iface -p tcp --dport $port -j ACCEPT
                done
            else
                webLogging " $IPV6_BIN not found. Not applying ipv6 firewall rules"
            fi
        else
           [ -f $NET_SYS_PATH/$iface/operstate ] && iface_status=`cat $NET_SYS_PATH/$iface/operstate` || iface_status="down"
                webLogging "[$0]:Interface = $iface Status = $iface_status"
           if [ "$iface_status" = "up" ] && [ "$ip_event" = "add" ];then
                webLogging "ip_event : $ip_event"
		#Restart DHCPC if the global v6 Ip is not assigned to eth
                sleep 5
                globalIP=`ip addr show dev $iface | grep -i global | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d' | head -n`
                if [ ! -z "$globalIP" ]; then
                        UDHCPCPid=`ps -ef | grep udhcpc| grep $iface | grep -v grep | tr -s ' ' | cut -d ' ' -f2`
                        if [ ! -z "$UDHCPCPid" ]; then
                            kill -9 $UDHCPCPid
                        fi
                        /sbin/udhcpc -i $iface& 
                fi

                if [ -x $IPV4_BIN_PATH ]; then
                        #enable Web Inspector for WPE
                        for port in ${RWI_PORTS[@]}; do
                          $IPV4_BIN -I INPUT -i $iface -p tcp --dport $port -j ACCEPT
                        done
                else
                        webLogging " $IPV4_BIN not found. Not applying ipv4 firewall rules"
                fi
                if [ -x $IPV6_BIN_PATH ]; then 
                        #enable Web Inspector for WPE
                        for port in ${RWI_PORTS[@]}; do
                          $IPV6_BIN -I INPUT -i $iface -p tcp --dport $port -j ACCEPT
                        done
                else
                        webLogging " $IPV6_BIN not found. Not applying ipv6 firewall rules"
                fi
            fi
         fi
    fi
fi
