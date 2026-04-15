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

log_file="$LOG_PATH/unified-logging.txt"
help_strings()
{
    echo "`/bin/timestamp` ERROR: Argument mismatch" | systemd-cat -t cronjobs_update
    echo "`/bin/timestamp` Usage1: cronjobs_update.sh <add/update> <script-name> <new-entry>" | systemd-cat -t cronjobs_update
    echo "`/bin/timestamp` Usage2: cronjobs_update.sh <remove/check-entry> <script-name>" | systemd-cat -t cronjobs_update
}

#No argument check
if [ $# -eq 0 ]; then
    help_strings
    exit 1
fi
#remove/check-entry operation check
if [ $# -ne 2 ] && [ "$1" = "remove" -o "$1" = "check-entry" ]; then
    help_strings
    exit 1
fi
#add/update operation check
if [ $# -ne 3 ] && [ "$1" = "add" -o "$1" = "update" ]; then
    help_strings
    exit 1
fi

LOCK="/tmp/.cronjob.LCK"
exec 8>$LOCK
flock -x 8

remove()
{
    sed -i "/[A-Za-z0-9]*$1[A-Za-z0-9]*/d" $current_cron_file
}

add()
{
    echo "$1" >> $current_cron_file
}

check_entry()
{
    output=`grep -c "$1" $current_cron_file`
    echo "`/bin/timestamp` output=$output" | systemd-cat -t cronjobs_update
    echo $output
}


#main app
# Start crond daemon for yocto builds if not running
if [ -f /etc/os-release ]; then
    touch /var/spool/cron/root
    pid=`pidof crond`
    echo "`/bin/timestamp` crond pid: $pid" | systemd-cat -t cronjobs_update
    if [ -z $pid ]; then
        crond -b -L /dev/null -c /var/spool/cron/
    fi
fi


current_cron_file="/tmp/cron_list"
crontab -l -c /var/spool/cron/ > $current_cron_file

echo "`/bin/timestamp` :Arguments - 1st:$1, 2nd:$2, 3rd:$3" | systemd-cat -t cronjobs_update
if [ "$1" = "remove" ]; then
    echo "`/bin/timestamp` REMOVE" | systemd-cat -t cronjobs_update
    remove "$2"
fi

if [ "$1" = "add" ]; then
    echo "`/bin/timestamp` ADD" | systemd-cat -t cronjobs_update
    add "$3"
fi

if [ "$1" = "update" ]; then
    echo "`/bin/timestamp` UPDATE" | systemd-cat -t cronjobs_update
    remove "$2"
    add "$3"
fi

if [ "$1" = "check-entry" ]; then
    echo "`/bin/timestamp` ENTRY_CHECK" | systemd-cat -t cronjobs_update
    check_entry "$2"
fi


# update the new cron entries to root cron
crontab $current_cron_file -c /var/spool/cron/

# add flock -u to unlock the file descriptor before removing the file
flock -u 8
# do not remove the file as this can cause race conditions
# rm -rf /tmp/.cronjob.LCK
echo "`/bin/timestamp` Exiting cronjobs_update.sh" | systemd-cat -t cronjobs_update
exit 0

