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

# Purpose : To update the timesyncd configuration file
# Scope : RDK Devices
# Usage : Invoke by systemd service

sleep_time=5
output=""
count=0

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

# NTP URL from the property file
get_ntp_hosts() {
if [ -f /lib/rdk/getPartnerProperty.sh ]; then
     hostName=`/lib/rdk/getPartnerProperty.sh ntpHost`
     hostName2=`/lib/rdk/getPartnerProperty.sh ntpHost2`
     hostName3=`/lib/rdk/getPartnerProperty.sh ntpHost3`
     hostName4=`/lib/rdk/getPartnerProperty.sh ntpHost4`
     hostName5=`/lib/rdk/getPartnerProperty.sh ntpHost5`
fi
}

while [ ! "$hostName" ] && [ ! "$hostName2" ] && [ ! "$hostName3" ] && [ ! "$hostName4" ] && [ ! "$hostName5" ]
do
   get_ntp_hosts
   sleep 5
done
echo "NTP Server URL for this env is $hostName ..!"

# Update the timesyncd configuration with URL
if [ -f /etc/systemd/timesyncd.conf ];then
      defaultHostName=$(cat /etc/systemd/timesyncd.conf | grep ^NTP= | cut -d "=" -f2 | tr -s ' ')
      defaultHostName2=$defaultHostName
      if [ "$hostName" ] || [ "$hostName2" ] || [ "$hostName3" ] || [ "$hostName4" ] || [ "$hostName5" ];then
           if  [ "$hostName" == "$defaultHostName" ] || [ "$hostName2" == "$defaultHostName" ] || [ "$hostName3" == "$defaultHostName" ] || [ "$hostName4" == "$defaultHostName" ] || [ "$hostName5" == "$defaultHostName" ];then
                 defaultHostName2=''
           fi

           # Update the timesyncd configuration with URL
           cp /etc/systemd/timesyncd.conf /tmp/timesyncd.conf
           sed -i "s/^NTP=$defaultHostName/NTP=$hostName $hostName2 $hostName3 $hostName4 $hostName5 $defaultHostName2/" /tmp/timesyncd.conf
           echo "ConnectionRetrySec=5" >> /tmp/timesyncd.conf
           cat /tmp/timesyncd.conf > /etc/systemd/timesyncd.conf
           rm -rf /tmp/timesyncd.conf
           # Restart the service to reflect the new conf
           echo "`date`: Restarting the service: systemd-timesyncd.service ..!"
           /bin/systemctl reset-failed systemd-timesyncd.service
           /bin/systemctl restart systemd-timesyncd.service
      else
           echo "Hostnames are same ($hostName, $defaultHostName)"
      fi
else
      echo "Missing configuration file: /etc/systemd/timesyncd.conf"
fi

exit 0
