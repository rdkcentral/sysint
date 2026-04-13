#!/bin/sh
##############################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2026 RDK Management
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

# Purpose: This script is used to backup the Logs
# Scope: RDK devices
# Usage: This script is triggered by systemd service 
##############################################################################


SCRIPT_NAME=`basename $0`

# Arguments count check
if [ "$#" -ne 2 ]; then
  echo "**************************************************"
  echo "Usage: $SCRIPT_NAME <Process Name> <Alert Message>"
  echo "**************************************************"
  exit 1
fi

# Argument Assigment
MSG_DATA=$2
PROCESS_NAME=$1

# Setup the config File
if [ -f /etc/device.properties ];then
     . /etc/device.properties
fi

# Utility script for getting MAC address utilities
if [ -f /lib/rdk/utils.sh ];then
     . /lib/rdk/utils.sh
fi

if [ -f /lib/rdk/getPartnerId.sh ];then 
    . /lib/rdk/getPartnerId.sh
fi

if [ -f $RDK_PATH/exec_curl_mtls.sh ]; then
    . $RDK_PATH/exec_curl_mtls.sh
else 
    echo "$SCRIPT_NAME: exec_curl_mtls.sh not found, exiting!"
    exit 1
fi

# Configuration Files
VERSION=1
EXECUTION_ID="$$"
HTTP_CODE="/tmp/alertSystemHttpCode_${EXECUTION_ID}"
HTTP_FILENAME="/tmp/alertSystemHttpResponse_${EXECUTION_ID}.txt"

# File that is made available via DCM after processing the DCA profile by T2
TELEMETRY_PROFILE_DEFAULT_PATH="/tmp/DCMSettings.conf"

EnableOCSPStapling="/tmp/.EnableOCSPStapling"
EnableOCSP="/tmp/.EnableOCSPCA"

currentTime=`date '+%Y-%m-%d %H:%M:%S'`
partnerId=$(getPartnerId)
echo "$SCRIPT_NAME: $currentTime"

# Loggging should be handled by the caller 
alertLog() {
    echo "`/bin/timestamp` : $0: $*" 
}

# Extract upload end point from DCM processed telemetry profile
if [ -f $TELEMETRY_PROFILE_DEFAULT_PATH ]; then
    UPLOAD_END_POINT=`grep '"uploadRepository:URL":"' $TELEMETRY_PROFILE_DEFAULT_PATH | awk -F 'uploadRepository:URL":' '{print $NF}' | awk -F '",' '{print $1}' | sed 's/"//g' | sed 's/}//g'`
    if [ ! -z "$UPLOAD_END_POINT" ]; then
        alertLog "Deep sleep notification end point = $UPLOAD_END_POINT" 
    else
        alertLog "Empty upload endpoint: $UPLOAD_END_POINT from $TELEMETRY_PROFILE_DEFAULT_PATH"
        exit 1
    fi
else
    alertLog "$TELEMETRY_PROFILE_DEFAULT_PATH, File Not Found"
    exit 1
fi

# Device attributes
estb_mac=$(getEstbMacAddress)
software_version=`grep ^imagename: /version.txt | cut -d ':' -f2`


if [ "x$PROCESS_NAME" == "xdeepSleepMgrMain" ]; then
    # Message data is actual metadata header in case of trigger from deepSleep manager process
    # This change is needed since there are data clouds in different deployment which are not flexible to accomodate any deviations in data format
    strjson="{\"searchResult\":[{\"Time\":\"$currentTime\"},{\"process_name\":\"$PROCESS_NAME\"},{\"mac\":\"$estb_mac\"},{\"Version\":\"$software_version\"},{\"PartnerId\":\"$partnerId\"},{\"$MSG_DATA\":\"1\"}]}"
else
    strjson="{\"searchResult\":[{\"process_name\":\"$PROCESS_NAME\"},{\"mac\":\"$estb_mac\"},{\"Version\":\"$software_version\"},{\"msgTime\":\"$currentTime\"},{\"PartnerId\":\"$partnerId\"},{\"logEntry\":\"$MSG_DATA\"}]}"
fi

if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
    CURL_CMD="curl -w '%{http_code}\n' -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '$strjson' -o \"$HTTP_FILENAME\" \"$UPLOAD_END_POINT\" --cert-status --connect-timeout 30 -m 30 "
else
    CURL_CMD="curl -w '%{http_code}\n' -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '$strjson' -o \"$HTTP_FILENAME\" \"$UPLOAD_END_POINT\" --connect-timeout 30 -m 30 "
fi

TLSRet=`exec_curl_mtls "$CURL_CMD" "alertLog"`
alertLog "$SCRIPT_NAME: CURL_CMD : $CURL_CMD"
eval $CURL_CMD > $HTTP_CODE
ret=$?
http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
alertLog "$SCRIPT_NAME: Return Status: $ret, HTTP CODE:$http_code"
if [ "$ret" -eq "0" ] && [ "$http_code" -eq "200" ]; then
    #Upload success
    rm -f $HTTP_FILENAME $HTTP_CODE
    exit 0
else
    #Upload failed
    rm -f $HTTP_FILENAME $HTTP_CODE
    exit 1
fi
