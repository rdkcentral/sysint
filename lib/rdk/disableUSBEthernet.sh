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


if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

VENDOR_ID=`udevadm info -q all /sys/class/net/wlan0 | grep ID_VENDOR_ID | cut -d " " -f2 | awk -F '=' '{print $2}'`
AUTHORIZED_USB1=`echo $AUTHORIZED_USB_DEVICES | awk -F ":" '{gsub(/"/, ""); print $1}'`
AUTHORIZED_USB2=`echo $AUTHORIZED_USB_DEVICES | awk -F ":" '{gsub(/"/, ""); print $2}'`
echo "Vendor ID of Wifi Driver: $VENDOR_ID"
echo "Authorized USB devices: $AUTHORIZED_USB_DEVICES"

if [ "$VENDOR_ID" != "$AUTHORIZED_USB1" ] || [ "$VENDOR_ID" != "$AUTHORIZED_USB2" ];then
    build=`echo $BUILD_TYPE | tr '[:upper:]' '[:lower:]'`
    if [ "$build" = "prod" ];then
        echo "TRUE"
    else
        echo "FALSE"
    fi
fi
