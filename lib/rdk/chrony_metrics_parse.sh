#!/bin/sh

line=$(tail -1 /opt/logs/chrony/tracking.log)
LOG_FILE=/opt/logs/tracking-telemetry
logger()
{
 echo "`/bin/timestamp` : $0: $*" >> $LOG_FILE
}
date=$(echo "$line" | awk '{print $1}')
time=$(echo "$line" | awk '{print $2}')
offset=$(echo "$line" | awk '{print $7}')
drift=$(echo "$line" | awk '{print $5}')
delay=$(echo "$line" | awk '{print $11}')
jitter=$(echo "$line" | awk '{print $9}')

logger "NTP response:"
logger "  response time : ${date} ${time}"
logger "  offset        : ${offset} sec"
logger "  drift         : ${drift} ppm"
logger "  delay         : ${delay} sec"
logger "  jitter        : ${jitter} sec"
