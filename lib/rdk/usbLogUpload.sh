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
if [ $# -ne 1 ]; then
     echo "USAGE: $0 <USB mount point>"
         exit 4
fi

if [ "$DEVICE_NAME" != "PLATCO" ]; then
    echo "ERROR! USB Log download not available on this device."
        exit 4
fi
USB_MNTP=$1
USB_LOG="$USB_MNTP/Log"


if [ -z $RDK_PATH ]; then
    RDK_PATH="/lib/rdk"
fi

if [ -f $RDK_PATH/utils.sh ]; then
   . $RDK_PATH/utils.sh
fi



if [ ! -d $USB_MNTP ]; then
    echo "`/bin/timestamp` ERROR! USB drive is not mounted at $USB_MNTP" >> $LOG_PATH/dcmscript.log
        # Return error
        exit 2 # No USB
fi

#create Log directory
if [ ! -d $USB_LOG ]; then
    mkdir -p $USB_LOG
fi

#create file name in form og Logs_<MAC>_<unix epoch time>.gtz

echo "`/bin/timestamp` STARTING USB LOG UPLOAD" >> $LOG_PATH/dcmscript.log
/bin/timestamp >> $LOG_PATH/dcmscript.log

# Construct File Name:

MAC=`getMacAddressOnly`
dt=`date "+%m-%d-%y-%I-%M%p"`
LOG_FILE=$MAC"_Logs_$dt.tgz"

FILE_NAME=$MAC"_Logs_$dt"

echo "`/bin/timestamp` Folder: $USB_LOG" >> $LOG_PATH/dcmscript.log
echo "`/bin/timestamp` File: $FILE_NAME" >> $LOG_PATH/dcmscript.log

USB_DIR="/opt/tmpusb/$FILE_NAME"
mkdir -p $USB_DIR

sync
if [ ! -d $USB_DIR ]; then
    echo "`/bin/timestamp` ERROR! Failed to create $USB_DIR" >> $LOG_PATH/dcmscript.log
        exit 3 # Writing error
fi

# Move now all of the log files that were collected since last upload

cd $LOG_PATH
mv $LOG_PATH/* $USB_DIR/.

#Send SIGHUP to reload syslog-ng after uploading logs to usb
if [ "$SYSLOG_NG_ENABLED" == "true" ] ; then
    echo "`/bin/timestamp` Sending SIGHUP to reload syslog-ng" >> $LOG_PATH/dcmscript.log
    killall -HUP syslog-ng
    if [ $? -eq 0 ]; then
        echo "`/bin/timestamp` syslog-ng reloaded successfully" >> $LOG_PATH/dcmscript.log
    fi
fi

cd $USB_DIR

USB_LOG_FILE="$USB_LOG/$LOG_FILE"

echo "`/bin/timestamp` ARCHIVE AND COMPRESS TO $USB_LOG_FILE " >> $LOG_PATH/dcmscript.log
tar -zcvf $USB_LOG_FILE * >> $LOG_PATH/dcmscript.log 2>&1
echo $USB_LOG_FILE

retVal=$?

if [ "$retVal" != "0" ]; then
    echo "`/bin/timestamp` USB WRITING ERROR $retVal" >> $LOG_PATH/dcmscript.log
    sync
    exit 3 # Writing Error
fi

cd $LOG_PATH
rm -r $USB_DIR

# Now sync USB drive, so that everything is flushed out to external USB drive
sync

echo "`/bin/timestamp` COMLETED USB LOG UPLOAD" >> $LOG_PATH/dcmscript.log
/bin/timestamp >> $LOG_PATH/dcmscript.log


exit 0

