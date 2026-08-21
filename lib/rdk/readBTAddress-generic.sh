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
# Purpose: This script is used to fetch device Bluetooth Mac information
# Scope: RDK devices.
# Usage: This script is triggered by a systemd service and shell scripts.

. /etc/include.properties
. /etc/device.properties
. $RDK_PATH/utils.sh

if [ "$BLUETOOTH_ENABLED" = "true" ]; then
    bluetooth_mac=$(getDeviceBluetoothMac)
fi
echo $bluetooth_mac
