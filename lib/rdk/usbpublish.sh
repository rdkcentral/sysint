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

. /etc/include.properties
. /etc/device.properties

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
else
    IARM_EVENT_BINARY_LOCATION=/usr/bin
fi


vendorid="unknown"
productid="unknown"
devpath="unknown"

if [ "x${ID_VENDOR_ID}" != "x" ]; then
    vendorid=${ID_VENDOR_ID}
fi

if [ "x${PRODUCT}" != "x" ]; then
    productid=${PRODUCT}
fi

if [ "x${DEVPATH}" != "x" ]; then
    devpath=${DEVPATH}
fi


#Set logs folder
if [ -z $LOG_PATH ]; then
    LOG_PATH="/opt/logs/"
fi

USB_LOGFILE=$LOG_PATH/usbpublish.log


usbpublishlog()
{
    echo "`/bin/timestamp` : $0: $*"  >> $USB_LOGFILE
}


#retrieves the current firmware info of peripheral devices

#sends notification to Control Manager with downloaded firmwares and their location 
sendNotification()
{
    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ]; then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender usbdetected $1 $vendorid $productid $devpath >> $USB_LOGFILE 2>&1
    else
        usbpublishlog "Missing the binary $IARM_EVENT_BINARY_LOCATION/IARM_event_sender"
    fi
}

usbpublishlog "PARAMETERS = $*"
usbpublishlog "ENVIRONMENT: Vendorid = $vendorid ; ProductId = $productid ; USBDEVPATH= $devpath"
sendNotification $1
