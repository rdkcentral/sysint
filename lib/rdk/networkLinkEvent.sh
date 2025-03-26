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


NETWORK_EVENT_LOGFILE="/opt/logs/NMMonitor.log"
networkEventLog() {
    echo "`/bin/timestamp` :$0: $*" >> $NETWORK_EVENT_LOGFILE
}
# Network Interface - $1
# Network Interface Status - $2 (add/delete/up/down)

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

if [ "$#" -eq 2 ];then
    interfaceName=$1
    interfaceStatus=$2

    networkEventLog "Arguments : Network InterfaceName:$1, Network InterfaceStatus:$2"

    # process only add/delete events
    if [ "$interfaceStatus" == "up" ] || [ "$interfaceStatus" == "down" ]; then
        exit
    fi

    if [ -f /lib/systemd/system/pni_controller.service ]; then
        . /etc/device.properties
        if [ "$interfaceName" == "$ETHERNET_INTERFACE" ]; then
            if systemctl is-active netsrvmgr.service > /dev/null || systemctl is-failed netsrvmgr.service > /dev/null; then
                networkEventLog "[networkLinkEvent.sh#$$]: $* - systemctl restart pni_controller.service &"
                systemctl restart pni_controller.service &
            fi
        fi
    fi

    #Skip event received before ipremote boot scan
    sh /lib/rdk/enable_ipremote.sh $interfaceName $interfaceStatus
    networkEventLog "enable_ipremote.sh"

    #WebInspector script
    sh /lib/rdk/enableWebInspector.sh $interfaceName $interfaceStatus
    networkEventLog "enableWebInspector.sh"

    #WebAutomation script
    sh /lib/rdk/enableWebAutomation.sh $interfaceName $interfaceStatus
    networkEventLog "enableWebAutomation.sh"

else
    networkEventLog "Failed due to invalid arguments ..."
    networkEventLog "Usage : $0 InterfaceName InterfaceStatus"
fi
