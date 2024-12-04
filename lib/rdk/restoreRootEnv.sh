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

USER_ID=0
USER_GROUP=0

if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

if [ -f /etc/os-release ]; then
    exit 0
fi

if [ -d /opt/restricted ]; then
    rm -rf /opt/restricted
fi

if [ -d /tmp ]; then
    chown -R $USER_ID:$USER_GROUP /tmp
fi

if [ -d /dev ]; then
    chown -Rh $USER_ID:$USER_GROUP /dev
fi

if [ -d /var/logs ]; then
    chown -R $USER_ID:$USER_GROUP /var/logs
fi

if [ -f /opt/logs/receiver.log ]; then
   chown $USER_ID:$USER_GROUP /opt/logs/receiver.log
fi

chown $USER_ID:$USER_GROUP /dev/fusion*
chown $USER_ID:$USER_GROUP /tmp/fusion.*
chown $USER_ID:$USER_GROUP /opt/xupnp/
chown -R $USER_ID:$USER_GROUP /opt
chown $USER_ID:$USER_GROUP $CORE_PATH
chown $USER_ID:$USER_GROUP $MINIDUMPS_PATH
chown $USER_ID:$USER_GROUP /dev/avcap_core
chown $USER_ID:$USER_GROUP /var/logs/pipe_receiver
chown $USER_ID:$USER_GROUP /tmp/csmedia_msr*
chown $USER_ID:$USER_GROUP /tmp/video1_msr*
chown $USER_ID:$USER_GROUP /version.txt
chown $USER_ID:$USER_GROUP /SetEnv.sh
                                           
