#! /bin/sh
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

##################################################################
## This script inserts a random uuid as receiver id and partner id as community.
#
## Author: RDK Community
##################################################################

deviceIdFile="/opt/www/authService/deviceid.dat"
partnerIdFile="/opt/www/authService/partnerId3.dat"

#Check whether time event is received
if [ -f /usr/bin/timedatectl ] ; then
   ntpstatus=`timedatectl |grep "Network time on"|cut -d ':' -f2 |xargs`

   if [ "$ntpstatus" = "yes" ] ; then
        touch /tmp/stt_received
   fi
fi

#Check whether authservice file already exists
response=`curl --write-out "%{http_code}\n" --silent --output /dev/null http://localhost:50050/authService/getDeviceId`
if [ $response -eq 200 ] ; then
   if [ ! -f "${deviceIdFile}" ]; then
      uuid=`uuidgen`
      echo "$uuid" > ${deviceIdFile}
   fi
   if [ ! -f "${partnerIdFile}" ]; then
      echo "community" > ${partnerIdFile}
   fi
   echo "All set. Exiting"
else
   uuid=`uuidgen`
   echo "{ \"deviceId\" : \"$uuid\" , \"partnerId\": \"community\" }" >~/authService/getDeviceId
fi
