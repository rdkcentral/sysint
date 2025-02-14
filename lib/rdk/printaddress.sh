#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
# file the following copyright and licenses apply:
#
# Copyright 2018 RDK Management
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
##########################################################################
## invocation format
## add ipv4 interfacename address global

. /etc/device.properties
cmd=$1
mode=$2
ifc=$3
addr=$4
flags=$5

filename="/tmp/addressaquired_ipv4"
if [ "x$mode" = "xipv6" ]; then
   filename="/tmp/addressaquired_ipv6"
fi
echo "Address Info from Kernel: $*"
if [ "x$cmd" = "xadd" ] && [ "x$flags" = "xglobal" ]; then
	if [ "x$ifc" = "x$DEFAULT_ESTB_INTERFACE" ] && [ "x$addr" != "x$DEFAULT_ESTB_IP" ] && [ "x$addr" != "x$DEFAULT_ECM_IP" ]; then
		touch $filename
        if [ -f /lib/rdk/getDeviceDetails.sh ]; then
            /bin/sh /lib/rdk/getDeviceDetails.sh refresh estb_ip &
        fi
	fi
fi
