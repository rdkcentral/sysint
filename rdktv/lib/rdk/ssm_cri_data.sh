#!/bin/sh
##
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:##www.apache.org#licenses#LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##

SSM_LOG="/opt/logs/ssmdataparser.log"
CRI_LOG="/opt/logs/cridataparser.log"
THIS_SCRIPT=$(basename "$0")

log()
{
    echo "$(date '+%Y %b %d %H:%M:%S.%6N') [$THIS_SCRIPT#$$]: $*"
}
touch $SSM_LOG
touch $CRI_LOG

getSSMdata()
{
    if [ -f "/tmp/ssm_data" ]; then
        log "/usr/bin/ssmdataparser" > $SSM_LOG
        /usr/bin/ssmdataparser >> $SSM_LOG
    else
        #/opt/panel/ssm_data not exists.Gracefully returning zero
        return 0
    fi
}

getCRIdata()
{
    if [ -f "/opt/panel/cri_data" ]; then
        log "/usr/bin/cridataparser" > $CRI_LOG
        /usr/bin/cridataparser >> $CRI_LOG
    else
        #/opt/panel/cri_data not exists.Return zero
        return 0
    fi
}
getSSMdata
getCRIdata
