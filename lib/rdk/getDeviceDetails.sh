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

# Purpose: This script is used to fetch device information such as MAC address, IP address, and model.
# Scope: RDK devices.
# Usage: This script is triggered by a systemd service and shell scripts.

# input arguments
command=$1
parameter=$2
logEnabled=$3

# internal variables
logFile="/opt/logs/getDeviceDetails.$$.log"
lockDir=/tmp/.getDeviceDetails.lock
lockPidFile=/tmp/.getDeviceDetails.lock/.lockPidFile
deviceDetailsCache=/tmp/.deviceDetails.cache

# to enable logging: uncomment out echo and comment out colon :
logMsg()
{
	#echo "$(cat /proc/uptime | awk '{print $1}'): $0: $$: $(ps -o comm= $PPID): $PPID :: $1" >> $logFile
	:
}

logMsg "enter"

. /etc/include.properties
. /etc/device.properties
. $RDK_PATH/utils.sh


if [ "$DEVICE_TYPE" != "mediaclient" ]; then
    export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
    export MIBS=ALL
    export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
    export PATH=$PATH:$SNMP_BIN_DIR:
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
    snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
fi

# get box IP address
# This function will be invoked for non-mediaclients and for the devices with WiFI Support
getBoxIPAddress()
{
    if [ "$WIFI_SUPPORT" == "true" ] && [ -f /tmp/wifi-on ]; then
        if [ -f /tmp/.ipv6$WIFI_INTERFACE ]; then
            IPAddress=`cat /tmp/.ipv6$WIFI_INTERFACE`
        elif [ -f /tmp/.ipv4$WIFI_INTERFACE ]; then
            IPAddress=`cat /tmp/.ipv4$WIFI_INTERFACE`
        else
            IPAddress=""
        fi
    else
        if [ -f /tmp/.ipv6$ESTB_INTERFACE ]; then
            IPAddress=`cat /tmp/.ipv6$ESTB_INTERFACE`
        elif [ -f /tmp/.ipv4$ESTB_INTERFACE ]; then
            IPAddress=`cat /tmp/.ipv4$ESTB_INTERFACE`
        else
            IPAddress=""
        fi
    fi
}

