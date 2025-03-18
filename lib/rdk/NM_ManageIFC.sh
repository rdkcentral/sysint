#!/bin/bash
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

# List of interfaces to manage
MANAGED_INTERFACES=("eth0" "wlan0")

# Get all network interfaces
ALL_INTERFACES=$(ls /sys/class/net)

# Generate unmanaged devices list
UNMANAGED_DEVICES=""
for iface in $ALL_INTERFACES; do
    if [[ ! " ${MANAGED_INTERFACES[@]} " =~ " ${iface} " ]]; then
        UNMANAGED_DEVICES+="interface-name:${iface};"
    fi
done

# Add for p2p-dev* since they are not listed under $ALL_INTERFACES
UNMANAGED_DEVICES+="interface-name:p2p*"

# Update NetworkManager configuration
echo -e "[keyfile]\nunmanaged-devices=${UNMANAGED_DEVICES}" >> /etc/NetworkManager/conf.d/10-unmanaged-devices.conf
