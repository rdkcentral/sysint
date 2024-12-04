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
if [ -f /etc/device.properties ];then
    . /etc/device.properties
fi

if [ -f /etc/rfc.properties ];then
    . /etc/rfc.properties
fi

OCSPSTAPLE_TR181_NAME='Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.CRL.Enable'
OCSPCA_TR181_NAME='Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.CRL.DirectOCSP'

StatusOCSPSTAPLE=`tr181Set ${OCSPSTAPLE_TR181_NAME} 2>&1 > /dev/null`
StatusOCSPCA=`tr181Set ${OCSPCA_TR181_NAME} 2>&1 > /dev/null`

echo "[$0] status of RFC $OCSPSTAPLE_TR181_NAME: $StatusOCSPSTAPLE $OCSPCA_TR181_NAME: $StatusOCSPCA"

if [ "$StatusOCSPSTAPLE" = "true" ]; then
    echo "[$0]:[OCSPSTAPLE] Enabled"
    touch /tmp/.EnableOCSPStapling
else
    echo "[$0]:[OCSPSTAPLE] Disabled"
    if [ -f /tmp/.EnableOCSPStapling ]; then
        rm /tmp/.EnableOCSPStapling
    fi
fi

if [ "$StatusOCSPCA" = "true" ]; then
    echo "[$0]:[OCSPCA] Enabled"
    touch /tmp/.EnableOCSPCA
else
    echo "[$0]:[OCSPCA] Disabled"
    if [ -f /tmp/.EnableOCSPCA ]; then
        rm /tmp/.EnableOCSPCA
    fi
fi
