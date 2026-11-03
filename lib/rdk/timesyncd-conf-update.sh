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


output=""
count=0
LOG_FILE="/opt/logs/ntp.log"
attempts=1
max_attempts=5

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

get_ntp_hosts_from_bootstrap() {
    BOOTSTRAP="/opt/secure/RFC/bootstrap.ini"

    if [ ! -f "$BOOTSTRAP" ]; then
        ntpLog "bootstrap.ini not found at $BOOTSTRAP"
        return 1
    fi

    # Helper to fetch key=value from bootstrap.ini (first match)
    get_bs_val() {
        key="$1"
        # Extract RHS after '=' and trim whitespace
        grep -m1 -E "^[[:space:]]*$key=" "$BOOTSTRAP" 2>/dev/null | \
            cut -d'=' -f2- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
    }

    bs1="$(get_bs_val 'Device.Time.NTPServer1')"
    bs2="$(get_bs_val 'Device.Time.NTPServer2')"
    bs3="$(get_bs_val 'Device.Time.NTPServer3')"
    bs4="$(get_bs_val 'Device.Time.NTPServer4')"
    bs5="$(get_bs_val 'Device.Time.NTPServer5')"

    # Only fill missing values (don’t override TR-181 values if present)
    [ -z "$hostName" ]  && hostName="$bs1"
    [ -z "$hostName2" ] && hostName2="$bs2"
    [ -z "$hostName3" ] && hostName3="$bs3"
    [ -z "$hostName4" ] && hostName4="$bs4"
    [ -z "$hostName5" ] && hostName5="$bs5"

    return 0
}


ntpLog "Retrieve NTP Server URL from /lib/rdk/getPartnerProperty.sh..."
while [ "$attempts" -le "$max_attempts" ]; do

    ntpLog "Attempt $attempts/$max_attempts to retrieve NTP server URL(s)..."
    get_ntp_hosts

    if [ "$hostName" ] || [ "$hostName2" ] || [ "$hostName3" ] || [ "$hostName4" ] || [ "$hostName5" ]; then
        break
    fi

     # If this is the last attempt, try bootstrap as fallback and then break
    if [ $attempts -eq $max_attempts ]; then
        ntpLog "TR-181 returned empty NTP server list; falling back to /opt/secure/RFC/bootstrap.ini..."
        get_ntp_hosts_from_bootstrap
        break
    fi

    sleep 3
    attempts=$((attempts + 1))

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
               systemd_ver=`systemctl --version | grep systemd | awk '{print $2}'`
           if [ "$systemd_ver" -ge 248 ]; then
		   # For systemd version >= 248, add the ConnectionRetrySec parameter
		   echo "ConnectionRetrySec=5" >> /tmp/timesyncd.conf
	       fi
	       cat /tmp/timesyncd.conf > /etc/systemd/timesyncd.conf
               rm -rf /tmp/timesyncd.conf
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
