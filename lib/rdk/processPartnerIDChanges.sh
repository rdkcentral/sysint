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

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
export PATH=$PATH:/usr/local/bin
if [ ! -f /etc/os-release ]; then
	IARM_EVENT_BINARY_LOCATION=/usr/local/bin
else
	IARM_EVENT_BINARY_LOCATION=/usr/bin
fi

eventManager()
{
   if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ]; then
          $IARM_EVENT_BINARY_LOCATION/IARM_event_sender PartnerIdEvent 0
   else
          echo "Missing the binary $IARM_EVENT_BINARY_LOCATION/IARM_event_sender"
   fi
}

if [ $# -ne 1 ]
then
  echo "Usage: processPartnerIDChanges.sh <partner_id>"
  exit 1
fi

if [ "$WHOAMI_SUPPORT" == "true" ]; then
    echo "WHOAMI_SUPPORT is enabled"
else
    echo "WHOAMI_SUPPORT is disabled"
fi

if [ "$DEVICE_TYPE" = "mediaclient" ];then
    if [ "$WHOAMI_SUPPORT" = "true" ];then
        eventManager
    fi
    if [ -f "$RDK_PATH/clearACSConf.sh" ];then
        sh $RDK_PATH/clearACSConf.sh $1
    else
        echo "$RDK_PATH/clearACSConf.sh file not found."
    fi
else
	eventManager
fi

# Check and restart SDV Agent
if [ -f "$RDK_PATH/runSdvAgent.sh" ];then
    pidof "sdvAgent"
    if [ $? -eq 0 ]; then
         if [ ! -f /etc/os-release ]; then
              /etc/init.d/sdv-service stop
         else
              killall "sdvAgent"
         fi
    fi
    echo "ParnerID changed..! Restarting SDV Agent..!"
    if [ ! -f /etc/os-release ]; then
          /etc/init.d/sdv-service restart
    else
          sh $RDK_PATH/runSdvAgent.sh &
    fi
else
    echo "$RDK_PATH/runSdvAgent.sh file not found."
fi

if [ "$WHOAMI_SUPPORT" != "true" ]; then
    echo "Initiating reprovisioning on partnerId change"
    THUNDER_SEC_ENABLED=$(curl -s http://127.0.0.1:9998/Service/Controller/Configuration/Controller | grep Security | wc -l)
    if [ "$THUNDER_SEC_ENABLED" = "1" ]; then
      export TOKEN;
      TOKEN=$(/usr/bin/WPEFrameworkSecurityUtility | grep token | cut -f4 -d "\"")
      curl -H "Content-Type: application/json"  -H "Authorization: Bearer $TOKEN" -X POST -d '{"jsonrpc":"2.0","id":"3","method": "com.comcast.DeviceProvisioning.1.reprovision", "params": {"provisionType": "HARDWARE", "fetchCredentials":true}}' http://127.0.0.1:9998/jsonrpc > /dev/null 2>&1 &
    else
      curl -H "Content-Type: application/json" -X POST -d '{"jsonrpc":"2.0","id":"3","method": "com.comcast.DeviceProvisioning.1.reprovision", "params": {"provisionType": "HARDWARE", "fetchCredentials":true}}' http://127.0.0.1:9998/jsonrpc > /dev/null 2>&1 &
    fi
fi
