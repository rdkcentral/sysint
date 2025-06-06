#!/bin/busybox sh
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

# Purpose: Script to Initiate SSH Session
# Scope: RDK devices
# Usage: Run as a systemd service

. /etc/include.properties
. /etc/device.properties
if [ "$DEVICE_TYPE" = "mediaclient" ]; then
     . /lib/rdk/utils.sh
fi
if [ -f /etc/mount-utils/getConfigFile.sh ];then
      mkdir -p /tmp/.dropbear
      . /etc/mount-utils/getConfigFile.sh

      DROPBEAR_PARAMS_1="/tmp/.dropbear/dropcfg1"
      DROPBEAR_PARAMS_2="/tmp/.dropbear/dropcfg2"

      getConfigFile $DROPBEAR_PARAMS_1

      if [ ! -f "$DROPBEAR_PARAMS_1" ]; then
        echo "Dropbear param 1: $DROPBEAR_PARAMS_1 generation failure"
        exit 127
      fi

      getConfigFile $DROPBEAR_PARAMS_2

      if [ ! -f "$DROPBEAR_PARAMS_2" ]; then
        echo "Dropbear param 2: $DROPBEAR_PARAMS_2 generation failure"
        exit 127
      fi
fi
WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"
if [ -f /tmp/SSH.pid ]
then
   if [ -d /proc/$(cat /tmp/SSH.pid) ]
   then
      echo "An instance of startSSH.sh is already running !!! Exiting !!!"
      exit 0
   fi
fi

echo $$ > /tmp/SSH.pid

ipAddress=""
checkForInterface()
{
   interface=$1
   if [ -f /tmp/.ipv6$interface ]; then
       echo "Reading IPv6 address for $interface"
       ipv6address=`cat /tmp/.ipv6$interface`
   fi
   if [ -f /tmp/.ipv4$interface ]; then
       echo "Reading IPv4 address for $interface"
       ipv4address=`cat /tmp/.ipv4$interface`
   fi
}

#RFC check for MOCA SSH enable/not.
isMOCASSHEnable=$(/usr/bin/tr181Set -d  Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MOCASSH.Enable 2>&1 > /dev/null)

echo "RFC_ENABLE_MOCASSH:$isMOCASSHEnable"

if [ "$COMMUNITY_BUILDS" = "true" ]; then
     EXTRA_ARGS=" -B "
     DROPBEAR_KEY_DIR="/opt/dropbear"
     if [ ! -f ${DROPBEAR_KEY_DIR}/dropbear_rsa_host_key ] ; then
        systemctl start dropbearkey.service
     fi
     DROPBEAR_PARAMS="${DROPBEAR_KEY_DIR}/dropbear_rsa_host_key"
else
     EXTRA_ARGS=" -s -a"
fi
loop=1
address=""
# mediaclient code
if [ "$DEVICE_TYPE" = "mediaclient" ]; then
      while [ $loop -eq 1 ]
      do
           if [ "$WIFI_INTERFACE" ] && [ ! "$ipAddress" ];then
                 checkForInterface "$WIFI_INTERFACE"
                 ipAddress+=" "
                 ipAddress+=$ipv6address
                 ipAddress+=" "
                 ipAddress+=$ipv4address
           fi
           Interface=`getMoCAInterface`
           checkForInterface "$Interface"
           ipAddress+=" "
           ipAddress+=$ipv6address
           ipAddress+=" "
           ipAddress+=$ipv4address
           break

           if [ "$isMOCASSHEnable" = "true" ];then
               ipAddress+=" "
               ipAddress+=`ifconfig $MOCA_INTERFACE |grep 169.254.* |tr -s ' '| cut -d ' ' -f3 | sed -e 's/addr://g'`
           fi
           sleep 5
     done

     #Concatenating all ip addresses
     IP_ADDRESS_PARAM=""
     for i in $ipAddress;
     do
          IP_ADDRESS_PARAM+="-p $i:22 "
     done
     if [ -e /sbin/dropbear ] || [ -e /usr/sbin/dropbear ] ; then
          if [ -f /etc/os-release ];then
                if [ "$COMMUNITY_BUILDS" = "true" ]; then
                      /bin/systemctl set-environment DROPBEAR_PARAMS="-r $DROPBEAR_PARAMS"
                else
                      /bin/systemctl set-environment DROPBEAR_PARAMS="-r $DROPBEAR_PARAMS_1 -r $DROPBEAR_PARAMS_2"
                fi
                /bin/systemctl set-environment DROPBEAR_EXTRA_ARGS="$EXTRA_ARGS"
                /bin/systemctl set-environment IP_ADDRESS_PARAM="$IP_ADDRESS_PARAM"
          else
              dropbear -s -b /etc/sshbanner.txt -s -a -r $DROPBEAR_PARAMS_1 -r $DROPBEAR_PARAMS_2 $IP_ADDRESS_PARAM $USE_DEVKEYS &
          fi
     fi
     exit 0
fi

startDropbear()
{
     ipAddress=$1
     echo --------- $interface got an ip $ipAddress starting dropbear service ---------
     if [ -f /etc/os-release ];then
          /bin/systemctl set-environment IP_ADDRESS=$ipAddress
          if [ "$COMMUNITY_BUILDS" = "true" ]; then
                /bin/systemctl set-environment DROPBEAR_PARAMS="-r $DROPBEAR_PARAMS"
          else
                /bin/systemctl set-environment DROPBEAR_PARAMS="-r $DROPBEAR_PARAMS_1 -r $DROPBEAR_PARAMS_2"
          fi
          /bin/systemctl set-environment DROPBEAR_EXTRA_ARGS="$EXTRA_ARGS"
     else
          dropbear -b /etc/sshbanner.txt -s -a -r $DROPBEAR_PARAMS_1 -r $DROPBEAR_PARAMS_2 -p $ipAddress:22 $USE_DEVKEYS &
     fi
     echo "$ipAddress" > /tmp/.dropbearBoundIp
}

# non-mediaclient devices
while [ $loop -eq 1 ]
do
    estbIp=$(getIPAddress)
    if [ "X$estbIp" == "X" ]; then
         sleep 15
    else
         if [ "$IPV6_ENABLED" = "true" ]; then
              if [ "Y$estbIp" != "Y$DEFAULT_IP" ] && [ -f $WAREHOUSE_ENV ]; then
                   startDropbear "$estbIp"
                   loop=0
              elif [ ! -f /tmp/estb_ipv4 ] && [ ! -f /tmp/estb_ipv6 ]; then
                   sleep 15
              elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv4 ]; then
                   #echo "waiting for IP ..."
                   sleep 15
              elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv6 ]; then
                   #echo "waiting for IP ..."
                   sleep 15
              else
                   startDropbear "$estbIp"
                   loop=0
              fi
         else
              if [ "Y$estbIp" == "Y$DEFAULT_IP" ]; then
                   #echo "waiting for IP ..."
                   sleep 15
              else
                   startDropbear "$estbIp"
                   loop=0
              fi
         fi
    fi
done

exit 0
