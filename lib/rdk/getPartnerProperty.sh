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
## Script to Partner Bootstrap Configuration
## Updates the following information in the settop box
##    list of features that are enabled or disabled
##    if feature configuration is effective immediately
##    updates startup parameters for each feature
##    updates the list of variables in a single file
## Author: Milorad
##################################################################

if [ $# != 1 ] ; then
    echo "`/bin/timestamp` [BP] Usage: $0 <property_name>" >> /opt/logs/ntp.log
    exit 1
fi

cgPDf=0

if [ "$1" = "ntpHost" ]; then
    result=`tr181 Device.Time.NTPServer1 2>&1 > /dev/null`
    echo $result
elif [ "$1" = "ntpHost2" ]; then
    result=`tr181 Device.Time.NTPServer2 2>&1 > /dev/null`
    echo $result
elif [ "$1" = "ntpHost3" ]; then
    result=`tr181 Device.Time.NTPServer3 2>&1 > /dev/null`
    echo $result
elif [ "$1" = "ntpHost4" ]; then
    result=`tr181 Device.Time.NTPServer4 2>&1 > /dev/null`
    echo $result
elif [ "$1" = "ntpHost5" ]; then
    result=`tr181 Device.Time.NTPServer5 2>&1 > /dev/null`
    echo $result
elif [ "$1" = "partnerName" ]; then
    result=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Bootstrap.PartnerName 2>&1 > /dev/null`
    echo $result
elif [ "$1" = "partnerProductName" ]; then
    result=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Bootstrap.PartnerProductName 2>&1 > /dev/null`
    echo $result
else
    cgPDf=1
fi

if [ $cgPDf -ne 0 ]; then
    if [ -f /etc/getBootstrapProperty.sh ]; then
        result=`/etc/getBootstrapProperty.sh $1`
        echo $result
        echo "`/bin/timestamp` [BP] Returning through getBootstrapProperty call for $1, result=$result" >> /opt/logs/ntp.log
    fi
else
        echo "`/bin/timestamp` [BP] Returning through tr181 call for $1, result=$result" >> /opt/logs/ntp.log
fi
