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

TR181_BIN="/usr/bin/tr181"
TR181_DISABLEMOCA_NAME="Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DisableMoca.Enable"
MOCA_BIN="/usr/bin/rmh"
echo "triggered stopMoca.sh"
disableMoca="false"
if [ -f "$TR181_BIN" ]; then
        disableMoca=`$TR181_BIN -g $TR181_DISABLEMOCA_NAME  2>&1 > /dev/null`
fi

if [ "$disableMoca" != "true" ] ; then
        $MOCA_BIN stop
fi

/sbin/ip addr flush dev ${MOCA_INTERFACE}:0
/sbin/ip link set dev ${MOCA_INTERFACE}:0 down
/lib/rdk/zcip.script deconfig
exit 0
