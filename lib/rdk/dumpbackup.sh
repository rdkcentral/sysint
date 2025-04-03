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
. /etc/config.properties
. /etc/device.properties
if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

start_function() {
    ulimit -c 1024000000
    if [ ! -d $CORE_PATH ]; then mkdir -p $CORE_PATH; fi
    if [ ! -d $MINIDUMPS_PATH ]; then mkdir -p $MINIDUMPS_PATH; fi

    if [ -f $RDK_PATH/core_shell.sh ]; then
	echo "|$RDK_PATH/core_shell.sh %e %s %t %p %i" >/proc/sys/kernel/core_pattern
    fi

    TS=`date +%Y-%m-%d-%H-%M-%S`
    # Randomize upload delay for PROD
    if [ "$BUILD_TYPE" = "prod" ]; then
        delay=$((400 + $RANDOM % 600))
    else
        delay=400
    fi
}

stop_function() {
    sh /lib/rdk/processPID.sh /lib/rdk/uploadDumps.sh | xargs kill -9
}

case "$1" in
  start)
    start_function
    ;;
  stop)
    stop_function
    ;;
  restart)
    $0 stop && $0 start
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
  ;;
esac
