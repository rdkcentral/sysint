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

# This script to collect Video Decoder performance details
# for monitoring in telemetry

TEMP_LOG="/opt/logs/videodecoder.log"
THIS_SCRIPT=$(basename "$0")
log()
{
    echo "$(date '+%Y %b %d %H:%M:%S.%6N') [$THIS_SCRIPT#$$]: $*"
}
touch $TEMP_LOG

# Compare with previous value before updating the cron
if [ $# -eq 0 ]; then
    FRQMIN=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.VideoTelemetry.FrequncyMinutes 2>&1 > /dev/null`
else
    FRQMIN=$1
fi

output=`crontab -l -c /var/spool/cron/ | grep vdec-statistics.sh | grep -o '[0-9]'`
if [ "$FRQMIN" != 0 ] && [ "$output" != "$FRQMIN" ]; then
    # Set new cron job from the file
    sh /lib/rdk/cronjobs_update.sh "update" "vdec-statistics.sh" "*/$FRQMIN * * * * sh /lib/rdk/vdec-statistics.sh"
    log "Created/Updated CRONJOB to run the script on every $FRQMIN mins" >> $TEMP_LOG
fi

log "Retrieving Video Decoder performance information for telemetry support" >> $TEMP_LOG
log "cat /sys/class/vdec/vdec_status" >> $TEMP_LOG
cat /sys/class/vdec/vdec_status >> $TEMP_LOG

log "cat /sys/class/vdec/core" >> $TEMP_LOG
cat /sys/class/vdec/core >> $TEMP_LOG

log "cat /sys/class/codec_mm/codec_mm_dump" >> $TEMP_LOG
cat /sys/class/codec_mm/codec_mm_dump >> $TEMP_LOG

