#!/bin/sh

echo "NTP EVENT RECEIVED"
LOG_FILE="/tmp/ntp-status-latest.log"

leap=$(grep "leap" "$LOG_FILE" | awk '{print $3}')
version=$(grep "version" "$LOG_FILE" | awk '{print $3}')
mode=$(grep "mode" "$LOG_FILE" | awk '{print $3}')
stratum=$(grep "stratum" "$LOG_FILE" | awk '{print $3}')
precision=$(grep "precision" "$LOG_FILE" | awk '{print $3}')
precision_val=$(grep "precision" "$LOG_FILE" | awk '{print $5}' | tr -d '()')
root_distance=$(grep "root distance" "$LOG_FILE" | awk '{print $4}')
reference=$(grep "reference" "$LOG_FILE" | awk '{print $3}')
origin=$(grep "origin" "$LOG_FILE" | awk '{print $3}')
receive=$(grep "receive" "$LOG_FILE" | awk '{print $3}')
transmit=$(grep "transmit" "$LOG_FILE" | awk '{print $3}')
dest=$(grep "dest" "$LOG_FILE" | awk '{print $3}')
offset=$(grep "offset" "$LOG_FILE" | awk '{print $3}')
delay=$(grep "delay" "$LOG_FILE" | awk '{print $3}')
packet_count=$(grep "packet count" "$LOG_FILE" | awk '{print $4}')
jitter=$(grep "jitter" "$LOG_FILE" | awk '{print $3}')
poll_interval=$(grep "poll interval" "$LOG_FILE" | awk '{print $3}')

echo "INTERVAL: $poll_interval,OFFSET:$offset"
