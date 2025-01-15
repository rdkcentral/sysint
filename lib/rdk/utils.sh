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

# Scripts having common utility functions
. /etc/common.properties
. /etc/include.properties
. /etc/device.properties
. /etc/env_setup.sh

if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

export PATH=$PATH:/sbin:/usr/sbin
CORE_LOG="$LOG_PATH/core_log.txt"

#This is need to set core path for yocto builds
if [ -f /etc/os-release ]; then
        export CORE_PATH=$CORE_PATH
fi

if [ "$BUILD_TYPE" != "prod" ] && [ -f $PERSISTENT_PATH/rfc.properties ]; then
    . $PERSISTENT_PATH/rfc.properties
else
   . /etc/rfc.properties
fi

processCheck()
{
   count=`ps | grep $1 | grep -v grep | wc -l`
   if [ $count == 0 ]; then
        echo "1"
   else
        echo "0"
   fi
}

rebootFunc()
{
    sync
    if [[ $1 == "" ]] && [[ $2 == "" ]]; then
       process=`cat /proc/$PPID/cmdline`
       reason="Rebooting by calling rebootFunc of utils.sh script..."
    else
       process=$1
       reason=$2
    fi
    /rebootNow.sh -s $process -o $reason
}

checkProcess()
{
  ps | grep $1 | grep -v grep
}

# Last modified time
getLastModifiedTimeOfFile()
{
    if [ -f $1 ] ; then
        stat -c '%y' $1 | cut -d '.' -f1 | sed -e 's/[ :]/-/g'
    fi
}

# Set the name of the log file using SHA1
setLogFile()
{
    fileName=`basename $6`
    echo $1"_mac"$2"_dat"$3"_box"$4"_mod"$5"_"$fileName
}

# Get the MAC address of the machine
getMacAddressOnly()
{
   cat /sys/class/net/${ESTB_INTERFACE}/address | sed -e 's/://g' | tr a-z A-Z
    
}

# Get the SHA1 checksum
getSHA1()
{
    sha1sum $1 | cut -f1 -d" "

}

# IP address of the machine
getIPAddress()
{
    if [ "$WIFI_SUPPORT" == "true" ] && [ -f /tmp/wifi-on ]; then
        interface=$WIFI_INTERFACE
    else
        interface=$ESTB_INTERFACE
    fi

    if [ -z $IPAddress ]; then
        if [ -f /tmp/estb_ipv6 ]; then
            IPAddress=`ifconfig -a $interface | grep inet6 | tr -s " " | grep -v Link | grep -i global | cut -d " " -f4 | cut -d "/" -f1 | tail -n1`
        else
            IPAddress=`ifconfig -a $interface | grep inet | grep -v inet6 | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g' | tail -n1`
        fi
    fi

    if [ "$(getModel)" = "RPI" ]; then
        if [ -f /tmp/wifi-on ]; then
            interface=`getWiFiInterface`
        else
            interface=`getMoCAInterface`
        fi
        if [ -f /tmp/estb_ipv6 ]; then
            IPAddress=`ip addr show dev $interface | grep -i global | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d' | head -n1`
        else
            IPAddress=`ifconfig $interface | grep inet | tr -s ' ' | cut -d ' ' -f3 | sed -e 's/addr://g'`
        fi
    fi

    echo $IPAddress
}

getEstbMacAddress()
{
    ifconfig -a $ESTB_INTERFACE | grep $ESTB_INTERFACE | tr -s ' ' | cut -d ' ' -f5 | tr -d '\r\n'
    
}

# Return system uptime in seconds
Uptime()
{
     cat /proc/uptime | awk '{ split($1,a,".");  print a[1]; }'
}

getMoCAInterface()
{
        if [ -f $PERSISTENT_PATH/moca_interface ] && [ "$BUILD_TYPE" != "prod" ] ; then
                interface=`cat $PERSISTENT_PATH/moca_interface`
        else
                interface=$MOCA_INTERFACE
                if [ ! "$interface" ]; then
                     interface=eth0
                fi

                if [[ "$MOCA_SUPPORT" == "true" ]]; then
                    interface=$MOCA_INTERFACE
                fi
        fi
        echo $interface
}

