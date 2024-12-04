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

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

# Look whether we have already installed cron job for this
tCheck=`sh /lib/rdk/cronjobs_update.sh "check-entry" "wifi-telemetry-cronjob.sh"`
if [ "$tCheck" != "0" ]; then
    # This means, the cron job is install already and execution of this thread is triggered by cron
    systemctl start wifi-telemetry.service
    exit
fi

# Get the RFC..  If RFC is not enabled, set both samplingInterval and Logging Interval to 900s as same as existing code.
if [ ! -f /lib/rdk/isFeatureEnabled.sh ]; then
    echo "No logic to verify the Feature is enabled or not. Assuming RFC_ENABLE_WIFI_TM_DC is false"
    exit
fi

dateVariable=`/bin/timestamp`

. /lib/rdk/isFeatureEnabled.sh WIFI_TM_DC

if [ "$RFC_ENABLE_WIFI_TM_DC" == "true" ] || [ "$RFC_ENABLE_WIFI_TM_DC" == "1" ] ; then
    samplingInterval=$RFC_DATA_WIFI_TM_DC_SAMPLE_INT
    loggingInterval=$RFC_DATA_WIFI_TM_DC_LOG_INT

    echo "$dateVariable RFC_ENABLE_WIFI_TM_DC is $RFC_ENABLE_WIFI_TM_DC" >> /opt/logs/wifi_telemetry.log
    echo "$dateVariable RFC_DATA_WIFI_TM_DC_SAMPLE_INT is $RFC_DATA_WIFI_TM_DC_SAMPLE_INT" >> /opt/logs/wifi_telemetry.log
    echo "$dateVariable RFC_DATA_WIFI_TM_DC_LOG_INT is $RFC_DATA_WIFI_TM_DC_LOG_INT" >> /opt/logs/wifi_telemetry.log
else
    echo "$dateVariable RFC_ENABLE_WIFI_TM_DC is false" >> /opt/logs/wifi_telemetry.log
    # Remove the cron job if it is disabled by the RFC Server
    if [ "$tCheck" != "0" ]; then
        sh /lib/rdk/cronjobs_update.sh "remove" "wifi-telemetry-cronjob.sh"
    fi
    exit
fi

#Cron does not support seconds based timer.. So calculate the time in mins
iterationCnt=`expr $samplingInterval / 60`
variable="*/$iterationCnt * * * * /bin/sh /lib/rdk/wifi-telemetry-cronjob.sh >> /opt/logs/wifi_telemetry.log"

# Set new cron job from the file            
sh /lib/rdk/cronjobs_update.sh "add" "wifi-telemetry-cronjob.sh" "$variable"
# End of Script