getEcmIp()
{
  ecmIp=""
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  if [ "$DEVICE_TYPE" != "mediaclient" ]; then
       addr_type=`snmpget -OQv -v 2c -c "$snmpCommunityVal" 192.168.100.1 .1.3.6.1.2.1.69.1.4.6.0`
       if [ "$addr_type" == "ipv6" ]; then
            MAX_FIELD_SEPARATOR_COUNT=7
            ecmIp=`snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 192.168.100.1 IP-MIB::ipAddressOrigin.ipv6 | grep dhcp | cut -d "\"" -f2`
            fieldSeparatorCount=`echo $ecmIp | tr -dc ':' | wc -c`
            if [ $fieldSeparatorCount -gt $MAX_FIELD_SEPARATOR_COUNT ]; then
               # Format IPV6 address in 2 octet format to standard format
               ecmIp=`echo $ecmIp | sed -e 's/://g' -e 's/..../&:/g' -e 's/:$//'`
            fi
       else
            ecmIp=`snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 192.168.100.1 IP-MIB::ipAdEntAddr | grep -v '127.0.0.1\|192.168\|10.10.10.1' | cut -d "=" -f2 | sed 's/[ /t]*//'`
       fi
  fi
  ecmIp=`echo $ecmIp | sed  "s/ //g"`
  # Validating ECM IP address
  validIPV4IP=`echo $ecmIp | egrep "^([0-9]{1,3}.){3}[0-9]{1,3}$"`
  validIPV6IP=`echo $ecmIp | egrep "^([0-9A-Fa-f]{0,4}:){1,7}[0-9A-Fa-f]{0,4}$"`
  invalidIP=`echo $ecmIp | egrep "^([0]{1,3}.){3}[0]{1,3}$"`
  if [ "$validIPV4IP" != "" ] && [ "$invalidIP" == "" ] || [ "$validIPV6IP" != "" ]; then
       [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Got ecmIp : $ecmIp"
  else
       ecmIp=""
  fi
}

getEcmMac()
{
  EcmMac=""
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  if [ "$DEVICE_TYPE" != "mediaclient" ]; then
      EcmMac=`snmpwalk -O0x -m IF-MIB -v 2c -c "$snmpCommunityVal" 192.168.100.1 IF-MIB::ifPhysAddress.2 | cut -d "=" -f2 | sed 's/[ /t]*//'|cut -d " " -f2`
      EcmMac=`echo $EcmMac | sed  "s/ //g"`
      validMac=`echo $EcmMac | egrep "^([0-9A-Fa-f]{1,2}:){5}[0-9A-Fa-f]{1,2}$"`
      invalidMac=`echo $EcmMac | egrep "^([0]{1,2}:){5}[0]{1,2}$"`
      if [ "$validMac" == "" ] || [ "$invalidMac" != "" ]; then
          EcmMac=""
      else
          [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Got EcmMac : $EcmMac"
      fi
  fi
}

getEthernetMacAddress()
{
    EtherMac=$(ifconfig $ETHERNET_INTERFACE  | awk '/HWaddr/ {print $5}')
}

getMocaMac()
{
    MocaMac=$(ifconfig $MOCA_INTERFACE | awk '/HWaddr/ {print $5}')
}

getWiFiMac()
{
    # Get the wifi mac only if WIFI_INTERFACE is defined
    if [ "x$WIFI_INTERFACE" != "x" ]; then
        WiFiMac=$(ifconfig $WIFI_INTERFACE | awk '/HWaddr/ {print $5}')
    fi
}

getMocaIp()
{
    MocaIp=""
    
    if [ "$MOCA_INTERFACE" != "" ]; then
        if [ -f /tmp/.ipv6$MOCA_INTERFACE ]; then
            MocaIp=$(cat /tmp/.ipv6$MOCA_INTERFACE)
        elif [ -f /tmp/.ipv4$MOCA_INTERFACE ]; then
            MocaIp=$(cat /tmp/.ipv4$MOCA_INTERFACE)
        else
            MocaIp=""
        fi
   fi
}

getLocalTime()
{
   timeValue=$(date)
   echo "$timeValue"
}

getTimeZone()
{
  zoneValue=""
  if [ -f /opt/etc/saved_timezone ]; then
       zoneValue=$(cat /opt/etc/saved_timezone | cut -d "=" -f2 | cut -d "," -f1)
  fi
  echo "$zoneValue"
}

getFWVersion()
{
  Version=$(cat /version.txt | grep ^imagename: | cut -d ":" -f 2)
}
getDACInitTimestamp()
{
   if [ "$DEVICE_TYPE" != "mediaclient" ]; then
       if [ -f /opt/mpeos_hrv_init_log.txt ]; then
           head -n 1 /opt/mpeos_hrv_init_log.txt | cut -d',' -f1
       fi
   fi
}

getCableCardVersion()
{
  CableCardVersion=""
  if [ "$DEVICE_TYPE" != "mediaclient" ]; then
    snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
    CableCardVersion=`snmpget -OQv -v 2c -c "$snmpCommunityVal" localhost OC-STB-HOST-MIB::ocStbHostCardVersion.0| cut -d "\"" -f2 | tr -d " "`
    CableCardVersion=`echo $CableCardVersion | sed  "s/ //g"`
    if [[ $? -ne 0 ]] || [[ "$CableCardVersion" == *"NoSuchObjectavailableonthisagentatthisOID"* ]] || [[ "$CableCardVersion" == *"NoInfoAvailable"* ]] || [[ "$CableCardVersion" == "" ]]; then
        CableCardVersion=""
    else
        [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Got CableCardVersion : $CableCardVersion"
    fi
  fi
}

# identifies whether it is a VBN or PROD build
getBuildType()
{
   echo $BUILD_TYPE |tr '[:lower:]' '[:upper:]'
}

getModelNum()
{
   echo $MODEL_NUM
}

getManufacturer(){
           output=$(mfr_util --Manufacturer 2>&1)
           if [ -n "$output" ] && ! echo "$output" | grep -iq "failed"; then
               output=$(echo $output | sed 's/ /_/g')
               echo "$output" | safeWrite /tmp/.manufacturer
               echo "$output"
	   else
               echo "UNKNOWN"
           fi
}

getBrandName(){
            output=$(mfr_util --Manufacturer 2>&1)
            if [ -n "$output" ] && ! echo "$output" | grep -iq "failed"; then
                echo "$output" | safeWrite /tmp/.brandname
            fi
}

getDeviceType()
{
   echo $DEVICE_TYPE
}

getFriendlyId()
{
   echo $FRIENDLY_ID
}

getModel()
{
   model=""
   modelFile="/opt/persistent/.model"
   if [ "$DEVICE_TYPE" != "mediaclient" ]; then
      snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
      model=`snmpget -Os -v 2c -c "$snmpCommunityVal" 192.168.100.1 sysDescr.0 | cut -d ":" -f7 | cut -d " " -f2 | sed 's/[>"]//g'`
      model=`echo $model | sed  "s/ //g"`
      [ $? -ne 0 ] && model=""
      [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Got model : $model"
      [[ "$model" != "$MODEL_NUM"* ]] && model=""
      [ "$model" == "$MODEL_NUM" ] && model=""

      if [ "$model" != "" ]; then
          if [ -f $modelFile ] && [ "$model" != "`cat $modelFile`" ] || [ ! -f $modelFile ]; then
              echo "$model" > $modelFile
          fi
      elif [ -f $modelFile ]; then
           model=`cat $modelFile`
      fi

   fi
}

getDeviceSerialNumber()
{
   serialNumber=""
   if [ "$DEVICE_TYPE" != "mediaclient" ]; then
      snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
      serialNumber=`snmpwalk -Oqv -v 2c -c "$snmpCommunityVal" 127.0.0.1 ocStbHostSerialNumber`
      [ $? -ne 0 ] && serialNumber=""
      serialNumber=`echo $serialNumber | sed  "s/ //g"`
      [ "$logEnabled" == "true" ] && [ "$serialNumber" != "" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Got serialNumber : $serialNumber"
   fi
}

getBluetoothMac()
{
    bluetooth_mac="00:00:00:00:00:00"
    if [ -f /lib/rdk/readBTAddress-vendor.sh ]; then
        bluetooth_mac=`sh /lib/rdk/readBTAddress-vendor.sh`
    else
        bluetooth_mac=`sh /lib/rdk/readBTAddress-generic.sh`
    fi

    echo "$bluetooth_mac"
}

getRF4CEMac()
{
    rf4ce_mac="00:00:00:00:00:00:00:00"
    if [ "$RF4CE_CAPABLE" = "true" ]; then
        if [ "$DEVICE_TYPE" != "mediaclient" ]; then
            snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
            rf4ce_mac=`snmpwalk -OQ -v 2c -c "$snmpCommunityVal"  localhost 1.3.6.1.4.1.17270.9225.2.1.9.1.2 | cut -d "=" -f2 |tr -d " " | tr -d \" | cut -c 3- | sed 's/\(..\)/\1:/g;s/:$//'`
        else
           rf4ce_mac=`curl -d '{"paramList" : [{"name" : "Device.Services.STBService.1.Components.X_RDKCENTRAL-COM_RF4CE.rf4ceMACAddress"}]}' http://127.0.0.1:10999 | cut -d ":" -f4 | cut -d "\"" -f2 | tr -d " " | tr -d \" | cut -c 3- | sed 's/\(..\)/\1:/g;s/:$//'`
        fi
    fi
    rf4ce_mac=$(echo $rf4ce_mac | tr 'a-z' 'A-Z' )
    if [ `echo $rf4ce_mac | egrep "^([0-9A-F]{2}:){7}[0-9A-F]{2}$"` ]
    then
        echo "$rf4ce_mac"
    fi
}


# Write stdin to a /tmp file atomically: build a fresh mktemp file (O_EXCL,
# root-owned) and rename it over the target. rename() replaces a symlink
# instead of following it, and readers never see a missing/partial file.
safeWrite()
{
    file="$1"
    [ -d "$file" ] && return 1
    sw_tmp=$(mktemp "${file}.XXXXXX") || return 1
    if cat > "$sw_tmp" && chmod 644 "$sw_tmp" && mv -f "$sw_tmp" "$file"; then
        return 0
    fi
    rm -f "$sw_tmp"
    logMsg "Error: unable to securely write $file"
    return 1
}

executeServiceRequest()
{
   logMsg "exec service = $1"
   if [ "$1" != "all" ]; then
        lock
   fi

   case "$1" in
      "all")
		executeServiceRequest "estb_mac"
		executeServiceRequest "moca_mac"
		executeServiceRequest "wifi_mac"
		executeServiceRequest "eth_mac"
		executeServiceRequest "model_number"
		executeServiceRequest "manufacturer"
		executeServiceRequest "brandname"
		executeServiceRequest "device_type"
		executeServiceRequest "friendly_id"
		executeServiceRequest "build_type"
		executeServiceRequest "imageVersion"
                executeServiceRequest "bluetooth_mac"

		if [ "$DEVICE_TYPE" != "mediaclient" ]; then
			# snmp based / none mediaclient parameter acquisition
			executeServiceRequest "ecm_mac"
			executeServiceRequest "model"
		fi

                while true
                do
                    if [ "$DEVICE_TYPE" != "mediaclient" ]; then
                        [ -f /tmp/ip_acquired ] && logMsg "/tmp/ip_acquired = true" || logMsg "/tmp/ip_acquired = false"
                        if [[ -f /tmp/ip_acquired ]] && [[ "$ecmIp" == "" || "$IPAddress" == "" || "$model" == "" ]]; then
                            executeServiceRequest "ecm_ip"
                            executeServiceRequest "estb_ip"
                            executeServiceRequest "cableCardVersion"
                            executeServiceRequest "DACInitTimestamp"
                            executeServiceRequest "serial_number"
                            executeServiceRequest "model"
                            executeServiceRequest "ecm_mac"
                        elif [ ! -f /tmp/ip_acquired ]; then
                            [ "$model" == "" ] && executeServiceRequest "model"
                            [ "$serialNumber" == "" ] && executeServiceRequest "serial_number"
                            [ "$CableCardVersion" == "" ] && executeServiceRequest "cableCardVersion"
                        fi
                    fi

                    if [ "$RF4CEMac" == "" ]; then
                        executeServiceRequest "rf4ce_mac"
                    fi

                    if [ "$IPAddress" == "" ] && [ "$WIFI_SUPPORT" == "true" ]; then
                        executeServiceRequest "boxIP"
                    fi
                    
                    if [ "$Version" == "" ]; then
                        executeServiceRequest "imageVersion"
                    fi          

                    [ -f /tmp/moca_ip_acquired ] && logMsg "/tmp/moca_ip_acquired = true" || logMsg "/tmp/moca_ip_acquired = false"

                    # Mediaclient devices with SLAAC will not have this flag
                    # Also refresh moca ip for IPV6 mode
                    if [ -f /tmp/moca_ip_acquired ] && [ "$MocaIp" == "" ]; then
                        executeServiceRequest "moca_ip"
                        executeServiceRequest "moca_mac"
                    elif [ -f /tmp/estb_ipv6 ]; then
                        executeServiceRequest "moca_ip"
                    fi

                    if [[ "$DEVICE_TYPE" == "mediaclient" && "$WIFI_SUPPORT" == "true" && "$IPAddress" != "" ]]; then
                        [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Breaking the loop, Got IPAddress:$IPAddress"
                        break
                    elif [[ "$DEVICE_TYPE" == "mediaclient" && "$WIFI_SUPPORT" != "true" && "$MocaIp" != "" ]]; then
                        [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Breaking the loop, Got MocaIp:$MocaIp"
                        break
                    elif [[ "$ecmIp" != "" && "$IPAddress" != "" && "$MocaIp" != "" && "$model" != "" ]]; then
                        [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Breaking the loop, Got ecmIp:$ecmIp, IPAddress:$IPAddress, MocaIp:$MocaIp, model:$model"
                        break
                    elif [ $(cat /proc/uptime | cut -d ' ' -f1 | cut -d '.' -f1) -gt 360 ]; then
                        [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Breaking the loop, Uptime limit reached"
                        break
                    fi

                    sleep 3
                done
                ;;
      "downloadIP" | "ecm_ip")
		getEcmIp
 		echo "$ecmIp" | safeWrite /tmp/.downloadIP
 		echo "$ecmIp" | safeWrite /tmp/.ecm_ip
                ;;
      "boxIP" | "estb_ip")
		getBoxIPAddress
  		echo "$IPAddress" | safeWrite /tmp/.boxIP
  		echo "$IPAddress" | safeWrite /tmp/.estb_ip
                ;;
      "macAddress" | "estb_mac")
		MacAddress=`getEstbMacAddress`
  		echo "$MacAddress" | safeWrite /tmp/.macAddress
  		echo "$MacAddress" | safeWrite /tmp/.estb_mac
                ;;
      "ecm_mac")
		getEcmMac
  		echo "$EcmMac" | safeWrite /tmp/.ecm_mac
  		echo "$EcmMac" | tr ':' ' ' | safeWrite /tmp/ecm_mac.txt
                ;;
      "eth_mac")
		getEthernetMacAddress
  		echo "$EtherMac" | safeWrite /tmp/.eth_mac
                ;;
      "moca_mac")
		getMocaMac
  		echo "$MocaMac" | safeWrite /tmp/.moca_mac
                ;;
      "wifi_mac")
		[ -f /proc/device-tree/wifi-mac-addr ] && WiFiMac=$(cat /proc/device-tree/wifi-mac-addr) || WiFiMac=
		if [ "$WiFiMac" == "" ]; then
			getWiFiMac
		fi
		echo "$WiFiMac" | safeWrite /tmp/.wifi_mac
                ;;
      "moca_ip")
		getMocaIp
  		echo "$MocaIp" | safeWrite /tmp/.moca_ip
                ;;
      "model")
		getModel
		echo "$model" | safeWrite /tmp/.model
                ;;
      "model_number")
		modelNum=`getModelNum`
		echo "$modelNum" | safeWrite /tmp/.model_number
                ;;
      "manufacturer")
		getManufacturer
                ;;
      "brandname")
		getBrandName
                ;;
      "device_type")
                deviceType=`getDeviceType`
                echo "$deviceType" | safeWrite /tmp/.device_type
                ;;
      "friendly_id")
		friendlyId=`getFriendlyId`
		echo "$friendlyId" | safeWrite /tmp/.friendly_id
                ;;
      "imageVersion")
               getFWVersion
               echo "$Version" | safeWrite /tmp/.imageVersion
                ;;
      "cableCardVersion")
		getCableCardVersion
  		echo "$CableCardVersion" | safeWrite /tmp/.cableCardVersion
                ;;
      "build_type")
		buildType=`getBuildType`
  		echo "$buildType" | safeWrite /tmp/.build_type
                ;;
      "DACInitTimestamp")
		DACInitTimestamp=`getDACInitTimestamp`
	        echo "$DACInitTimestamp" | safeWrite /tmp/.DACInitTimestamp
                ;;
      "serial_number")
		getDeviceSerialNumber
	        echo "$serialNumber" | safeWrite /tmp/.serial_number
                ;;
      "bluetooth_mac")
                BluetoothMac=`getBluetoothMac`
                echo "$BluetoothMac" | safeWrite /tmp/.bluetooth_mac
                ;;
      "rf4ce_mac")
                RF4CEMac=`getRF4CEMac`
                echo "$RF4CEMac" | safeWrite /tmp/.rf4ce_mac
                ;;
      "top_labels")
                echo
                ;;
      "mid_labels")
                echo
                ;;
      "low_labels")
                echo
                ;;
      *)
		logMsg "Error: wrong parameter=\"$parameter\"! No actions. Exit."
                ;;
   esac

   if [ -n "$1" ] && [ "$1" != "all" ]; then
        if [ ! -f "$deviceDetailsCache" ]; then
            executeServiceRequestOutput
        elif echo "$1" | grep -Eq '^[A-Za-z0-9:._-]+$' && [ -f "/tmp/.$1" ] && [ ! -L "/tmp/.$1" ]; then
            tmpfile=$(mktemp)
            value=$(head -n 1 "/tmp/.$1")
            awk -v key="$1" -v val="$value" -F= '
                BEGIN{OFS="="}
                $1==key {$2=val}
                {print}
            ' "$deviceDetailsCache" > "$tmpfile" &&
            chmod 644 "$tmpfile" &&
            mv "$tmpfile" "$deviceDetailsCache"
        fi
        unlock
   fi
}

