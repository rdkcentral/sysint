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

WIFI_WPA_SUPPLICANT_CONF="/nvram/secure/wifi/wpa_supplicant.conf"

if [ -f $WIFI_WPA_SUPPLICANT_CONF ]; then
  SSID=$(cat $WIFI_WPA_SUPPLICANT_CONF | grep -w ssid= | cut -d '"' -f 2)
  PSK=$(cat $WIFI_WPA_SUPPLICANT_CONF | grep -w psk= | cut -d '"' -f 2)

  ETH_STATUS=$(nmcli dev status | grep -w eth0)
  IS_ETH_CONN=$(echo $ETH_STATUS | grep -w connected)

  if [ -z "${IS_ETH_CONN}" ]; then
         if [ -z "$( ls -A '/opt/NetworkManager/system-connections' )" ]; then
            if [ -z $PSK ]; then
                #connect to wifi
                nmcli conn add type wifi con-name $SSID autoconnect yes ifname wlan0 ssid $SSID
                nmcli conn reload
            else
                #connect to wifi
                nmcli conn add type wifi con-name $SSID autoconnect yes ifname wlan0 ssid $SSID wifi-sec.key-mgmt wpa-psk wifi-sec.psk $PSK
                nmcli conn reload
            fi
         elif [ -z $(grep "interface-name" /opt/NetworkManager/system-connections/*.nmconnection) ]; then
            rm -rf /opt/NetworkManager/system-connections/*.nmconnection
            if [ -z $PSK ]; then
                #connect to wifi
                nmcli conn add type wifi con-name $SSID autoconnect yes ifname wlan0 ssid $SSID
                nmcli conn reload
            else
                #connect to wifi
                nmcli conn add type wifi con-name $SSID autoconnect yes ifname wlan0 ssid $SSID wifi-sec.key-mgmt wpa-psk wifi-sec.psk $PSK
                nmcli conn reload
            fi
         fi
  fi
fi
rm -f /nvram/secure/wifi/wpa_supplicant.conf
rm -f /opt/secure/wifi/wpa_supplicant.conf
rm -f /var/lib/secure/wifi/wpa_supplicant.conf
