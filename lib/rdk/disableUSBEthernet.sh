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

#Note: Vendor supporting wifi Driver with USB bus must provide the information of both Model_ID and Vendor_ID

if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

AUTHORIZED_USB1=`echo $AUTHORIZED_USB_DEVICES | awk -F ":" '{gsub(/"/, ""); print $1}'`
AUTHORIZED_USB2=`echo $AUTHORIZED_USB_DEVICES | awk -F ":" '{gsub(/"/, ""); print $2}'`

if [ ! -z "$ID_VENDOR_ID" ] && [ ! -z "$ID_MODEL_ID" ] ;then
    if [ "$ID_VENDOR_ID" == "$AUTHORIZED_USB1" ] && [ "$ID_MODEL_ID" == "$AUTHORIZED_USB2" ];then
        echo "FALSE"
    else
        build=`echo $BUILD_TYPE | tr '[:upper:]' '[:lower:]'`
        if [ "$build" = "prod" ];then
            echo "TRUE"
        else
            echo "FALSE"
        fi
    fi
else
    echo "TRUE"
fi
