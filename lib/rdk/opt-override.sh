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

. /etc/device.properties

if [ -f /opt/rmfconfig.ini ]  && [ "$BUILD_TYPE" != "prod" ]; then
   RMFCONFIGINIFILE=/opt/rmfconfig.ini
else
   RMFCONFIGINIFILE=/etc/rmfconfig.ini
fi

if [ -f /opt/debug.ini ]  && [ "$BUILD_TYPE" != "prod" ]; then
   DEBUGINIFILE=/opt/debug.ini
else
   DEBUGINIFILE=/etc/debug.ini
fi

if [ -f /opt/netsrvmgr.conf ]  && [ "$BUILD_TYPE" != "prod" ]; then
   NETSRVMGRINIFILE=/opt/netsrvmgr.conf
else
   NETSRVMGRINIFILE=/etc/netsrvmgr.conf
fi

if [ -f /opt/notify_webpa_cfg.json ]  && [ "$BUILD_TYPE" != "prod" ]; then
   WEBPANOTIFYINCFG=/opt/notify_webpa_cfg.json
else
   WEBPANOTIFYINCFG=/etc/notify_webpa_cfg.json
fi

/bin/systemctl set-environment RMFCONFIGINIFILE=$RMFCONFIGINIFILE
/bin/systemctl set-environment DEBUGINIFILE=$DEBUGINIFILE
/bin/systemctl set-environment NETSRVMGRINIFILE=$NETSRVMGRINIFILE
/bin/systemctl set-environment WEBPANOTIFYINCFG=$WEBPANOTIFYINCFG
