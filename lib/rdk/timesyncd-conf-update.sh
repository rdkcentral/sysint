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
LOG_FILE="/opt/logs/ntp.log"

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

#Log framework to print timestamp and source script name
ntpLog()
{
    echo "`/bin/timestamp` : $0: $*" >> $LOG_FILE
}

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

# Ensure auth service is ready for URL request
if [ -f /lib/systemd/system/authservice.service ];then
    auth_pid=`pidof authservice`
    while [ ! $auth_pid ]
    do
         sleep 5
         auth_pid=`pidof authservice`
    done
    ntpLog "Auth service ready now..!"
    sleep 2
fi

ntpLog "Retrive NTP Server URL from /lib/rdk/getPartnerProperty.sh..."
while [ ! "$hostName" ] && [ ! "$hostName2" ] && [ ! "$hostName3" ] && [ ! "$hostName4" ] && [ ! "$hostName5" ]
do
    # NTP URL from the property file
    get_ntp_hosts
    sleep 5
done

partnerHostnames="$hostName $hostName2 $hostName3 $hostName4 $hostName5"
ntpLog "NTP Server URL for the partner:$partnerHostnames"

# Update the timesyncd configuration with URL
if [ -f /etc/systemd/timesyncd.conf ];then
      defaultHostName=$(cat /etc/systemd/timesyncd.conf | grep ^NTP= | cut -d "=" -f2 | tr -s ' ')
      defaultHostName2=$defaultHostName
      if [ "$hostName" ] || [ "$hostName2" ] || [ "$hostName3" ] || [ "$hostName4" ] || [ "$hostName5" ];then
           if  [ "$hostName" == "$defaultHostName" ] || [ "$hostName2" == "$defaultHostName" ] || [ "$hostName3" == "$defaultHostName" ] || [ "$hostName4" == "$defaultHostName" ] || [ "$hostName5" == "$defaultHostName" ];then
                 defaultHostName2=''
           fi
           for host in $partnerHostnames; do
               if grep -q "$host" /etc/systemd/timesyncd.conf; then
                    updateHostnames+=" "
               else
                    updateHostnames+="$host "
               fi
           done
           updateHostname=$(echo "$updateHostnames" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

           if [ ! -z "$updateHostname" ]; then
               # Update the timesyncd configuration with URL
               ntpLog "Update the timesyncd configuration with URL updateHostname=$updateHostname defaultHostName=$defaultHostName2"

               cp /etc/systemd/timesyncd.conf /tmp/timesyncd.conf
               sed -i "s/^NTP=.*/NTP=/g" /tmp/timesyncd.conf
               sed -i "s/^NTP=/NTP=$updateHostname $defaultHostName2/" /tmp/timesyncd.conf
               cat /tmp/timesyncd.conf > /etc/systemd/timesyncd.conf
               rm -rf /tmp/timesyncd.conf

               # Restart the service to reflect the new conf
               ntpLog "Restarting the service: systemd-timesyncd.service ..!"
               /bin/systemctl reset-failed systemd-timesyncd.service
               /bin/systemctl restart systemd-timesyncd.service
           else
               ntpLog "No new Hostnames found to update /etc/systemd/timesyncd.conf"
           fi
      else
           ntpLog "Hostnames are same ($hostName, $defaultHostName)"
      fi
else
      ntpLog "Missing configuration file: /etc/systemd/timesyncd.conf"
fi

exit 0
