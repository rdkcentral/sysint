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
. /etc/config.properties
. /etc/env_setup.sh

check=0
loop=1
cnt=0
startmonitor=0
if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi
# Set the data dump properties
propertyFile="/etc/rmfconfig.ini"
if [ "$BUILD_TYPE" != "prod" ]; then
      if [ -f /opt/rmfconfig.ini ]; then
           propertyFile="/opt/rmfconfig.ini"
      fi
fi
                       
start_process=0
if [ -f $propertyFile ]; then
     flag=`grep "FEATURE.RESTART.RMFSTREAMER" $propertyFile |grep -v "^[#]"| cut -d "=" -f2`
     if [ "$flag" ] && [ "$flag" = "TRUE" ]; then
           start_process=1
     fi
fi

while [ $startmonitor -eq 0 ]
do
    id=`pidof rmfStreamer`
    if [ ! "$id" ]; then
        sleep 5
    else
        startmonitor=1
        echo "Started rmfstreamer, starting monitoring..!"
    fi
    if [ -f /tmp/.rmfstreamer_started ]; then
      sleep 20
      startmonitor=1
    fi
    if [ "$DEVICE_TYPE" = "mediaclient" ]; then
          if [ -f /tmp/no-sd-card ]; then exit 0; fi
    fi
done

while [ $loop -eq 1 ]
do
  retPid=`pidof rmfStreamer`
  if [ ! "$retPid" ]; then
      if [ "$DEVICE_TYPE" != "mediaclient" ] && [ $start_process -eq 0 ]; then 
          echo "rmfStreamer process is killed.."
          check=`expr $check + 1`
          if [ $check -gt 6 ]; then
	      if [ -f /opt/.reboot ]; then
	          r=`cat /opt/.reboot`
	      else
	          r=0
	      fi
              if [ ! $r ];then r=0; fi
	      r=`expr $r + 1`
	      if [ $r -le 10 ]; then
	          echo " rmfStreamer is not alive.. rebooting the box"
	          echo $r > /opt/.reboot
	          echo 0 > /opt/.rebootFlag
                  echo `/bin/timestamp`  ---------------- rebooting due to rmfStreamer-crash ------------------------------- >> $LOG_PATH/ocapri_log.txt
                  cp /opt/logs/receiver.log /opt/logs/receiver.log_rmfstreamer
                  cp /opt/logs/ocapri_log.txt /opt/logs/ocapri_log.txt_rmfstreamer
                  cp /opt/logs/messages.txt /opt/logs/messages.txt_rmfstreamer
                  cp /opt/logs/app_status.log /opt/logs/app_status_backup.log_rmfstreamer
                  # ------------------------------------------------------------------
                  # need 4 parameters in call to uploadDumps.sh to wait in case it's busy
                  # current uploadDumps.sh implementation will wait indefinitely for other instances
                  # to finish upload in case 4th parameter is "wait_for_lock"
                  sh $RDK_PATH/uploadDumps.sh `date +%Y-%m-%d-%H-%M-%S` 1 unused_parameter wait_for_lock
                  sleep 1
	          sync
                  /rebootNow.sh -s RmfStreamerRecovery -o "Rebooting the box due to rmfStreamer process crash..."
                  exit 0
	      else
	          echo  `/bin/timestamp` -----------Box has rebooted 10 times.. no more reboot ------------ >> $LOG_PATH/ocapri_log.txt
	          exit 1
	      fi
         fi
      else
          echo `/bin/timestamp` rmfStreamer crashed, restarting the process >> $LOG_PATH/rmfstr_log.txt
          t2CountNotify "SYST_ERR_Rmfstreamer_crash"
          export crashTS=`date +%Y-%m-%d-%H-%M-%S`
          if [ "$POTOMAC_SVR" != "" ] && [ "$BUILD_TYPE" != "dev" ]; then
               nice sh $RDK_PATH/uploadDumps.sh $crashTS 1 $POTOMAC_SVR &
          else
               nice sh $RDK_PATH/uploadDumps.sh $crashTS 1&
          fi
          /etc/init.d/rmf-streamer stop
          sleep 5
          /etc/init.d/rmf-streamer start
          exit 0
      fi
  fi
  sleep 15
  cnt=`expr $cnt + 1`
  if [ $cnt -eq 240 ]; then
    echo 0 > /opt/.reboot
  fi
done
