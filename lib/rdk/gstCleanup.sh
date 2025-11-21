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

CDLFILE=`cat /opt/cdl_flashed_file_name`
PREV_CDLFILE=`cat /opt/previous_flashed_file_name`


if [[ ! -f /opt/previous_flashed_file_name || ! -f /opt/cdl_flashed_file_name ]]; then
    echo "Likely FSR done don't remove gstreamer registry, if still present"
    if [ ! -f /opt/.gstreamer/registry.bin ]; then
        echo "Gstreamer registry empty after FSR, clear /opt/.gstreamer"
        rm -rf /opt/.gstreamer
        GST_REGISTRY_UPDATE=yes gst-inspect-1.0 >/dev/null 2>&1
    fi
elif [ ! -f /opt/.gstreamer/registry.bin ] || [[ ${CDLFILE} != *"${PREV_CDLFILE}"* ]]; then
    echo "Removing gstreamer registry on bootup after CDL"
    rm -rf /opt/.gstreamer
    GST_REGISTRY_UPDATE=yes gst-inspect-1.0 >/dev/null 2>&1
else
    echo "gstreamer registry is not removed, previous reboot is not due to CDL"
fi