executeServiceRequestOutput()
{
	logMsg "output"

	# write to a private temp file and rename, so a planted symlink is replaced, never followed
	tmpfile=$(mktemp) || return 1

	if [ "$DEVICE_TYPE" != "mediaclient" ]; then
		printf "estb_mac=%s\necm_mac=%s\nmoca_mac=%s\nwifi_mac=%s\neth_mac=%s\nmodel=%s\nmodel_number=%s\ndevice_type=%s\nfriendly_id=%s\nbuild_type=%s\nimageVersion=%s\necm_ip=%s\nestb_ip=%s\nmoca_ip=%s\ncableCardVersion=%s\nDACInitTimestamp=%s\nserial_number=%s\nbluetooth_mac=%s\nrf4ce_mac=%s\n" \
			"$MacAddress" "$EcmMac" "$MocaMac" "$WiFiMac" "$EtherMac" "$model" "$modelNum" "$deviceType" "$friendlyId" "$buildType" "$FWVersion" "$ecmIp" "$IPAddress" "$MocaIp" "$CableCardVersion" "$DACInitTimestamp" "$serialNumber" "$BluetoothMac" "$RF4CEMac" | sort > "$tmpfile"
        elif [ "$WIFI_SUPPORT" == "true" ]; then
                if [ "$RF4CE_CAPABLE" == "true" ]; then
                        printf "estb_mac=%s\nwifi_mac=%s\neth_mac=%s\nmodel_number=%s\ndevice_type=%s\nfriendly_id=%s\nbuild_type=%s\nimageVersion=%s\nboxIP=%s\nbluetooth_mac=%s\nrf4ce_mac=%s\n" \
                                "$MacAddress" "$WiFiMac" "$EtherMac" "$modelNum" "$deviceType" "$friendlyId" "$buildType" "$FWVersion" "$IPAddress" "$BluetoothMac" "$RF4CEMac" | sort > "$tmpfile"
                else
                        printf "estb_mac=%s\nwifi_mac=%s\neth_mac=%s\nmodel_number=%s\ndevice_type=%s\nfriendly_id=%s\nbuild_type=%s\nimageVersion=%s\nboxIP=%s\nbluetooth_mac=%s\n" \
                                "$MacAddress" "$WiFiMac" "$EtherMac" "$modelNum" "$deviceType" "$friendlyId" "$buildType" "$FWVersion" "$IPAddress" "$BluetoothMac" | sort > "$tmpfile"
                fi
	else
		printf "estb_mac=%s\nmoca_mac=%s\nwifi_mac=%s\neth_mac=%s\nmodel_number=%s\ndevice_type=%s\nfriendly_id=%s\nbuild_type=%s\nimageVersion=%s\nmoca_ip=%s\nbluetooth_mac=%s\nrf4ce_mac=%s\n" \
			"$MacAddress" "$MocaMac" "$WiFiMac" "$EtherMac" "$modelNum" "$deviceType" "$friendlyId" "$buildType" "$FWVersion" "$MocaIp" "$BluetoothMac" "$RF4CEMac" | sort > "$tmpfile"
	fi
	chmod 644 "$tmpfile" && mv -f "$tmpfile" "$deviceDetailsCache"
}

