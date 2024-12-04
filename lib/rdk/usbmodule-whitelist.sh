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
if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

if [ -f /etc/rfc.properties ];then
    . /etc/rfc.properties
fi

USB_STORAGE_TR181_NAME='Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.USB_AutoMount.Enable'

StatusUSBstorageModule=`tr181Set ${USB_STORAGE_TR181_NAME} 2>&1 > /dev/null`

echo "[$0] status of RFC $USB_STORAGE_TR181_NAME: $StatusUSBstorageModule"

echo "[$0]:[USB-HID] HID is enabled"
modprobe usbhid

if [ "$StatusUSBstorageModule" = "true" ]; then
    echo "[$0]:[USB-STORAGE] Enabling usb storage module based on USB_AutoMount RFC"
    modprobe usb-storage
else
    echo "[$0]:[USB-STORAGE] USB_AutoMount RFC is disabled, to work usb storage, make sure USB_AutoMount RFC is true."
fi
