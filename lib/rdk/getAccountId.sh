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

KEY_LEN="32"

ACCOUNT_ID_LOG="$LOG_PATH/servicenumber.log"
ACCOUNT_ID_TR181_NAME='Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.AccountInfo.AccountID'

getAccountId()
{
    accountId=`/usr/bin/tr181 -g $ACCOUNT_ID_TR181_NAME 2>&1 > /dev/null`
    accountIdLen=${#accountId}

    # Added a command to identify the Parent Process
    echo "Parent Process INFO" >> $ACCOUNT_ID_LOG
    echo "$PPID : `cat /proc/$PPID/cmdline`" >> $ACCOUNT_ID_LOG
    echo "$$ : `cat /proc/$$/cmdline`" >> $ACCOUNT_ID_LOG

    if [ "$accountId" != "" ] ; then
        if [ "$accountIdLen" -lt "$KEY_LEN" ] && [ `expr "$accountId" : ".*[a-zA-Z0-9_-].*"` -gt 0 ] &&  [ `expr "$accountId" : ".*[!@#\$%^\&*()_+].*"` -eq 0 ];  then
            echo "`/bin/timestamp` : accountId is valid and value retrieved from tr181 param." >> $ACCOUNT_ID_LOG
            echo "$accountId"
        else
            echo "`/bin/timestamp` : accountId is invalid (Id: \"$accountId\" Len:$accountIdLen) as contains special characters or larger than max $KEY_LEN characters." >> $ACCOUNT_ID_LOG
            echo "Unknown"
        fi

    else
        echo "`/bin/timestamp` : accountId is empty from $ACCOUNT_ID_TR181_NAME param, sending accountid as Unknown" >> $ACCOUNT_ID_LOG
        echo "Unknown"
    fi
}
