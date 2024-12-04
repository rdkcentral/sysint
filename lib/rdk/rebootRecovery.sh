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
. /etc/env_setup.sh
. /lib/rdk/commonUtils.sh

process=$1
LOG_FILE=$2

if [ -f $RAMDISK_PATH/.recovery_inprogress ]; then
      exit 0
fi

cleanup()
{
    # cleanup lock file
    if [ -f $RAMDISK_PATH/.recovery_inprogress ]; then                     
          rm -rf $RAMDISK_PATH/.recovery_inprogress                        
    fi 
}

reboot_Recovery()
{
    # backup before reboot
    echo 0 > $PERSISTENT_PATH/.rebootFlag
    echo `/bin/timestamp`  ----- rebooting due to $process crash -------- >> $LOG_FILE
    if [ "$HDD_ENABLED" = "false" ]; then
             if [ `haveCoreToUpload` == 'true' ] ; then
                    # max wait time is 5 minutes
                    waitForDumpCompletion 300
                    TS=`date +%Y-%m-%d-%H-%M-%S`
                    sh $RDK_PATH/uploadDumps.sh $TS 1
             fi
    else
          cp $LOG_PATH/receiver.log $LOG_PATH/receiver.log_$process
          cp $LOG_PATH/messages.txt $LOG_PATH/messages.txt_$process
          cp $LOG_PATH/app_status.log $LOG_PATH/app_status_backup.log_$process
          cp $LOG_FILE $LOG_FILE_$process
    fi
    cleanup
    sleep 1
    sync
    /rebootNow.sh -s RunPodRecovery -o "Rebooting the box due to runPod process crash..."
    exit 0
}

touch $RAMDISK_PATH/.recovery_inprogress 
check=0
loop=1
while [ $loop -eq 1 ]
do
  processLive=`pidof $process`
  if [ ! "$processLive" ]; then
          echo "`/bin/timestamp` $process process is killed.." >> $LOG_FILE
          check=`expr $check + 1`
          if [ $check -gt 6 ]; then
	      if [ -f $PERSISTENT_PATH/.reboot ]; then
	          r=`cat $PERSISTENT_PATH/.reboot`
	      else
	          r=0
	      fi
              if [ ! $r ];then r=0; fi

	      r=`expr $r + 1`
	      if [ $r -le 10 ]; then
	          echo "`/bin/timestamp` $process is not alive.. rebooting the box" >> $LOG_FILE
	          echo $r > $PERSISTENT_PATH/.reboot
                  reboot_Recovery
      	      else
	          echo `/bin/timestamp` -----------Box has rebooted 10 times.. no more reboot ------------ >> $LOG_FILE
                  cleanup
	          exit 1
	      fi
         fi
  else
       loop=0
       echo "0" > $PERSISTENT_PATH/.reboot
       cleanup
  fi
  sleep 5
done
