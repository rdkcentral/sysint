#! /bin/sh
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

set -x
. /etc/include.properties
. $RDK_PATH/utils.sh
. /etc/device.properties
. /etc/env_setup.sh
logsFile=$LOG_PATH/ipSetupLogs.txt
wifi_interface=`getWiFiInterface`
interface=`getMoCAInterface`
ret=`checkWiFiModule`
if [ $ret == 1 ]; then
        echo "`/bin/timestamp` WIFI is enabled" >> $logsFile
        interface=$wifi_interface
fi
    
START=1
while [ $START -lt 420 ]; do
    gatewayIP=`route -n | grep 'UG[ \t]' | grep $interface | awk '{print $2}' | grep 169.254`
    gatewayIP=`echo $gatewayIP | head -n1 | awk '{print $1;}'`
    if [ "$gatewayIP" != "" ]; then
        echo "`/bin/timestamp` got the route exiting the rstXdiscovery   "  >> $logsFile
        exit 0
    fi
    gatewayIPv6=`ip -6 route | grep $interface | awk '/default/ { print $3 }'`
    if [ "$gatewayIPv6" != "" ]; then
        echo "`/bin/timestamp` got the ipv6 route exiting the rstXdiscovery   "  >> $logsFile
        exit 0
    fi
    sleep 10
    START=$((START + 10)) 
    echo "`/bin/timestamp`  checking for the route waited for  $START seconds  "  >> $logsFile
done
    touch /tmp/rstXdiscovery
    echo "`/bin/timestamp`  Killing the xdiscovery  "  >> $logsFile
    killall xdiscovery

