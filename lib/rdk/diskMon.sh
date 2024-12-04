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

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

#conf filename. The file will have the path and size limit(in MB) seperated by a tab
CONF_FILE=/etc/diskMon.conf 

if [ -f /tmp/.standby ]; then
      LOG=$TEMP_LOG_PATH/diskMon.log
else
      LOG=$LOG_PATH/diskMon.log
fi

echo "`/bin/timestamp` Checking Disk size.." >> $LOG

sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' $CONF_FILE | while read dir limit
do
	# if directory exists, find out it's size
	if [ -d $dir ]
	then
		size=$(du -sm $dir | cut -f1)
	else
		echo "`/bin/timestamp` path $dir not found!!!" >> $LOG
		continue
	fi

	#check if directory size is greater than limit
	if [ $size -ge $limit ]
	then
		echo "`/bin/timestamp` $dir is OVER the limit. size = $size limit = $limit"  >> $LOG
	else
		echo "`/bin/timestamp` $dir is within the limit size = $size limit = $limit" >> $LOG
	fi
        sleep 1
done
echo "" >> $LOG
