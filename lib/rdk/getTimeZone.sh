#!/bin/sh
##
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:##www.apache.org#licenses#LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##

. /etc/device.properties

timeZoneDSTPath="/opt/persistent/timeZoneDST"
timeZoneOffsetMap="/etc/timeZone_offset_map"
timeZone=""
timeZoneOffset=""
zoneValue=""

#Log framework to print timestamp and source script name
timelog()
{
    echo "`/bin/timestamp`: getTimeZone.sh: $*"
}

if [ "$DEVICE_NAME" = "PLATCO" ]; then
   timelog "Reading Timezone value from $timeZoneDSTPath file..."
   timeZone=`cat "$timeZoneDSTPath" | grep -v 'null'`

   if [ -z "$timeZone" ]; then
      timelog "/opt/persistent/timeZoneDST is empty, default timezone America/New_York applied"
      timeZone="America/New_York"
   else
      timelog "Device TimeZone: $timeZone"
   fi

   if [ -f "$timeZoneOffsetMap" -a -s "$timeZoneOffsetMap" ]; then
      zoneValue=`cat $timeZoneOffsetMap | grep $timeZone | cut -d ":" -f2 | sed 's/[\",]/ /g'`
      timeZoneOffset=`cat $timeZoneOffsetMap | grep $timeZone | cut -d ":" -f3 | sed 's/[\",]/ /g'`
   fi

   if [ -z "$zoneValue" -o -z "$timeZoneOffset" ]; then
      timelog "Given TimeZone not supported by XConf - default timezone US/Eastern with offset 0 is applied"
      zoneValue="US/Eastern"
      timeZoneOffset="0"
   fi

   timelog "TimeZone Information after mapping : zoneValue = $zoneValue, timeZoneOffset = $timeZoneOffset"
else
   JSONPATH=/opt
   if [ "$CPU_ARCH" == "x86" ]; then JSONPATH=/tmp; fi

   if [ -f $JSONPATH/output.json ] && [ -s $JSONPATH/output.json ];then
      timelog "Reading Timezone value from $JSONPATH/output.json file..."
      zoneValue=`grep timezone $JSONPATH/output.json | cut -d ":" -f2 | sed 's/[\",]/ /g' | head -n1`
   fi

   if [ ! -z $zoneValue ]; then
      timelog "Got timezone using $JSONPATH/output.json successfully, value:$zoneValue"
      t2ValNotify "TimeZone_split" "$zoneValue"
   elif [ -f "$timeZoneDSTPath" -a -s "$timeZoneDSTPath" ]; then
      timelog "Timezone value from output.json is empty, Reading from $timeZoneDSTPath file..."
      zoneValue=`cat "$timeZoneDSTPath" | grep -v 'null'`
      if [ ! -z $zoneValue ]; then
         timelog "Got timezone using $timeZoneDSTPath successfully, value:$zoneValue"
      else
         zoneValue="Universal"
         timelog "Timezone files $JSONPATH/output.json and $timeZoneDSTPath not found, proceeding with default timezone=$zoneValue"
      fi
   fi
fi

echo "$zoneValue"
