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

if [ -f "$TR181_BIN" ]; then
    serialNum=`tr181 Device.DeviceInfo.SerialNumber 2>&1 > /dev/null`
else #For Other device models
    serialNum=`cat /proc/cmdline | awk -F"[ ]" '{for(i=1;i<=NF;i++){print $(i)} }' | grep serial_number | cut -d "=" -f2`
fi

#check for empty value
if [ -z "$serialNum" ]; then
    serialNum="Not Available"
fi

echo $serialNum