updateMissingParameters()
{
        # /tmp is world-writable: ignore a cache that is a symlink or not owned by us
        if [ -L "$deviceDetailsCache" ] || [ ! -f "$deviceDetailsCache" ] || [ ! -O "$deviceDetailsCache" ]; then
            return 0
        fi
        data=$(sed -n '/=$/p' "$deviceDetailsCache" | tr "=" " ")
        if [ "$data" != "" ]; then
            echo "$data" | while read -r param
            do
                # only known parameter names are used to build paths and commands
                case "$param" in
                    estb_mac|ecm_mac|moca_mac|wifi_mac|eth_mac|model|model_number|device_type|friendly_id|build_type|imageVersion|ecm_ip|estb_ip|moca_ip|boxIP|cableCardVersion|DACInitTimestamp|serial_number|bluetooth_mac|rf4ce_mac) ;;
                    *) continue ;;
                esac
                file="/tmp/.$param"
                if [ -e "$file" ] || [ -L "$file" ]; then
                    if [ -L "$file" ] || [ ! -f "$file" ] || [ ! -O "$file" ]; then
                        rm -f "$file" || continue
                    fi
                fi
                if [ -f "$file" ] && [ ! -L "$file" ] && [ -O "$file" ] && [ "$(head -n 1 "$file")" != "" ]; then
                    tmpfile=$(mktemp)
                    value=$(head -n 1 "$file")
                    awk -v key="$param" -v val="$value" -F= '
                        BEGIN{OFS="="}
                        $1==key {$2=val}
                        {print}
                    ' "$deviceDetailsCache" > "$tmpfile" &&
                    chmod 644 "$tmpfile" &&
                    mv "$tmpfile" "$deviceDetailsCache"
                else
                    executeServiceRequest "$param"
                fi
            done
        fi
}

