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
. $RDK_PATH/utils.sh
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
      . $RDK_PATH/snmpUtils.sh

      #ENV for the SNMP queries to the box
      setSNMPEnv
      max_count=120
      counter=0
      while [ $counter -lt 120 ]
      do
         snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
         #get current model using SNMP request
         current_model=`getModel`
         result=`echo $current_model | grep $MODEL_NUM`
         if [ $? -ne 0 ]; then
	     sleep 1
             counter=$(( $counter + 1 ))
         else
             counter=$max_count
         fi
      done
      #model using SNMP request
      echo $current_model
else
      getModel
fi

