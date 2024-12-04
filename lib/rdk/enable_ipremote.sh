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

if [ -f /etc/rfc.properties ];then
    . /etc/rfc.properties
fi

NET_SYS_PATH='/sys/class/net'
IP_REMOTE_PORT='8091'
IP_REMOTE_INTERFACE_ENABLE_PREFIX='/tmp/ipremote_enabled'
IP_REMOTE_DHCP_PID_PREFIX='/tmp/ipremote_udhcpc_pid'
IP_REMOTE_TR181_NAME='Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.IPRemotePort.Enable'
IP_REMOTE_DISABLED_FLAG='/tmp/ipremote_boot_disabled'
IP_REMOTE_ENABLED_FLAG='/tmp/ipremote_boot_enabled'
IP_REMOTE_SUPPORT_TR181_NAME='Device.DeviceInfo.X_RDKCENTRAL-COM_IPRemoteSupport.Enable'
IP_REMOTE_SUPPORT_ENABLE_FLAG='/opt/.ipremote_status'
IP_REMOTE_SUPPORT_INTERFACE_FILE='/tmp/ipremote_interface_info'

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

disable_ipremote_port()
{
    iface=$1
    if [ -x $IPV4_BIN_PATH ]; then
        $IPV4_BIN -D INPUT -i $iface -p tcp --dport $IP_REMOTE_PORT  -j ACCEPT
    fi
}

enable_ipremote_port()
{
    iface=$1
    if [ -x $IPV4_BIN_PATH ]; then
        $IPV4_BIN -I INPUT -i $iface -p tcp --dport $IP_REMOTE_PORT  -j ACCEPT
    fi
}

disable_udhcpc_service()
{
    iface=$1
    pid_file=${IP_REMOTE_DHCP_PID_PREFIX}_${iface}
    if [ -f $pid_file ];then
        dhcp_pid=`cat $pid_file`
        if [ $dhcp_pid ]; then
            kill -9 $dhcp_pid
            rm -f $pid_file
            if [ -f $NET_SYS_PATH/$iface/operstate ];then
                /sbin/ip addr flush dev $iface
            fi
        fi
    fi
}

enable_udhcpc_service()
{
    iface=$1
    pid_file=${IP_REMOTE_DHCP_PID_PREFIX}_${iface}
    /sbin/udhcpc -i $iface  -p $pid_file &
}

disable_interface()
{
    iface=$1
    if [ "$BUILD_TYPE" = "prod" ] && [ "$DEVICE_TYPE" != "mediaclient" ];then
        ifconfig $iface down
        echo "[$0]:IP Remote disabled Ethernet interface - $iface on prod build"
    fi

}

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
# 1=WiFi Interface, 2=Ethernet Interface, 3=USB to Ethernet Interface
get_interface_type()
{
    iface=$1
    iface_type=0

    if [ "$iface" = "$WIFI_INTERFACE" ];then
        iface_type=1 #WIFI Interface
    elif [ "$iface" = "$ETHERNET_INTERFACE" ];then
        iface_type=2 #Ethernet Interface
    elif [ -f $NET_SYS_PATH/$iface/device/modalias ];then
        iface_modalias=`cat $NET_SYS_PATH/$iface/device/modalias |  cut -d ':' -f1`
        if [ "$iface_modalias" = "usb" ];then
            iface_type=3 #USB to Ethernet Interface
        fi
    fi
    return $iface_type
}

disable_ipremote_interface()
{
    iface=$1
    disable_ipremote_port $iface
    if [ "$iface" != "$WIFI_INTERFACE" ] && [ "$DEVICE_TYPE" != "mediaclient" ];then
        disable_udhcpc_service $iface
    fi
    rm -f ${IP_REMOTE_INTERFACE_ENABLE_PREFIX}_${iface}
    echo "[$0]:IP Remote is disabled on $iface interface"
}

enable_ipremote_interface()
{
    iface=$1
    iface_status="down"
    iface_type=0
    ipremote_enabled_iface=0 #WiFi = 1, Ethernet = 2

    get_interface_type $iface
    iface_type=$?
    if [ $iface_type -eq 1 ] && [ "$IPREMOTE_WIFI" = "true" ];then
        ipremote_enabled_iface=1 #WIFI Interface
    elif [ $iface_type -eq 2 ] && [ "$IPREMOTE_ETHERNET" = "true" ];then
        ipremote_enabled_iface=2 #Ethernet Interface
    fi

    if [ $ipremote_enabled_iface -ne 0 ];then
        iface_status=$(enable_interface $iface)
        echo "[$0]:Interface = $iface Status = $iface_status"
        if [ "$iface_status" = "up" ];then
            enable_ipremote_port $iface
            #Run udhcpc on Ethernet interface
            if [ $ipremote_enabled_iface -eq 2 ] && [ "$DEVICE_TYPE" != "mediaclient" ];then
                enable_udhcpc_service $iface
            fi
            touch ${IP_REMOTE_INTERFACE_ENABLE_PREFIX}_${iface}
            echo "[$0]:IP Remote is enabled on $iface interface"

            if [ ! -f $IP_REMOTE_SUPPORT_INTERFACE_FILE ];then
                touch $IP_REMOTE_SUPPORT_INTERFACE_FILE
            fi
        fi

    elif [ $iface_type -eq 2 ] || [ $iface_type -eq 3 ];then
        disable_interface $iface
    fi
}

