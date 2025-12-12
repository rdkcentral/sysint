#!/bin/sh

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

NM_LOG_FILE="/opt/logs/NMMonitor.log"

NMdispatcherLog()
{
    echo "$(/bin/timestamp) : $0: $*" >> $NM_LOG_FILE
}

interfaceName=$1
interfaceStatus=$2

NMdispatcherLog "From NM_preUp.sh $interfaceName $interfaceStatus"

# Start avahi-autoipd when link is up and no global IPv4
start_zero_conf() {
    local ifname="$1"
    # Check if interface already has a global IPv4
    has_global_ipv4=$(/sbin/ip -4 addr show dev "$ifname" scope global | wc -l)
    if [ "$has_global_ipv4" -ne 0 ]; then
        NMdispatcherLog "Interface $ifname already has global IPv4, skipping avahi-autoipd start"
        return 0
    fi
    # Start the systemd service for this interface
    if systemctl is-active --quiet "avahi@${ifname}.service"; then
        NMdispatcherLog "avahi@${ifname}.service already active"
    else
        NMdispatcherLog "Starting avahi@${ifname}.service"
        systemctl start "avahi@${ifname}.service" || NMdispatcherLog "Failed to start avahi@${ifname}.service"
    fi
}

# On link up, start avahi-autoipd if no global IPv4 exists (helps IPv4LL assignment)
if [ "x$interfaceName" != "x" ] && [ "$interfaceName" != "lo" ]; then
    NMdispatcherLog "Calling start_zero_conf for $interfaceName"
    start_zero_conf "$interfaceName"
else
    NMdispatcherLog "Skipping: interfaceName='$interfaceName'"
fi

exit 0
