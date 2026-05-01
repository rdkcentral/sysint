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

if [ -f "$RDKV_SUPP_CONF" ]; then
#########################
    # SSID Extraction       #
    #########################
    SSID_LINE=$(grep -m 1 '^[[:space:]]*ssid=' "$RDKV_SUPP_CONF")

    case "$SSID_LINE" in
        *ssid=\"*\")
            SSID=$(echo "$SSID_LINE" | sed 's/.*ssid="\(.*\)".*/\1/')
            ;;
        *ssid=[0-9a-fA-F]*)
            HEX_SSID=$(echo "$SSID_LINE" | sed 's/.*ssid=\([0-9a-fA-F]*\).*/\1/')
            HEX_LEN=${#HEX_SSID}
            if [ "$((HEX_LEN % 2))" -ne 0 ] || [ "$HEX_LEN" -eq 0 ]; then
                echo "ERROR: Hex SSID length ($HEX_LEN) is invalid."
                SSID=""
            else
                ESCAPED_HEX=$(echo "$HEX_SSID" | sed 's/../\\x&/g')
                SSID=$(printf '%b' "$ESCAPED_HEX")
            fi
            ;;
    esac

    #########################
    # Passphrase Extraction #
    #########################
    PSK_LINE=$(grep -m 1 '^[[:space:]]*psk=' "$RDKV_SUPP_CONF")

    case "$PSK_LINE" in
        *psk=\"*\")
            PSK=$(echo "$PSK_LINE" | sed 's/.*psk="\(.*\)".*/\1/')
            ;;
        *psk=[0-9a-fA-F]*)
            HEX_PSK=$(echo "$PSK_LINE" | sed 's/.*psk=\([0-9a-fA-F]*\).*/\1/')
            if [ "$((${#HEX_PSK} % 2))" -ne 0 ]; then
                echo "ERROR: Hex PSK length is invalid."
                PSK=""
            else
                ESCAPED_PSK=$(echo "$HEX_PSK" | sed 's/../\\x&/g')
                PSK=$(printf '%b' "$ESCAPED_PSK")
            fi
            ;;
    esac

    #########################
    # Key_Mgmt Extraction   #
    #########################
    if grep -q "key_mgmt=.*SAE" "$RDKV_SUPP_CONF"; then
        echo "key_mgmt is SAE"
        KEY_MGMT=sae
    else
        echo "key_mgmt is wpa-psk"
        KEY_MGMT=wpa-psk
    fi

    sed -i '/network={/,/}/d' "$RDKV_SUPP_CONF"
else
    echo "Config file not found."
fi



if [ "$BOOT_TYPE" == "BOOT_MIGRATION" ]; then
    if [ -f $MIGRATION_JSON ]; then
        echo "`/bin/timestamp` :$0: BOOT_TYPE=$BOOT_TYPE... Waiting for IMMUI connect" >>  /opt/logs/NMMonitor.log
        echo "`/bin/timestamp` :$0: Disable Ethernet for Migration" >>  /opt/logs/NMMonitor.log
        nmcli dev set eth0 managed no

        if [ -d /opt/NetworkManager ]; then
         rm -rf /opt/NetworkManager/
        fi
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
          nmcli conn add type wifi con-name "$SSID" autoconnect yes ifname wlan0 ssid "$SSID" wifi-sec.key-mgmt "$KEY_MGMT" wifi-sec.psk "$PSK"
          nmcli conn reload
      fi
fi
