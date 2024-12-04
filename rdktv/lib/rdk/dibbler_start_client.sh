#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
#
# Copyright 2021 RDK Management
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
##########################################################################

. /etc/include.properties
. /etc/device.properties
. /lib/rdk/utils.sh
if [ -f  /lib/rdk/getRFC.sh ]; then
    . /lib/rdk/getRFC.sh SLAACSUPPORT
fi
echo "RFC_ENABLE_SLAACSUPPORT:$RFC_ENABLE_SLAACSUPPORT"
RFC_ENABLE_SLAACSUPPORT_L=`echo $RFC_ENABLE_SLAACSUPPORT | tr '[:upper:]' '[:lower:]'`
if [ "x$RFC_ENABLE_SLAACSUPPORT_L" != "xfalse" ]; then
    echo "SLAAC support is enabled WITHOUT RFC Check"
else
    PREFERED_GATEWAY=$(cat /opt/prefered-gateway)
    echo "PREFERED_GATEWAY:$PREFERED_GATEWAY"
    if [ "${PREFERED_GATEWAY:0:2}" != "XB" ]; then
        echo "Prefered gateway is not XB"
    fi
fi

DHCPv6ClientEnabled=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DHCPv6Client.Enable 2>&1 > /dev/null)
echo "DHCPv6ClientEnabled:$DHCPv6ClientEnabled"
if [ "$DHCPv6ClientEnabled" != "true" ]; then
    echo "DHCPv6 client is disabled via RFC"
    exit 0
fi

## Function: removeIfNotLink
DHCP_CONFIG_FILE_TMP="/etc/dibbler/client_back.conf"
DHCP_CONFIG_FILE_RUNTIME="/etc/dibbler/client.conf"
cat $DHCP_CONFIG_FILE_TMP > $DHCP_CONFIG_FILE_RUNTIME
ifce=$ESTB_INTERFACE
if [ -f /tmp/wifi-on ]; then
ifce=$WIFI_INTERFACE
fi
echo "2" > /proc/sys/net/ipv6/conf/$ifce/accept_ra
echo "1" > /proc/sys/net/ipv6/conf/$ifce/accept_ra_defrtr

sysctl -w "net.ipv6.conf.$ifce.accept_ra=2"
sysctl -w "net.ipv6.conf.$ifce.accept_ra_defrtr=1"

sleep 2
sed -i "s/RDK-ESTB-IF/${ifce}/g"  $DHCP_CONFIG_FILE_RUNTIME
/usr/sbin/dibbler-client start
exit $?
