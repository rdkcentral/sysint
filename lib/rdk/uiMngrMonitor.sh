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

. $RDK_PATH/commonUtils.sh
. $RDK_PATH/interfaceCalls.sh

if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

if [ ! -f $RAMDISK_PATH/.uiMngrFlag ] || [ -f /tmp/.standby ]; then
     exit 0
fi
 
# Check the UIMNGR process
output=`processCheck uimgr_main`
if [ "$output" == "1" ]; then     
     echo "UIMngr process is killed.." 
     if [ "$HDD_ENABLED" = "false" ]; then
          if [[ -f $CORE_PATH/*core.prog_uimgr_main.signal_* ]] ; then
              waitForDumpCompletion 300
              TS=`date +%Y-%m-%d-%H-%M-%S`
              sh $RDK_PATH/uploadDumps.sh $TS 1
          fi
     fi
     echo "`/bin/timestamp` Rebooting due to UI Mngr crash" >> /opt/logs/uimgr_log.txt
     /rebootNow.sh -s UIMngrRecovery -o "Rebooting the box due to UI_Mngr process crash..."
     exit 1
fi

exit 0

