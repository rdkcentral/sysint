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

IBUS_MNGR_PATH="/mnt/nfs/env"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib:/usr/lib:/usr/local/lib:/mnt/nfs/lib

if [ -f /opt/debug.ini ] && [ "$BUILD_TYPE" != "prod" ]; then                      
    debugConfigFile="/opt/debug.ini"                
else                                                
    debugConfigFile="/etc/debug.ini"
fi 
        
wait_for_ibus_start()
{
   startmonitor=0
   while [ $startmonitor -eq 0 ]
   do
      if [ -f "$1" ]; then
           startmonitor=1
      else
           echo "IARM managers are not called yet..!"
           sleep 1
      fi
   done
}

wait_for_ibus_complete()
{
   startmonitor=0
   while [ $startmonitor -eq 0 ]
   do
      if [ -f "$1" ]; then
            startmonitor=1
      else
            echo "IARM managers are not started yet..!"
            sleep 1
      fi
   done
}

start_ibus_manager()
{
  currDir=`pwd`
  cd $IBUS_MNGR_PATH
  if [ -f ./$1 ]; then
      echo "`/bin/timestamp` Restarting the process $1 ..!"
      ./$1 --debugconfig $debugConfigFile &
      sleep 1
  fi
  cd $currDir
}
            
rebootFunction()
{
  echo "`/bin/timestamp` $1 process crashed..Rebooting the box..!" >> /opt/logs/uimgr_log.txt
  echo "`/bin/timestamp` $1 process crashed..Rebooting the box..!" >> /opt/logs/rf4ce_log.txt
  sleep 2
  if [ -f /lib/rdk/debug_info.sh ]; then
       sh /lib/rdk/debug_info.sh >> /opt/logs/top_log.txt
  fi
  if [ $1 == "IARMDaemonMain" ]; then
      crash_pid=$iarmpid
  else
	  crash_pid=$dsmgrpid
  fi
  cat /proc/$crash_pid/cmdline >> /opt/logs/top_log.txt 2>&1
  cat /proc/$crash_pid/status >> /opt/logs/top_log.txt 2>&1

  if [ -f /rebootNow.sh ]; then 
       sh /rebootNow.sh -s IarmMgrRecovery -o "Rebooting the box due to $1 process crash..." &
  fi
}

# wait for IBUS manager scripts start
wait_for_ibus_start "$RAMDISK_PATH/.IarmBusMngrStart"
sleep 5

# wait for IBUS manager scripts end
wait_for_ibus_complete "$RAMDISK_PATH/.IarmBusMngrFlag"

sleep 30
iarmpid=`pidof "IARMDaemonMain"`
dsmgrpid=`pidof "dsMgrMain"`
loop=1
while [ $loop -eq 1 ]
do
   status=`pidof "IARMDaemonMain"`
   if [ ! "$status" ]; then rebootFunction "IARMDaemonMain"; fi
   status=`pidof "dsMgrMain"`
   if [ ! "$status" ]; then rebootFunction "dsMgrMain"; fi
   status=`pidof "irMgrMain"`
   if [ ! "$status" ]; then start_ibus_manager "irMgrMain"; fi
   status=`pidof "pwrMgrMain"`
   if [ ! "$status" ]; then start_ibus_manager "pwrMgrMain"; fi
   status=`pidof "storageMgrMain"`
   if [ ! "$status" ]; then 
        currDir=`pwd`
        cd /usr/bin
        if [ -f ./storageMgrMain ]; then
              echo "`/bin/timestamp` Restarting the process $1 ..!"
              if [ -f $PERSISTENT_PATH/storageMgr.conf ] && [ "$BUILD_TYPE" != "prod" ]; then
                  export stmMgrConfigFile=$PERSISTENT_PATH/storageMgr.conf
              else
             	  export stmMgrConfigFile=/etc/storageMgr.conf
              fi
              ./storageMgrMain --debugconfig $debugConfigFile --configFilePath $stmMgrConfigFile &
              sleep 1
        fi
        cd $currDir
   fi
   if [[ "$RF4CE_CAPABLE" = "true" ]]; then
      status=`pidof "vrexMgrMain"`
      if [ ! "$status" ]; then start_ibus_manager "vrexMgrMain"; fi
      status=`pidof "deviceUpdateMgrMain"`
      if [ ! "$status" ]; then start_ibus_manager "deviceUpdateMgrMain"; fi
   fi
   status=`pidof "sysMgrMain"`
   if [ ! "$status" ]; then start_ibus_manager "sysMgrMain"; fi
   status=`pidof "mfrMgrMain"`
   if [ ! "$status" ]; then start_ibus_manager "mfrMgrMain"; fi
   sleep 30
done

