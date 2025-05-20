#!/bin/sh
NTP_LOG_FILE="/tmp/fall_back_time"

source=$(grep '^SOURCE=' "$NTP_LOG_FILE" | cut -d'=' -f2- )
echo "Source: $source"
Time=$(grep "^TIME=" "$NTP_LOG_FILE" | cut -d'=' -f2- )
echo "Time: $Time"
