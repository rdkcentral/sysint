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


TLS_LOG_FILE="$LOG_PATH/tlsError.log"
tlsLog()
{
    echo "`/bin/timestamp`: $*" >> $TLS_LOG_FILE
}
if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

getMtlsCreds()
{
    mtlscreds=""
    if [ "$LONG_TERM_CERT" == "true" ]; then
       ltcert=$2
       cred=$3
       if [ -z $ltcert ] || [ -z $cred ]; then
           echo "Error: EOL device $1, require cert credential"
	   exit 127
       fi
    fi

    if [ -f /opt/certs/devicecert_1.pk12 ] && [ -f /usr/bin/rdkssacli ]; then
        mtlscreds=" --cert-type P12 --cert /opt/certs/devicecert_1.pk12:$(/usr/bin/rdkssacli "{STOR=GET,SRC=kquhqtoczcbx,DST=/dev/stdout}")"
    elif [ -f $ltcert ]  && [ "$LONG_TERM_CERT" == "true" ]; then
        if [ ! -f /usr/bin/GetConfigFile ]; then
             echo "Error: $1 GetConfigFile Not Found"
             exit 127
        fi
        if [ ! -f "$cred" ]; then
            GetConfigFile $cred
        fi
        if [ ! -f "$cred" ]; then
            echo "Error: $1 Getconfig file failed"
            exit 128
        fi
        mtlscreds=" --key $cred --cert $ltcert"
    else
        if [ ! -f /usr/bin/GetConfigFile ];then
            echo "Error: $1 GetConfigFile Not Found. Exit!!"
            exit 127
        fi
        ID="/tmp/.cfgStaticxpki"
        if [ ! -f "$ID" ]; then
            GetConfigFile $ID
        fi
        if [ ! -f "$ID" ]; then
            echo "Error: $1 GetConfigFile Failed. Exit"
            exit 128
        fi
        mtlscreds=" --cert-type P12 --cert /etc/ssl/certs/staticXpkiCrt.pk12:$(cat $ID)"
        UPTIME=$(cut -d' ' -f1 /proc/uptime)
        tlsLog "xPKIStaticCert: /etc/ssl/certs/staticDeviceCert.pk12 uptime $UPTIME seconds,$0"
        if [ -f /lib/rdk/t2Shared_api.sh ]; then
            t2ValNotify "SYS_INFO_xPKI_Static_Fallback" "xPKIStaticCert: /etc/ssl/certs/staticDeviceCert.pk12 uptime $UPTIME seconds,$0"
        fi
    fi
    echo "$mtlscreds"
}

