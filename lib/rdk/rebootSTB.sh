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

Timestamp()
{
    /bin/timestamp
}

REBOOTLOG="$LOG_PATH/reboot.log"
## Sleep for 30 minutes, to make sure all the times are correct on the STB
echo `Timestamp` 'Initial sleep for 30 minutes, for time to be set correctly on STB'>>$REBOOTLOG;
sleep 1800

#check if AutoReboot Maintenance Window is Enabled
if [ "$DEVICE_TYPE" = "hybrid" ] || [ "$DEVICE_TYPE" = "mediaclient" ]; then
    AutoReboot=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.AutoReboot.Enable 2>&1 > /dev/null)
    if [ "$AutoReboot" = "true" ]; then
        echo `Timestamp` 'Aborting the rebootSTB Operation as AutoReboot.Enable is True'>>$REBOOTLOG;
        exit
    fi
fi

if [ "$DEVICE_TYPE" = "mediaclient" ] && [ -f $RDK_PATH/networkCommnCheck.sh ]; then
     echo "Verifying the network and the gateway for Communication"
     sh $RDK_PATH/networkCommnCheck.sh
     sleep 1
fi
#Default param values
rebootWindowMins=30
timeToReboot="07:30"  #Time in UTC
rebootInt=144

if [ -f $PERSISTENT_PATH/.autoRebootParams.sh ] && [ "$BUILD_TYPE" != "prod" ] ; then
    chmod 777 $PERSISTENT_PATH/.autoRebootParams.sh
    . $PERSISTENT_PATH/.autoRebootParams.sh

    ## Random time between RebootWStartTime and RebootWindow in mins
    if [ $RebootWStartTimeUTC -ge 0 ] ; then
        if [ $RebootWindowHours -gt 0 ] ; then
            rebootWindowMins=`expr $RebootWindowHours \* 60`
        fi
        timeToReboot=`echo $RebootWStartTimeUTC":00"`
    fi  
    if [ $RebootIntervalHours -ge 0 ] ; then
        rebootInt=$RebootIntervalHours
    fi
fi
  
echo `Timestamp` 'rebootWindowMins' $rebootWindowMins ' timeToReboot' $timeToReboot ' rebootInt' $rebootInt 'hours'>>$REBOOTLOG;
rTime=`expr $RANDOM % $rebootWindowMins`
echo `Timestamp` 'Sleeping for an additional ' $rTime ' minutes'>>$REBOOTLOG;

## Minimum time to reboot in minutes
minTime=60

## Calculating time to reboot in seconds
start_time=`date +%H:%M:%S`
rebootIntSecs=`expr $rebootInt \* 3600`
start_hour=`echo $start_time | cut -d':' -f1`
start_min=`echo $start_time | cut -d':' -f2`
end_hour=`echo $timeToReboot | cut -d':' -f1`
end_min=`echo $timeToReboot | cut -d':' -f2`
hour=`expr $end_hour - $start_hour`
min=`expr $end_min - $start_min`

if [ $min -lt 0 ]
then
    min=`expr $min + 60`
    hour=`expr $hour - 1`
fi

if [ $hour -lt 0 ]
then
    hour=`expr $hour + 24`
fi

hour_min=`expr $hour \* 60`

## Modified to include random time
tot_min=`expr $hour_min + $min + $rTime`
                                   
## Sleep for remaining time or next day the same time
if [ $tot_min -lt $minTime ]                 
then                                         
     tot_min=`expr $tot_min + 1440`             
     seconds=`expr $tot_min \* 60`              
else                                         
     seconds=`expr $tot_min \* 60`              
fi    

## Calculate additional time based on rebootInterval
echo 'rebootIntSecs' $rebootIntSecs ' seconds' $seconds>>$REBOOTLOG;
while [ $rebootIntSecs -ge $seconds ] 
do 
    seconds=`expr $seconds + 86400` 
done                              
                                                     
## Sleep for the time in seconds                     
echo `Timestamp` 'The box will reboot in ' $seconds ' seconds'>>$REBOOTLOG;
sleep $seconds                                                                       

## Rebooting the box                                                                         
echo `Timestamp` 'Rebooting the box'>>$REBOOTLOG;
echo 0 > $PERSISTENT_PATH/.rebootFlag
echo `/bin/timestamp` ------------ Its a scheduled reboot ----------------- >> $REBOOTLOG
## reboot the box
sh /rebootNow.sh -s RebootSTB.sh -r "Scheduled Reboot" -o "Rebooting the box after device triggered Scheduled Reboot..."
