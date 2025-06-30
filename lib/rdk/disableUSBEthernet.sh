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

# Function to check if current device matches any authorized USB device
check_authorized_device() {
    current_vendor="$1"
    current_model="$2"
    authorized_devices="$3"
    
    # Split authorized devices by space and check each pair
    for driver_id_pair in $authorized_devices; do
        # Extract vendor and model from each pair
        vendor_id=$(echo "$driver_id_pair" | awk -F ":" '{gsub(/"/, ""); print $1}')
        model_id=$(echo "$driver_id_pair" | awk -F ":" '{gsub(/"/, ""); print $2}')
        
        # Check if current device matches this authorized pair
        if [ "$current_vendor" = "$vendor_id" ] && [ "$current_model" = "$model_id" ]; then
            return 0
        fi
    done
    return 1
}

if [ ! -z "$ID_VENDOR_ID" ] && [ ! -z "$ID_MODEL_ID" ]; then
    # Check if current device is in the authorized list
    if check_authorized_device "$ID_VENDOR_ID" "$ID_MODEL_ID" "$AUTHORIZED_USB_DEVICES"; then
        echo "FALSE"  # Device is authorized
    else
        build=$(echo $BUILD_TYPE | tr '[:upper:]' '[:lower:]')
        if [ "$build" = "prod" ]; then
            echo "TRUE"   # Device is unauthorized
        else
            echo "FALSE"  # Device is authorized for Dev builds.
        fi
    fi
else
    echo "TRUE"  # Block if wifi driver is missing vendor/model IDs information
fi