lock()
{
        locktime=0
	while ! mkdir "$lockDir" &>/dev/null ; do
		logMsg "wait to acquire lock"
                if [ -s $lockPidFile ];then
		    lockPid=$(cat $lockPidFile)
		    if [ $? = 0 ]; then
			if ! kill -0 $lockPid &>/dev/null; then
				unlock "terminated process $lockPid stale"
		  	fi
                    fi
                else
                    prev_locktime=$locktime
                    locktime=$(date +%s -r $lockDir 2> /dev/null)
                    if [ $? = 0 ] && [ "$prev_locktime" = "$locktime" ]; then
                        unlock "terminated process"
                    fi
		fi
		sleep 2
	done
	echo "$$" > $lockPidFile
	logMsg "lock acquired successfully"
	trap 'unlock "active process"'  0 1 13 15 &>/dev/null
}

unlock()
{
	rm -rf "$lockDir"
	logMsg "$1 lock released successfully"
}

# /tmp is world-writable: discard a cache that is a symlink or not a regular file owned by us
if [ -e "$deviceDetailsCache" ] || [ -L "$deviceDetailsCache" ]; then
    if [ -L "$deviceDetailsCache" ] || [ ! -f "$deviceDetailsCache" ] || [ ! -O "$deviceDetailsCache" ]; then
        rm -f "$deviceDetailsCache"
    fi
