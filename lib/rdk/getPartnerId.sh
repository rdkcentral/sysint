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
##################################################################
## Script to retrieve receiver ID and partner ID
#
## Author: Milorad Neskovic
##################################################################
if [ "$WHITEBOX_ENABLED" == "true" ]; then
    . /etc/wbdevice.conf
else
    wbpath=/opt/www/whitebox/
fi

aspath=/opt/www/authService/

. /etc/include.properties
. /etc/device.properties

getReceiverId()
{
    outputR=`awk -F',' </tmp/gpid.txt '{ for (i=1; i<=NF; i++) print $i}'| grep deviceId | cut -d ":" -f2 | tr -d " " |sed -e 's/[{,},/"]//g'`
    deviceId=`echo "$outputR" | tr '[A-Z]' '[a-z]'`
    if [ "$deviceId" != "" ]; then
       echo "$deviceId"
    else
       if [ -f $aspath/deviceid.dat ]; then
           cat $aspath/deviceid.dat
       elif [ -f $wbpath/wbdevice.dat ]; then
           cat $wbpath/wbdevice.dat
       else
           echo ""
       fi
    fi
}



getPartnerId()
{
    WHOAMI_SUPPORT=$(grep '^WHOAMI_SUPPORT=' /etc/device.properties | cut -d'=' -f2 | tr -d '"')
    if [ "$WHOAMI_SUPPORT" == "true" ]; then
        echo "WhoAmI support is enabled"
    else
        echo "WhoAmI support is disabled"
    fi
    if [ "$WHOAMI_SUPPORT" == "true" ]; then
        partnerName="$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Bootstrap.PartnerName 2>&1)"
        echo "$partnerName"
        return;
    fi
    
    # Check for the partner ID
    sh /lib/rdk/getDeviceId.sh > /tmp/partnerid.txt
    output=`awk -F',' </tmp/partnerid.txt '{ for (i=1; i<=NF; i++) print $i}'| grep partnerId | cut -d ":" -f2 | tr -d " " |sed -e 's/[{,},/"]//g'`
    partnerName=`echo "$output" | tr '[A-Z]' '[a-z]'`

    if [ "$partnerName" != "" ]; then
       echo "$partnerName"
    else
        if [ -s $aspath/partnerId3.dat ]; then
            cat $aspath/partnerId3.dat
        else

            # Use default partnerId
			# receiverId and partnerId are retrieved as a set
			receiverId=$(getReceiverId)
			if [ "$receiverId" != "" ]; then
				if [ "$DEVICE_NAME" = "PLATCO" ]; then
					echo "xglobal"
				else
					echo "comcast"
				fi
			else
				echo ""
			fi

        fi
    fi
}

getExperience()
{
    # Check for the Experience
    curl -H "Authorization: Bearer `WPEFrameworkSecurityUtility | cut -d '"' -f 4`" --header "Content-Type: application/json" -d '{"jsonrpc":"2.0", "id":3, "method":"org.rdk.AuthService.getExperience", "params":{}}' http://127.0.0.1:9998/jsonrpc | cut -d ":" -f4-5 | sed 's/,.*/}/' > /tmp/experienceid.txt
    experience=`awk -F',' </tmp/experienceid.txt '{ for (i=1; i<=NF; i++) print $i}'| grep experience | cut -d ":" -f2 | tr -d " " |sed -e 's/[{,},/"]//g'`
    if [ "$experience" != "" ]; then
       echo "$experience"
    else
        echo "X1"
    fi
}
