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

RDK_PROFILE=$(grep "RDK_PROFILE" /etc/device.properties | cut -d '=' -f 2)
RDKV_SUPP_CONF="/opt/secure/wifi/wpa_supplicant.conf"


if [ -f $RDKV_SUPP_CONF ]; then
  SSID=$(cat $RDKV_SUPP_CONF | grep -w ssid= | cut -d '"' -f 2)
  PSK_LINE=$(grep psk= "$RDKV_SUPP_CONF")

  # Case 1: Quoted passphrase
  if [[ "$PSK_LINE" =~ psk=\"(.+)\" ]]; then
    PSK="${BASH_REMATCH[1]}"

  # Case 2: Unquoted 64-char raw PSK
  elif [[ "$PSK_LINE" =~ psk=([a-fA-F0-9]{64}) ]]; then
    PSK="${BASH_REMATCH[1]}"

  # No match
  else
    PSK=""
  fi
  sed -i '/network={/,/}/d' /opt/secure/wifi/wpa_supplicant.conf
fi

if [ -z $SSID ]; then
      echo "`/bin/timestamp` :$0: No SSID found in supplicant conf" >>  /opt/logs/NMMonitor.log
      echo "`/bin/timestamp` :$0: Trying with previously configured settings" >>  /opt/logs/NMMonitor.log
      if [ ! -d /opt/secure/NetworkManager/system-connections ]; then
         mkdir -p /opt/secure/NetworkManager/system-connections
      fi
      if [ -d /opt/NetworkManager/system-connections ]; then
         cp /opt/NetworkManager/system-connections/* /opt/secure/NetworkManager/system-connections/
         rm -rf /opt/NetworkManager/system-connections/*
      fi
      nmcli conn reload
else
      if [ -d /opt/NetworkManager/system-connections ]; then
         rm -rf /opt/NetworkManager/system-connections/*
      fi
      if [ "$RDK_PROFILE" == "TV" ]; then
        echo "`/bin/timestamp` :$0: Not migrating Wifi credentials for TVs from NM_Bootsrtap" >>  /opt/logs/NMMonitor.log
        if [ -d /opt/secure/NetworkManager/system-connections ]; then
           rm -rf /opt/secure/NetworkManager/system-connections/*
        fi
        exit  0
      fi
      if [ -z $PSK ]; then
          #connect to wifi
          nmcli conn add type wifi con-name "$SSID" autoconnect yes ifname wlan0 ssid "$SSID"
          nmcli conn reload
      else
          #connect to wifi
          nmcli conn add type wifi con-name "$SSID" autoconnect yes ifname wlan0 ssid "$SSID" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PSK"
          nmcli conn reload
      fi
fi