getWiFiInterface()
{
        if [ -f $PERSISTENT_PATH/wifi_interface ] && [ "$BUILD_TYPE" != "prod" ] ; then
                interface=`cat $PERSISTENT_PATH/wifi_interface`
        else
                interface=$WIFI_INTERFACE
        fi
        if [ ! "$interface" ]; then
                interface=wlan0
        fi
        echo $interface
}

getModel()
{
    if [ "$DEVICE_TYPE" = "hybrid" ] ; then
        model=`sh $RDK_PATH/getDeviceDetails.sh read model`
        echo $model
    else
        model_number=`sh $RDK_PATH/getDeviceDetails.sh read model_number`
        echo $model_number
    fi
}

checkWiFiModule()
{
    if [ -f "/tmp/wifi-on" ]; then
        echo 1
    else
        echo 0
    fi
}

getDeviceBluetoothMac()
{
        bluetooth_mac="00:00:00:00:00:00"
        hash hcitool >/dev/null 2>&1
        if [ $? -eq 0 ] ; then
            bluetooth_mac=`hcitool dev |grep hci |cut -d$'\t' -f3|tr -d '\r\n'`
        fi
    echo $bluetooth_mac
}

getRFCValueForTR181Param()
{
    tr181_status='false'
    TR181_PARAM_NAME=$1
    tr181_status=`/usr/bin/tr181Set  ${TR181_PARAM_NAME}  2>&1 > /dev/null`
    if [ $? -ne 0 ];then
        if [ -f ${TR181_STORE_FILENAME} ]; then
            echo "tr181Set doesnt work get TR181_PARAM_NAME from ${TR181_STORE_FILENAME} file" >&2
            tr181_status=`grep ${TR181_PARAM_NAME}'=' ${TR181_STORE_FILENAME} | cut -d "=" -f2`
        else
            echo "Error - ${TR181_STORE_FILENAME} file not available" >&2
            tr181_status='false'
        fi
    fi
    echo $tr181_status
}

# Flush the logger daemon buffers to the file
flushLogger()
{
    echo "$(/bin/timestamp) [PID:$$]: [utils.sh] flushLogger is called" >> /opt/logs/core_log.txt
    # Flush journald buffers
    test -f '/etc/os-release' && which journalctl && journalctl --sync --flush
    if [ "$SYSLOG_NG_ENABLED" != "true" ] ; then
        # Separate journald logs to files
        nice -n 19 /lib/rdk/dumpLogs.sh
    fi
}

getMacAddress()
{
	MacAddress=`ifconfig -a $ESTB_INTERFACE | grep $ESTB_INTERFACE | tr -s ' ' | cut -d ' ' -f5`
    echo $MacAddress
}

Timestamp()
{
    date +"%Y-%m-%d %T"
}

# argument is maximum time to wait in seconds
waitForDumpCompletion()
{
    waitTime=$1
    while [[ `dumpInProcess` == 'true' ]];
    do
        echo "`/bin/timestamp` Waiting for core dump completion." >> $CORE_LOG
        count=`expr $count + 1`
        sleep 1
        if [ $count -gt $waitTime ]; then
            echo "`/bin/timestamp` Core dump creation is taking more time than expected. Returning." >> $CORE_LOG
            return
        fi
    done
}

dumpInProcess()
{
    if [[ -n "`ls $CORE_PATH/*.gz.tmp 2>/dev/null`" ]]; then
        echo 'true'
    else
        echo 'false'
    fi
}

haveCoreToUpload()
{
    if [[ -n "`ls $CORE_PATH/*.gz.tmp 2>/dev/null`" ]] || [[ -n "`ls $CORE_PATH/*.gz 2>/dev/null`" ]]; then
        echo 'true'
    else
        echo 'false'
    fi
}

getPrivacyControlMode()
{
    #Implement own logic to get the privicyMode settings
    return
}
