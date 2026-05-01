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

BOOT_TYPE=$(grep "BOOT_TYPE" /tmp/bootType | cut -d '=' -f 2)
RDKV_SUPP_CONF="/opt/secure/wifi/wpa_supplicant.conf"
MIGRATION_JSON="/opt/secure/migration/migration_data_store.json"

if [[ -f "$RDKV_SUPP_CONF" ]]; then
    #########################
    # SSID Extraction #
    #########################
    # Extract the line containing ssid=
    SSID_LINE=$(grep -m 1 "ssid=" "$RDKV_SUPP_CONF")

    # Case 1: SSID is a quoted readable string like ssid="Test's iPhone"
    if [[ "$SSID_LINE" =~ ssid=\"(.*)\" ]]; then
        SSID="${BASH_REMATCH[1]}"
        echo "SSID in quoted format SSID: $SSID"

    # Case 2: SSID is a hex string like ssid=4b61...
    elif [[ "$SSID_LINE" =~ ssid=([a-fA-F0-9]+) ]]; then
        HEX_SSID="${BASH_REMATCH[1]}"

        # Convert hex string to readable UTF-8 string
        # Using printf with \x formatting for each byte pair
        SSID=$(printf "$(echo "$HEX_SSID" | sed 's/../\\x&/g')")
        echo "Converted Hex SSID to string: $SSID"
    fi

    echo "Final SSID: $SSID"

    #########################
    # Passphrase Extraction #
    #########################
    PSK_LINE=$(grep psk= "$RDKV_SUPP_CONF") 
    # Case 1: Quoted passphrase
    if [[ "$PSK_LINE" =~ psk=\"(.+)\" ]]; then
      PSK="${BASH_REMATCH[1]}"
      echo "PSK in quoted format" 

    # Case 2: Unquoted 64-char raw PSK
    elif [[ "$PSK_LINE" =~ psk=([a-fA-F0-9]+) ]]; then
      HEX_PSK="${BASH_REMATCH[1]}"
      PSK=$(printf "$(echo "$HEX_PSK" | sed 's/../\\x&/g')")
      echo "Converted Hex PSK to string"
    fi

    if grep -q "key_mgmt=SAE FT-SAE" "$RDKV_SUPP_CONF"; then
        echo "key_mgmt is SAE"
        KEY_MGMT=sae
    else
        echo "key_mgmt is wpa-psk"
        KEY_MGMT=wpa-psk
    fi

    sed -i '/network={/,/}/d' $RDKV_SUPP_CONF
else
    echo "Config file not found."
fi

if [ -d /opt/NetworkManager ]; then
    rm -rf /opt/NetworkManager/
fi

if [ "$BOOT_TYPE" == "BOOT_MIGRATION" ]; then
    if [ -f $MIGRATION_JSON ]; then
        echo "`/bin/timestamp` :$0: BOOT_TYPE=$BOOT_TYPE... Waiting for IMMUI connect" >>  /opt/logs/NMMonitor.log
        echo "`/bin/timestamp` :$0: Disable Ethernet for Migration" >>  /opt/logs/NMMonitor.log
        nmcli dev set eth0 managed no
        
        if [ -d /opt/secure/NetworkManager/system-connections ]; then
         rm -rf /opt/secure/NetworkManager/system-connections/*
        fi
        nmcli conn reload
        exit 0
    else
        echo "`/bin/timestamp` :$0: BOOT_TYPE=$BOOT_TYPE... But migration data JSON does not exist" >>  /opt/logs/NMMonitor.log
    fi
fi

if [ -z "$SSID" ]; then
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
      if [ -d /opt/secure/NetworkManager/system-connections ]; then
         echo "`/bin/timestamp` :$0: Listing the connection profiles in device: " >>  /opt/logs/NMMonitor.log
         ls -lh /opt/secure/NetworkManager/system-connections >> /opt/logs/NMMonitor.log
         echo "`/bin/timestamp` :$0: Deleting existing wifi profiles if any..." >>  /opt/logs/NMMonitor.log
         for f in /opt/secure/NetworkManager/system-connections/*; do
             if grep -q "type=wifi" "$f"; then
                 rm -f "$f"
             fi
         done
      fi
      if [ -z "$PSK" ]; then
          #connect to wifi
          nmcli conn add type wifi con-name "$SSID" autoconnect yes ifname wlan0 ssid "$SSID"
          nmcli conn reload
      else
          #connect to wifi
          nmcli conn add type wifi con-name "$SSID" autoconnect yes ifname wlan0 ssid "$SSID" wifi-sec.key-mgmt $KEY_MGMT wifi-sec.psk "$PSK"
          nmcli conn reload
      fi
fi
