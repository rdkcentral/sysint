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

FKPS_BROKER_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.FkpsBrokerUrl 2>&1)
if [ -z "$FKPS_BROKER_URL" ]; then
    FKPS_BROKER_URL="$FKPS_BROKER_DEFAULT"
fi

FKPS_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Sysint.FkpsUrl 2>&1)
if [ -z "$FKPS_URL" ]; then
    FKPS_URL="$FKPS_DEFAULT"
fi

getFKPSBURL()
{
    # assign default URL
    defaultURL="$FKPS_BROKER_URL"
    result=${defaultURL}

    # if configuration file exists and build type is not production
    # then read URL from configuration file
    if [ -f $PERSISTENT_PATH/fkpsb.conf ] && [ "$BUILD_TYPE" != "prod" ] ; then
        urlString=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/fkpsb.conf`
        if [ -n "$urlString" ] ; then
            result=${urlString}
        fi
    fi

    echo -n ${result}
}

getFKPSURL()
{
    # assign default URL
    defaultURL="$FKPS_URL"
    # get build type
    result=${defaultURL}

    # if configuration file exists and build type is not production
    # then read URL from configuration file
    if [ -f $PERSISTENT_PATH/fkps.conf ] && [ "$BUILD_TYPE" != "prod" ] ; then
        urlString=`grep -v '^[[:space:]]*#' $PERSISTENT_PATH/fkps.conf`
        if [ -n "$urlString" ] ; then
            result=${urlString}
        fi
    fi

    echo -n ${result}
}
