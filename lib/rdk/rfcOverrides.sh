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


# override DIFW path if RFC desires downloads to sd card
SDCARD_SCRATCHPAD_ENABLE=`/usr/bin/tr181Set -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.SDCARD_SCRATCHPAD.Enable 2>&1 > /dev/null`

if [ "x$SDCARD_SCRATCHPAD_ENABLE" == "xtrue" ]; then
    # make sure that we have a rw filesystem mounted on 
    # cdl mount path
    tst_file=$SD_CARD_APP_MOUNT_PATH/testfile
    touch $tst_file
    if [ -e $tst_file ]; then
        echo "secondary storage scratchpad will be used for firmware download"
        DIFW_PATH=$SD_CARD_APP_MOUNT_PATH
        rm $tst_file
    fi
fi

