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


(/bin/busybox kill -STOP $$; /bin/busybox kill -CONT $$)
# Include File check
if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

LOG_INPUT=ipSetupLogs.txt
if [ ! "$LOG_PATH" ];then LOG_PATH=/opt/logs/; fi
LOG_FILE=$LOG_PATH/$LOG_INPUT

# Input Arguments - $1 event - $2 ipaddress type - $3 interface name - $4 ipaddress - $5 ipaddress scope  
cmd=$1
flags=$5
printf "`/bin/timestamp` $0: Input Parameters : $* \n" >> $LOG_FILE
if [ "x$cmd" == "xadd" ] && [ "x$flags" == "xglobal" ]; then
    # Debug Logs regarding the Network Informations
    printf "`/bin/timestamp` $0: IP Informations\n `ifconfig` \n" >> $LOG_FILE
    wifiMac=`grep 'wifi_mac=' /tmp/.deviceDetails.cache | sed -e "s/wifi_mac=//g"`
    t2ValNotify "Xi_wifiMAC_split" "$wifiMac"
    printf "`/bin/timestamp` $0: Route Informations\n `route -n` \n" >> $LOG_FILE
    printf "`/bin/timestamp` $0: DNS Servers Informations" >> $LOG_FILE
    printf "`/bin/timestamp` $0: DNS Masq File: /etc/resolv.dnsmasq\n `cat /etc/resolv.dnsmasq`\n" >> $LOG_FILE
    printf "`/bin/timestamp` $0: DNS Resolve: /etc/resolv.conf\n `cat /etc/resolv.conf`\n" >> $LOG_FILE
fi
exit 0
