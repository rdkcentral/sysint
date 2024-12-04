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

if [ -f  /lib/rdk/getRFC.sh ]; then
    . /lib/rdk/getRFC.sh SLAACSUPPORT
fi

if [ ! -d "/proc/sys/net/ipv6/conf/$interface" ]; then
    echo "Interface $interface not yet created. Hence exiting.."
    exit 0
fi

echo "RFC_ENABLE_SLAACSUPPORT:$RFC_ENABLE_SLAACSUPPORT"

RFC_ENABLE_SLAACSUPPORT_L=`echo $RFC_ENABLE_SLAACSUPPORT | tr '[:upper:]' '[:lower:]'`
if [ "x$RFC_ENABLE_SLAACSUPPORT_L" != "xfalse" ]; then
   echo "SLAAC support is enabled WITHOUT RFC Check"
   sysctl -w "net.ipv6.conf.$interface.accept_ra=1"

   forwardingenabled=`sysctl -n "net.ipv6.conf.$interface.forwarding"`
   if [ "$forwardingenabled" = "1" ]; then
     sysctl -w "net.ipv6.conf.$interface.accept_ra=2"
   fi

   sysctl -w "net.ipv6.conf.$interface.autoconf=1"
   sysctl -w "net.ipv6.conf.$interface.accept_ra_defrtr=1"
   sysctl -w "net.ipv6.conf.$interface.use_tempaddr=2"
   sysctl -w "net.ipv6.conf.$interface.disable_ipv6=1"
   sysctl -w "net.ipv6.conf.$interface.disable_ipv6=0"
else
   echo "SLAAC support is Disabled via RFC"
fi