fi

# execute service request with arguments
if [ "$command" != "" ]; then

     # /tmp is world-writable: discard any cache or /tmp/.<param> file that is a
     # symlink or not owned by the running user so it is regenerated, never trusted
     if [ -n "$parameter" ] && [ "$parameter" != "all" ]; then
         if ! echo "$parameter" | grep -Eq '^[A-Za-z0-9:._-]+$'; then
             logMsg "Error: invalid parameter"
             exit 1
         fi
         if [ -e "/tmp/.$parameter" ] || [ -L "/tmp/.$parameter" ]; then
             if [ -L "/tmp/.$parameter" ] || [ ! -f "/tmp/.$parameter" ] || [ ! -O "/tmp/.$parameter" ]; then
                 rm -f "/tmp/.$parameter"
             fi
         fi
     fi

     if [ ! -s "$deviceDetailsCache" ]; then
         executeServiceRequestOutput
     fi

     logMsg "execute service request with arguments: command=$command : parameter=$parameter"
     if [ "$command" = "refresh" ]; then
         [ "$parameter" = "" ] && parameter="all"
         executeServiceRequest "$parameter"
         if [ "$parameter" != "all" ]; then
            file=/tmp/."$parameter"
            if [ -f "$file" ] && [ -f "$deviceDetailsCache" ] ; then
               value=$(cat "$file")
            fi
         fi
     elif [ "$command" = "read" ]; then
         [ "$parameter" = "" ] && parameter="all"
        if [ -n "$parameter" ] && [ "$parameter" != "all" ]; then
            file=/tmp/."$parameter"
            [ ! -f "$file" ] || [ "$(cat $file)" == "" ]  && executeServiceRequest "$parameter"
            [ -f "$deviceDetailsCache" ] && value=$(cat $deviceDetailsCache | grep $parameter | cut -d "=" -f2)
            if [ -f "$deviceDetailsCache" ] && [ "$value" == "" ] && echo "$parameter" | grep -Eq '^[A-Za-z0-9:._-]+$'; then
                tmpfile=$(mktemp)
                fileValue=$(cat "$file")
                awk -v key="$parameter" -v val="$fileValue" -F= '
                    BEGIN{OFS="="}
                    $1==key {$2=val}
                    {print}
                ' "$deviceDetailsCache" > "$tmpfile" &&
                chmod 644 "$tmpfile" &&
                mv "$tmpfile" "$deviceDetailsCache"
            fi

            [ -f "$file" ] && cat $file
         else
            [ ! -f "$deviceDetailsCache" ] && executeServiceRequest "all"
            updateMissingParameters
            cat $deviceDetailsCache
         fi
     else
	logMsg "Error: wrong command=\"$command\"! No actions. Exit."
     fi

     logMsg "execute service request with arguments: command=$command : parameter=$parameter : exit"
     exit 0
fi

logMsg "cache = $([ -s $deviceDetailsCache ] && echo available || echo empty) "

if [ -s $deviceDetailsCache ]; then
     logMsg "service complete. exit"
     exit 0
fi

# execute all services in one request if not completed
if [ ! -s $deviceDetailsCache ]; then
    executeServiceRequestOutput
fi
executeServiceRequest "all"

logMsg "exit"

exit 0

