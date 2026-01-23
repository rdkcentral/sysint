#!/bin/sh

. /etc/include.properties
. /etc/device.properties
. $RDK_PATH/utils.sh

if [ "$BLUETOOTH_ENABLED" = "true" ]; then
    bluetooth_mac=$(getDeviceBluetoothMac)
fi
