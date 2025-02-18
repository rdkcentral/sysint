#/bin/bash

. /etc/include.properties
. /lib/rdk/utils.sh

LOG_FILE=$LOG_PATH/net_monitor_log.txt

echo "`/bin/timestamp` Action:"$1 >> $LOG_FILE
echo "`/bin/timestamp` Addr_type:"$2 >> $LOG_FILE
echo "`/bin/timestamp` Interface:"$3 >> $LOG_FILE
echo "`/bin/timestamp` Address:"$4 >> $LOG_FILE
echo "`/bin/timestamp` Scope:"$5 >> $LOG_FILE

if [ $1 == "delete" ]; then
    touch /opt/recover_ipv6
    ./netmonitor_recovery.sh &
fi

if [ -f "/opt/recover_ipv6" ] && [ $1 == "add" ]; then
    rm recover_ipv6
fi

