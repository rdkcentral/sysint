#!/bin/sh
LOGFILE="/opt/logs/chrony_telemetry.log"

timestamp=$(date "+%Y-%m-%d %H:%M:%S")

{
echo "$timestamp chrony telemetry:"
chronyc tracking
echo ""
} >> "$LOGFILE"
