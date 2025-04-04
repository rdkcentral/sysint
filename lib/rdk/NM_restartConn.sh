#!/bin/bash

####################################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2024 Comcast Cable Communications Management, LLC
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
####################################################################################

# Get all connection names associated with the device
CONNECTIONS=$(nmcli connection show | grep wifi | cut -d ' ' -f1)
echo "From NM_restart_Conn.sh List of connections: " >> /opt/logs/NMMonitor.log
echo "$CONNECTIONS" >> /opt/logs/NMMonitor.log

# Bring up each connection
for CONNECTION in $CONNECTIONS; do
    is_autoConnect=$(nmcli conn show $CONNECTION |  grep -i "autoconnect:" | grep 'yes')
    echo "From NM_restart_Conn.sh Connection: $CONNECTION" >> /opt/logs/NMMonitor.log

    if [ -z $is_autoConnect ]; then
        echo "From NM_restart_Conn.sh $CONNECTION is not AutoConnect" >> /opt/logs/NMMonitor.log
        nmcli conn up $CONNECTION
    fi
done
