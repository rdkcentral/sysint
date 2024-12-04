#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
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
##########################################################################

. /etc/device.properties
. /etc/include.properties

SECUREDUMP_TR181_NAME='Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.SecDump.Enable'

if [ -f /tmp/.SecureDumpEnable ]; then
    SEC_DUMP="true"
elif [ -f /tmp/.SecureDumpDisable ]; then
    SEC_DUMP="false"
else
    SEC_DUMP=`/usr/bin/tr181 -g $SECUREDUMP_TR181_NAME 2>&1 > /dev/null`
fi

if [ "$SEC_DUMP" = "false" ]; then
	if [ ! -f /tmp/.SecureDumpDisable ]; then
		touch /tmp/.SecureDumpDisable
        	echo "`/bin/timestamp` [$0]:[SECUREDUMP] Disabled" >> /opt/logs/core_log.txt
	fi
        if [ -f /tmp/.SecureDumpEnable ]; then
        	rm /tmp/.SecureDumpEnable
        fi
	CORE_PATH="/var/lib/systemd/coredump"
        MINIDUMPS_PATH="/opt/minidumps"
        CORE_BACK_PATH="/opt/corefiles_back"
        PERSISTENT_SEC_PATH="/opt"
elif [ "$SEC_DUMP" = "true" ]; then
	if [ ! -f /tmp/.SecureDumpEnable ]; then
        	touch /tmp/.SecureDumpEnable
		echo "`/bin/timestamp` [$0]:[SECUREDUMP] Enabled. Dump location changed to /opt/secure." >> /opt/logs/core_log.txt
	fi
        if [ -f /tmp/.SecureDumpDisable ]; then
		rm /tmp/.SecureDumpDisable
        fi
	CORE_PATH="/opt/secure/corefiles"
	MINIDUMPS_PATH="/opt/secure/minidumps"
	CORE_BACK_PATH="/opt/secure/corefiles_back"
	PERSISTENT_SEC_PATH="/opt/secure"
fi
