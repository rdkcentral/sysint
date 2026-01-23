#!/bin/sh

. /etc/include.properties
. /etc/device.properties
. $RDK_PATH/utils.sh

bluetooth_mac="00:00:00:00:00:00"
if [ "$BLUETOOTH_ENABLED" = "true" ]; then
    bluetooth_mac=$(getDeviceBluetoothMac)
fi
