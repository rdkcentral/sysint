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
. /etc/include.properties

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib:/usr/lib:/usr/local/lib

DS_MGR_PATH="/usr/local/bin"
IARM_BIN_PATH="/mnt/nfs/env"
DS_PERSISTENT_PATH="$APP_PERSISTENT_PATH/ds/"

if [ ! -d /dev/shm ]; then mkdir -p /dev/shm; fi

if [ ! -d $DS_PERSISTENT_PATH ]; then
     echo "The DS Host Persistent folder is missing"
     mkdir -p $DS_PERSISTENT_PATH
fi

cd $IARM_BIN_PATH
echo "`/bin/timestamp` -------IARM Managers are coming up -----"
#/dump /version.txt
if [ -f ./IARMDaemonMain ]; then
     ./IARMDaemonMain &
fi
sleep 1
echo ----------- dsMgrMain coming up ------------
if [ -f ./dsMgrMain ]; then
     ./dsMgrMain &
fi
sleep 1
echo ----------- irMgrMain coming up ------------
if [ -f ./irMgrMain ]; then
     ./irMgrMain &
fi
sleep 1
echo ----------- pwrMgrMain coming up ------------
if [ -f ./pwrMgrMain ]; then
     ./pwrMgrMain &
fi
sleep 1
echo ----------- SysMgrMain coming up ------------
if [ -f ./sysMgrMain ]; then
     ./sysMgrMain &
fi
touch /tmp/.IarmBusMngrFlag