get_ipremote_status()
{
    status=0
    tr181_status='false'
    tr181_ipremote_status='false'

    tr181_status=`tr181Set  ${IP_REMOTE_TR181_NAME}  2>&1 > /dev/null`
    if [ $? -ne 0 ];then
        if [ -f ${TR181_STORE_FILENAME} ]; then
            echo "[$0]:IP Remote - Get IP Remote enabled status directly from ${TR181_STORE_FILENAME} file"
            tr181_status=`grep ${IP_REMOTE_TR181_NAME}'=' ${TR181_STORE_FILENAME} | cut -d "=" -f2`
        else
            echo "[$0]:IP Remote Error - ${TR181_STORE_FILENAME} file not available"
            tr181_status='false'
        fi
    fi

    tr181_ipremote_status=`tr181Set  ${IP_REMOTE_SUPPORT_TR181_NAME}  2>&1 > /dev/null`
    if [ $? -ne 0 ];then
        if [ -f ${IP_REMOTE_SUPPORT_ENABLE_FLAG} ]; then
            echo "[$0]:IP Remote - Set IP Remote Support enabled status as true, ${IP_REMOTE_SUPPORT_ENABLE_FLAG} file found."
            tr181_ipremote_status='true'
        else
            echo "[$0]:IP Remote - Set IP Remote Support enabled status as false, ${IP_REMOTE_SUPPORT_ENABLE_FLAG} file not found."
            tr181_ipremote_status='false'
        fi
    fi

    tr181_status=`echo $tr181_status | tr '[:upper:]' '[:lower:]'`
    tr181_ipremote_status=`echo $tr181_ipremote_status | tr '[:upper:]' '[:lower:]'`
    echo "[$0]:IP Remote - RFC Enabled Status : $tr181_status, TR181 Enabled Status : $tr181_ipremote_status"

    if [ "x$tr181_status" = "xtrue" ] || [ "x$tr181_ipremote_status" = "xtrue" ]; then
        status=1
    fi
    return $status
}

###### Main App ######
#$1 Interface Name
#$2 Interface Status
if [ "$#" -eq 2 ];then
    ip_iface=$1
    ip_event=$2
    ipremote_enabled=0
    ip_iface_type=0

    get_ipremote_status
    ipremote_enabled=$?
    #Boot scan
    if [ ! -f ${IP_REMOTE_DISABLED_FLAG} ] && [ ! -f ${IP_REMOTE_ENABLED_FLAG} ] ;then
        if [ $ipremote_enabled -eq 1 ];then
            touch ${IP_REMOTE_ENABLED_FLAG}
            echo "[$0]:IP Remote feature is enabled on boot"
        else
            touch ${IP_REMOTE_DISABLED_FLAG}
            echo "[$0]:IP Remote feature is disabled on boot"
        fi
    fi

    #Disable Ethernet interface on prod build if the ip remote feature is disabled on bootup for hybrid devices
    if [ -f ${IP_REMOTE_DISABLED_FLAG} ] && [ "$ip_event" = "add" ];then
        get_interface_type $ip_iface
        ip_iface_type=$?
        if [ $ip_iface_type -eq 2 ] || [ $ip_iface_type -eq 3 ];then
            disable_interface $ip_iface
        fi
    elif  [ -f ${IP_REMOTE_ENABLED_FLAG} ] && [ $ipremote_enabled -eq 1 ];then
        if [ "$ip_event" = "add" ] && [ ! -f ${IP_REMOTE_INTERFACE_ENABLE_PREFIX}_${ip_iface} ];then
             echo "[$0]:IP Remote detected new interface - $ip_iface"
             enable_ipremote_interface $ip_iface
        fi
    elif [ $ipremote_enabled -ne 1 ];then
        echo "[$0]:IP Remote feature is disabled"
    fi
    # Disable interface when ip remote feature is disabled dynamically via tr181/webpa
    if [ "$ip_event" = "delete" ] && [ -f ${IP_REMOTE_INTERFACE_ENABLE_PREFIX}_${ip_iface} ];then
        echo "[$0]:IP Remote removed interface - $ip_iface"
        disable_ipremote_interface $ip_iface
        # simply remove the ipremote interface file
        rm -f $IP_REMOTE_SUPPORT_INTERFACE_FILE 
    fi
else
    echo "Failed due to invalid arguments ..."
    echo "Usage(enable specified interface) : $0 InterfaceName InterfaceStatus(add/delete)"
    echo "             (OR)              "
    echo "Usage(scan and enable all interface) : $0 all add"
fi
