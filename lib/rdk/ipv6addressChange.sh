#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
# file the following copyright and licenses apply:
#
# Copyright 2018 RDK Management
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
## invocation format
## add ipv4 interfacename address global

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

IPV6_CHANGE_LOGFILE="/opt/logs/NMMonitor.log"
ipv6ChangeLog() {
    echo "`/bin/timestamp` :$0: $*" >> $IPV6_CHANGE_LOGFILE
}
. /etc/device.properties

cmd=$1
mode=$2
ifc=$3
addr=$4
flags=$5

IPTABLE_CMD="/usr/sbin/iptables -w "

if [ $ifc == "dobby0" ]; then
     ipv6ChangeLog "Exit the script due to interface $ifc"
     exit
fi

if [ $mode == "ipv6" ]; then
     IPTABLE_CMD="/usr/sbin/ip6tables -w "
     mode_str="-6"
else
     mode_str="-4"
fi
LOGMILESTONE_BIN="/usr/bin/rdkLogMileStone"

(/bin/busybox kill -STOP $$; /bin/busybox kill -CONT $$)
if [ "x$cmd" == "xadd" ] && [ "x$flags" == "xglobal" ]; then
   if [ ! -f /tmp/estb_ipv4 ] && [ ! -f /tmp/estb_ipv6 ];
   then
      if [ -f "$LOGMILESTONE_BIN" ]; then
          $LOGMILESTONE_BIN "IP_ACQUISTION_COMPLETED:$ifc"
          if [ $ifc == "eth0" ]; then
              ifc_uptime=$(awk '{printf "%.0f", $1 * 1000}' /proc/uptime)
              t2ValNotify "btime_ipacqEth_split" "$ifc_uptime"
	  elif [ $ifc == "wlan0" ]; then
              ifc_uptime=$(awk '{printf "%.0f", $1 * 1000}' /proc/uptime)
              t2ValNotify "btime_ipacqWifi_split" "$ifc_uptime"
          fi
      fi
   fi

   if [[ ($addr != fd* && $addr != fc*) || ($addr != 169.254* && $addr != 192.168.18.10 && $addr != 192.0.2.10 && $addr != 192.0.2.11) ]]; then
        ipv6ChangeLog "Creating $mode flags for $ifc"
        touch "/tmp/estb_$mode"
        touch "/tmp/addressaquired_$mode"
   else
	ipv6ChangeLog "It is a ULA address, no need to create IPv6 flags or ignoring zero config or default IP ($addr) assigned for $ifc"
   fi
fi

if [ "x$cmd" == "xdelete" ] && [ "x$flags" == "xglobal" ]; then
    if [[ ($mode == "ipv6" && $addr != fd* && $addr != fc*) || ($mode != "ipv6") ]]; then
        pd=`pwd`
        cd /sys/class/net
        globalip=""
        for i in `ls`
        do
            if [ "$i" = "$WIFI_INTERFACE" ] || [ "$i" = "$ETHERNET_INTERFACE" ]; then
	        lglobal=`/sbin/ip $mode_str addr show dev $i | grep global`
                globalip="$globalip $lglobal"
            fi
        done
        cd $pd

        # cleaning up all the spaces
        gIp=`echo $globalip | xargs`
        if [ "x$gIp" = "x" ]; then
            ipv6ChangeLog "Creating $mode flags for $ifc"
            rm -f "/tmp/estb_$mode"
            rm -f "/tmp/addressaquired_$mode"
        fi
    else
	ipv6ChangeLog "It is a ULA address, no need to create IPv6 flags or ignoring zero config or default IP ($addr) assigned for $ifc"
    fi
fi

ipv6ChangeLog "Received address Notification, cmd = $cmd, mode = $mode,  ifc= $ifc, addr = $addr, flags = $flags"

uptime=`cat /proc/uptime | awk '{print $1}'`

if [ $ifc == "$WIFI_INTERFACE" ] || [ $ifc == "$MOCA_INTERFACE" ] || [ $ifc == "$LAN_INTERFACE" ] || [ $ifc == "${WIFI_INTERFACE}:0" ] || [ $ifc == "${MOCA_INTERFACE}:0" ] || [ $ifc == "${LAN_INTERFACE}:0" ]; then

   if [ "x$cmd" == "xadd" ] && [ "x$flags" == "xglobal" ]; then
     # Check for ESTB_INTERFACE from device.properties is matching with IP acquired interface.
     ipv6ChangeLog "Received global $mode address for $ifc interface, uptime is $uptime milliseconds"
     touch "/tmp/${mode}_${flags}"

     $IPTABLE_CMD -I INPUT -s $addr -p tcp --dport 22 -j ACCEPT
     $IPTABLE_CMD -I OUTPUT -o lo -p tcp -s $addr -d $addr -j ACCEPT
     systemctl reset-failed tr69agent.service
     systemctl restart tr69agent.service
   fi

   if [ "x$cmd" == "xdelete" ] && [ "x$flags" == "xglobal" ]; then
     $IPTABLE_CMD -D INPUT -s $addr -p tcp --dport 22 -j ACCEPT
     $IPTABLE_CMD -D OUTPUT -o lo -p tcp -s $addr -d $addr -j ACCEPT
     if [ -f "/tmp/${mode}_${flags}" ]; then
         rm -rf "/tmp/${mode}_${flags}"
     fi
   fi
   
   if [ -d /opt/logs ] && [ $mode == "ipv6" ]; then
      ra_enabled=`sysctl -n net.ipv6.conf.$ifc.accept_ra`
      if [ "$ra_enabled" == "1" ]; then
       ipv6ChangeLog "Address : $addr, is $cmd ed using SLAAC(RA) for interface $ifc"
      else
       ipv6ChangeLog "Address : $addr, is $cmd ed for interface $ifc"
      fi
   fi

   # Refresh device cache info
   if [ -f /lib/rdk/getDeviceDetails.sh ]; then
       sh /lib/rdk/getDeviceDetails.sh 'refresh' 'all' &
   fi
fi

if [ $ifc == "$WIFI_INTERFACE" ] || [ $ifc == "$MOCA_INTERFACE" ] || [ $ifc == "${WIFI_INTERFACE}:0" ] || [ $ifc == "${MOCA_INTERFACE}:0" ]; then

  if [ "x$flags" == "xglobal" ]; then
       if [ ! -f /tmp/Dropbear_restart_disabled ]; then
            echo "`/bin/timestamp` Restarting Dropbear due to global ip address changes" >> /opt/logs/dropbear.log
            systemctl reset-failed dropbear.service
            systemctl restart dropbear.service &
       else
            echo "`/bin/timestamp` Preventing Dropbear restarts" >> /opt/logs/dropbear.log
       fi
  fi
fi
