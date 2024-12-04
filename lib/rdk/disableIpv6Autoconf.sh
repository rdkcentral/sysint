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

interface=$1

if [ "$DEVICE_NAME" = "LLAMA" ];then
    if [ "$1" == "$ETHERNET_INTERFACE" ] || [ "$1" == "$WIFI_INTERFACE" ];then
        if [ -f /proc/sys/net/ipv6/conf/$interface/disable_ipv6 ];then
            sysctl -w "net.ipv6.conf.$interface.disable_ipv6=1"
        fi
    fi
else
    if [ $LAN_INTERFACE ] && [ "$DEVICE_TYPE" = "mediaclient" ];then
        if [ -f /proc/sys/net/ipv6/conf/$LAN_INTERFACE/disable_ipv6 ];then
            echo 1 > /proc/sys/net/ipv6/conf/$LAN_INTERFACE/disable_ipv6
        fi
    fi
fi

if [ "$1" ];then
     # Adding config for avoiding Voice Guidance issue
     if [ -f /proc/sys/net/ipv6/conf/$interface/accept_ra ];then
           sysctl -w "net.ipv6.conf.$interface.accept_ra=0"
     fi
     if [ -f /proc/sys/net/ipv6/conf/$interface/autoconf ];then
           sysctl -w "net.ipv6.conf.$interface.autoconf=0"
     fi
     if [ -f /proc/sys/net/ipv6/conf/$interface/use_tempaddr ];then
           sysctl -w "net.ipv6.conf.$interface.use_tempaddr=0"
     fi
     if [ -f /proc/sys/net/ipv6/conf/$interface/accept_ra_defrtr ];then
          sysctl -w "net.ipv6.conf.$interface.accept_ra_defrtr=0"
     fi

else
     echo "Usage: $0 <interface>"
     echo "Please call the script with an interface..!"
fi
