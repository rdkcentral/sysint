#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
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
##########################################################################
NONROOTUSER_TR181_NAME='Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.NonRootSupport.Enable'

source /etc/device.properties
# NonRootSupport RFC is not supported for in this device
if [ $MODEL_NUM == "pi" ]; then
        exit 0
fi
StatusNONROOTUSER=`tr181Set ${NONROOTUSER_TR181_NAME} 2>&1 > /dev/null`

echo "[$0] status of RFC $NONROOTUSER_TR181_NAME: $StatusNONROOTUSER"

if [ "$StatusNONROOTUSER" = "true" ]; then
    echo "[$0]:[NONROOTUSER] Enabled"
    touch /tmp/.EnableNonRootUser
elif [ -z "$StatusNONROOTUSER" ]; then
    echo "[$0]:[NONROOTUSER] Enabled, while RFC setting as empty"
    touch /tmp/.EnableNonRootUser
else
    echo "[$0]:[NONROOTUSER] Disabled"
    if [ -f /tmp/.EnableNonRootUser ]; then
        rm /tmp/.EnableNonRootUser
    fi
fi
