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

. /etc/env_setup.sh

. $RDK_PATH/soc_specific_fn.sh

# Initial sleep to get up the box
#sleep $UDHCPC_MONITOR_TIME

loop=0
while [ $loop -eq 0 ];
do
     if [ -f /tmp/estb_ipv6 ]; then
          echo "TLV_IP_MODE: IPv6 Mode..!"
          processName=dibbler-client
          loop=1
     elif [ -f /tmp/estb_ipv4 ]; then
          echo "TLV_IP_MODE: IPv4 Mode..!"
          processName=udhcpc
          loop=1
     else
          echo "Waiting for TLV flag (v4/v6)"
          sleep 1
     fi
done

echo -e "nameserver \t127.0.0.1" >> /tmp/resolv.conf
#echo -e "nameserver \t::1" >> /tmp/resolv.conf
# dnsmasq update
#echo -e "nameserver \t2001:558:feed::1" >> /tmp/resolv.dnsmasq
#echo -e "nameserver \t2001:558:feed::2" >> /tmp/resolv.dnsmasq

# Adding config for avoiding Voice Guidance issue
if [ -f /lib/rdk/disableIpv6Autoconf.sh ];then
     sh /lib/rdk/disableIpv6Autoconf.sh $MOCA_INTERFACE
fi

UDHCPMONLOG="$TEMP_LOG_PATH/udhcp_monitor.log"
#TLV_IP_MODE="Unspecified"
#restartUdhcp "$processName"

if [ ! -f /etc/os-release ];then
     if [ "$DEVICE_TYPE" = "hybrid" ];then
             sh /lib/rdk/ipv4-client-upgrade.sh &
     fi
fi

# Repeat the udhcp monitor
while true
do
    result=0
    result=`pidof "$processName"`
    if [ ! "$result" ] ; then
        /bin/timestamp >> $UDHCPMONLOG
        echo "`/bin/timestamp` udhcpc script is killed .. restarting in TLV_Mode : $TLV_IP_MODE" >> $UDHCPMONLOG
        restartUdhcp "$processName"
        sleep 2
    else
        sleep 10
    fi
done
