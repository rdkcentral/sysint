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

### BEGIN INIT INFO
# Provides:          dump-backup-service
# Should-Start: 
# Required-Start:    cron-service
# Required-Stop:
# Default-Start:     3
# Default-Stop:
# Short-Description: 
### END INIT INFO
. /lib/rdk/init-functions

# Defaults can be overridden in this file
INIT_SCRIPT_DEFAULTS_FILE="/etc/include.properties"

# Load alternate configuration if exists
if [ -f $INIT_SCRIPT_DEFAULTS_FILE ]; then
     . $INIT_SCRIPT_DEFAULTS_FILE
fi

# Defaults
INIT_SCRIPT_NAME="COREDUMP-UPLOAD"                  # full path to the executable
INIT_SCRIPT_EXECUTABLE=""                           # options to pass to the executable 
INIT_SCRIPT_OPTIONS=""                              # a decriptive name 
INIT_SCRIPT_HOMEDIR="/"                             # place where to cd before running
INIT_SCRIPT_PIDFILE=""                              # pid file name
INIT_SCRIPT_LOGFILE="applications.log"              # log file name 
INIT_SLEEPTIME=""                                   # how long to wait for startup and shutdown

. /etc/config.properties
. /etc/device.properties
if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

start_function() {
	pre_start "$INIT_SCRIPT_LOGFILE" ">>"
	ulimit -c 1024000000
	if [ ! -d $CORE_PATH ]; then mkdir -p $CORE_PATH; fi
	if [ ! -d $MINIDUMPS_PATH ]; then mkdir -p $MINIDUMPS_PATH; fi


	if [ "$DEFAULT_CRASH_PATTERN" = "true" ]; then
		if [ "$BUILD_TYPE" != "prod" ] && [ "$BUILD_TYPE" != "vbn" ]; then
			if [ ! -f /etc/os-release ]; then
				echo "$CORE_PATH/%t_core.prog_%e.signal_%s" > /proc/sys/kernel/core_pattern
			else
				echo "$CORE_PATH/%t_core.prog_%e.signal_%s" > /proc/sys/kernel/core_pattern
			fi
		else
			if [ ! -f /etc/os-release ]; then
				echo "$CORE_PATH/core.prog_%e.signal_%s" > /proc/sys/kernel/core_pattern
			else
				echo "$CORE_PATH/core.prog_%e.signal_%s" > /proc/sys/kernel/core_pattern
                                echo "0" > /proc/sys/kernel/core_uses_pid
			fi
		fi
	else
		if [ "$DEVICE_TYPE" != "mediaclient" ]; then
			echo 1 > /opt/.uploadMpeosCores
			export uploadMpeosCores=1
		fi
		if [ -f $RDK_PATH/core_shell.sh ]; then
			echo "|$RDK_PATH/core_shell.sh %e %s %t" >/proc/sys/kernel/core_pattern
		fi
	fi

    TS=`date +%Y-%m-%d-%H-%M-%S`


    # Randomize upload delay for PROD
    if [ "$BUILD_TYPE" = "prod" ]; then
        delay=$((400 + $RANDOM % 600))
    else
        delay=400
    fi
    #core+mini dumps to Potomac's machine
    # Coredump Upload call
    if [ "$BUILD_TYPE" = "dev" ]; then
        nice sh -c "sleep $delay; $RDK_PATH/uploadDumps.sh ${TS} 1 " &
        nice sh -c "sleep $delay; $RDK_PATH/uploadDumps.sh ${TS} 0 " &
    else
        nice sh -c "sleep $delay; $RDK_PATH/uploadDumps.sh ${TS} 1 $POTOMAC_SVR" &
        nice sh -c "sleep $delay; $RDK_PATH/uploadDumps.sh ${TS} 0 $POTOMAC_SVR" &
    fi
    post_start $?
}

stop_function() {
    pre_stop
    sh /lib/rdk/processPID.sh /lib/rdk/uploadDumps.sh | xargs kill -9
    post_stop 0
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
