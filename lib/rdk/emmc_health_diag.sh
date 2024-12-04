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


LOG_FILE=/opt/logs/eMMC_diag.log
if [ ! -f $LOG_FILE ]; then
     touch $LOG_FILE
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

TMP_EMMCLOG=/tmp/emmc-report.log
TMP_EMMCVAL=/tmp/emmc-val.log

state=$1

# BigEndian to LittleEndian
conv_val()
{
    val=$1
    j=7
    k=8
    regval=""
    for ((i=0 ; i < 8; i++)); do
        byte=`echo $val | cut -b $j-$k`
        regval="$regval$byte"
        i=`expr $i + 1`
        j=`expr $j - 2`
        k=`expr $k - 2`
    done
}
report=`tr181 Device.Services.STBService.1.Components.X_RDKCENTRAL-COM_eMMCFlash.DeviceReport 2>&1 > /dev/null`
echo "$report" > $TMP_EMMCLOG
echo "`/bin/timestamp` : Running eMMC Version at $state: `mmc extcsd read /dev/mmcblk0 |grep Version|sed $'s/[^[:print:]\t]//g'`" >> $LOG_FILE

# If Device Report is valid log it.
if [ "$report" != "" ]; then

    # [151:148] Pre EOL State EUDA
    ext=`dd skip=149 count=4 if=$TMP_EMMCLOG of=$TMP_EMMCVAL bs=2 2>&1 > /dev/null`
    mem=`cat $TMP_EMMCVAL`

    conv_val "$mem"
    echo "`/bin/timestamp` : Pre EOL State EUDA: $regval" >> $LOG_FILE
    t2ValNotify "emmcPEOLEuda_split" "$regval"

    # [155:152] Pre EOL State System
    ext=`dd skip=153 count=4 if=$TMP_EMMCLOG of=$TMP_EMMCVAL bs=2 2>&1 > /dev/null`
    mem=`cat $TMP_EMMCVAL`

    conv_val "$mem"
    echo "`/bin/timestamp` : Pre EOL State System: $regval" >> $LOG_FILE
    t2ValNotify "emmcSystem_split" "$regval"

    # [159:156] Pre EOL State MCL
    ext=`dd skip=157 count=4 if=$TMP_EMMCLOG of=$TMP_EMMCVAL bs=2 2>&1 > /dev/null`
    mem=`cat $TMP_EMMCVAL`

    conv_val "$mem"
    echo "`/bin/timestamp` : Pre EOL State MLC: $regval" >> $LOG_FILE

    # [179:176] Health Device level EUDA
    ext=`dd skip=177 count=4 if=$TMP_EMMCLOG of=$TMP_EMMCVAL bs=2 2>&1 > /dev/null`
    mem=`cat $TMP_EMMCVAL`

    conv_val "$mem"
    echo "`/bin/timestamp` : Health Device Level EUDA: $regval" >> $LOG_FILE
    t2ValNotify "emmcHDLEUda_split" "$regval"

    # [183:180] Health Device level System
    ext=`dd skip=181 count=4 if=$TMP_EMMCLOG of=$TMP_EMMCVAL bs=2 2>&1 > /dev/null`
    mem=`cat $TMP_EMMCVAL`

    conv_val "$mem"
    echo "`/bin/timestamp` : Health Device Level System: $regval" >> $LOG_FILE
    t2ValNotify "emmcHealthSystem_split" "$regval"

    # [187:184] Health Device level MLC
    ext=`dd skip=185 count=4 if=$TMP_EMMCLOG of=$TMP_EMMCVAL bs=2 2>&1 > /dev/null`
    mem=`cat $TMP_EMMCVAL`

    conv_val "$mem"
    echo "`/bin/timestamp` : Health Device Level MLC: $regval" >> $LOG_FILE

    # [195:192] Free Block Count
    ext=`dd skip=193 count=4 if=$TMP_EMMCLOG of=$TMP_EMMCVAL bs=2 2>&1 > /dev/null`
    Freemem=`cat $TMP_EMMCVAL`

    conv_val "$Freemem"
    echo "`/bin/timestamp` : Free Block Count in Enhanced Partion: $regval" >> $LOG_FILE
    t2ValNotify "emmcFreeBlk_split" "$regval"
    Freecount=$((0x$regval))

    # [199:196] Count of Enhanced Premature Closures
    ext=`dd skip=197 count=4 if=$TMP_EMMCLOG of=$TMP_EMMCVAL bs=2 2>&1 > /dev/null`
    mem=`cat $TMP_EMMCVAL`

    conv_val "$mem"
    echo "`/bin/timestamp` : Count of Enhanced Premature closures: $regval" >> $LOG_FILE
    t2ValNotify "emmcPremClsCnt_split" "$regval"

    # [203:200] EUDA accumulated host write count in 100MB
    ext=`dd skip=201 count=4 if=$TMP_EMMCLOG of=$TMP_EMMCVAL bs=2 2>&1 > /dev/null`
    mem=`cat $TMP_EMMCVAL`

    conv_val "$mem"
    echo "`/bin/timestamp` : EUDA accumulated host write count: $regval" >> $LOG_FILE
    t2ValNotify "emmcEudaWrCnt_split" "$regval"

    # [207:204] Enhanced accumulated host write count in 100MB
    ext=`dd skip=205 count=4 if=$TMP_EMMCLOG of=$TMP_EMMCVAL bs=2 2>&1 > /dev/null`
    mem=`cat $TMP_EMMCVAL`

    conv_val "$mem"
    echo "`/bin/timestamp` : Enhanced accumulated host write count: $regval" >> $LOG_FILE
    t2ValNotify "emmcEnhWrCnt_split" "$regval"

    echo "`/bin/timestamp` : Start the sync for emmc diag report"
    sync
    echo "`/bin/timestamp` : End of sync for emmc diag report"

else

    echo "`/bin/timestamp` : tr181 Returned Null device report" >> $LOG_FILE

fi
