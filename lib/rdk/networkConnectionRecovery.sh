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

. /etc/device.properties
. /etc/include.properties
. $RDK_PATH/utils.sh

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

logsFile=$LOG_PATH/ConnectionStats.txt
dnsFile="/etc/resolv.dnsmasq"
wifiStateFile="/tmp/wifi-on"
packetsLostipv4=0
packetsLostipv6=0
lossThreshold=10
lnfSSIDConnected=0
lnfPskSSID=A16746DF2466410CA2ED9FB2E32FE7D9
lnfEnterpriseSSID=D375C1D9F8B041E2A1995B784064977B
ethernet_interface=$(getMoCAInterface) #In Xi WiFi devices MoCA is mapped to Ethernet
pingCount=2
pingInterval=0.2 #Interval between pings
wifiResetWaitTime=180
currentTime=0
tmpFile="/tmp/.Connection.txt"
wifiDriverErrors=0

##RFC parameters that can be customized
EthernetLoggingInterval=600
WifiLoggingInterval=300
GatewayLoggingInterval=180
PacketLossLoggingInterval=300
WifiReassociateInterval=360
WifiResetIntervalForPacketLoss=720
WifiResetIntervalForDriverIssue=120
dnsFailures=0
maxdnsFailures=3

StoreTotmpFile()
{
  [ -f "$tmpFile" ] && rm "$tmpFile"
  { echo "EthernetLogTimeStamp=$EthernetLogTimeStamp" ;
    echo "WifiLogTimeStamp=$WifiLogTimeStamp" ;
    echo "GatewayLogTimeStamp=$GatewayLogTimeStamp" ;
    echo "FirstWifiDriverIssueTime=$FirstWifiDriverIssueTime" ;
    echo "FirstPacketLossTime=$FirstPacketLossTime" ;
    echo "PacketLossLogTimeStamp=$PacketLossLogTimeStamp" ;
    echo "IsWifiReassociated=$IsWifiReassociated" ;
    echo "IsWifiReset=$IsWifiReset" ;
    echo "WifiResetTime=$WifiResetTime" ;
    echo "dnsFailures=$dnsFailures" ;
  } >> "$tmpFile"
}

LoadFromtmpFile()
{
if [ ! -f "$tmpFile" ] ; then
  #Default values
  EthernetLogTimeStamp=0
  WifiLogTimeStamp=$(($(date +%s)))
  GatewayLogTimeStamp=$(($(date +%s)))
  FirstWifiDriverIssueTime=0
  FirstPacketLossTime=0
  PacketLossLogTimeStamp=0
  IsWifiReassociated=0
  IsWifiReset=0
  WifiResetTime=0
  dnsFailures=0
  { echo "EthernetLogTimeStamp=$EthernetLogTimeStamp" ;
    echo "WifiLogTimeStamp=$WifiLogTimeStamp" ;
    echo "GatewayLogTimeStamp=$GatewayLogTimeStamp" ;
    echo "FirstWifiDriverIssueTime=$FirstWifiDriverIssueTime" ;
    echo "FirstPacketLossTime=$FirstPacketLossTime" ;
    echo "PacketLossLogTimeStamp=$PacketLossLogTimeStamp" ;
    echo "IsWifiReassociated=$IsWifiReassociated" ;
    echo "IsWifiReset=$IsWifiReset" ;
    echo "WifiResetTime=$WifiResetTime" ;
    echo "dnsFailures=$dnsFailures" ;
  } >> "$tmpFile"

else
  EthernetLogTimeStamp=$(grep "EthernetLogTimeStamp" $tmpFile|awk -F  "=" '{print $2}')
  WifiLogTimeStamp=$(grep "WifiLogTimeStamp" $tmpFile|awk -F  "=" '{print $2}')
  GatewayLogTimeStamp=$(grep "GatewayLogTimeStamp" $tmpFile|awk -F  "=" '{print $2}')
  FirstWifiDriverIssueTime=$(grep "FirstWifiDriverIssueTime" $tmpFile|awk -F  "=" '{print $2}')
  FirstPacketLossTime=$(grep "FirstPacketLossTime" $tmpFile|awk -F  "=" '{print $2}')
  PacketLossLogTimeStamp=$(grep "PacketLossLogTimeStamp" $tmpFile|awk -F  "=" '{print $2}')
  IsWifiReassociated=$(grep "IsWifiReassociated" $tmpFile|awk -F  "=" '{print $2}')
  IsWifiReset=$(grep "IsWifiReset" $tmpFile|awk -F  "=" '{print $2}')
  WifiResetTime=$(grep "WifiResetTime" $tmpFile|awk -F  "=" '{print $2}')
  dnsFailures=$(grep "dnsFailures" $tmpFile|awk -F  "=" '{print $2}')
fi
}


checkWifiConnected()
{
  [ ! -f "$wifiStateFile" ] && return 0
  strBuffer=$(wpa_cli status 2> /dev/null)
  [[ ! "$strBuffer" =~ "wpa_state=COMPLETED" ]] && return 0
  [[ "$strBuffer" =~ "$lnfPskSSID" ]] || [[ "$strBuffer" =~ "$lnfEnterpriseSSID" ]] && lnfSSIDConnected=1 && return 0
  return 1
}

checkEthernetConnected()
{
  ethernet_state=$(cat /sys/class/net/"$ethernet_interface"/operstate)
  if [ "$WIFI_SUPPORT" = "true" ] ; then
    if [ "$ethernet_state" != "up" ] ; then
      checkWifiConnected
      ret=$?
      if [ $ret -eq  0 ] ; then
        if [ "$lnfSSIDConnected" = "1" ]; then
          echo "$(/bin/timestamp) TELEMETRY_WIFI_CONNECTED_LNF" >> "$logsFile"
          t2CountNotify "SYST_INFO_WIFIConn"
        else
          echo "$(/bin/timestamp) TELEMETRY_WIFI_NOT_CONNECTED" >> "$logsFile"
        fi
        return 0
      else
        echo "$(/bin/timestamp) TELEMETRY_WIFI_CONNECTED" >> "$logsFile"
        t2CountNotify "SYST_INFO_WIFIConn"
        return 0
      fi
    else
      echo "$(/bin/timestamp) TELEMETRY_ETHERNET_CONNECTED" >> "$logsFile"
      t2CountNotify "SYST_INFO_ETHConn"
      return 1
    fi
  fi
}

printEthernetDetails()
{
  { echo "$(/bin/timestamp)"; arp -a; ifconfig; route -n; ip -6 route show; iptables -S; ip6tables -S; echo "$(cat /etc/resolv.dnsmasq)"; } >>"$logsFile"
}

printWifiDetails()
{
    # Command to get channel utilization
    iw dev "$WIFI_INTERFACE" survey dump | grep -A3 "in use" >>"$logsFile"
    iw dev "$WIFI_INTERFACE" link >> "$logsFile"
}

wifiReassociate()
{
  echo "$(/bin/timestamp) Packet Loss WiFi Reassociating" >> "$logsFile"
  t2CountNotify "WIFIV_ERR_reassoc"
  wpa_cli reassociate
  #set IsWifiReassociated to 1 after wifi reassociation
  IsWifiReassociated=1
}

checkWifiDrvErrors()
{
  dir=$(find /sys/kernel/debug/ieee80211  -type d -maxdepth 1 | sed '1d')
  if [ -z "$dir" ] ; then
    echo "$(/bin/timestamp) phy directory not in /sys/kernel/debug/ieee80211" >> "$logsFile"
  elif [ ! -f "$dir"/ath10k/fw_stats ]; then
    echo "$(/bin/timestamp) fw_stats file not in /sys/kernel/debug/ieee80211/$dir/ath10k/" >> "$logsFile"
  else
    cat "$dir"/ath10k/fw_stats > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      echo "$(/bin/timestamp) Cant open file /sys/kernel/debug/ieee80211/$dir/ath10k/ status=$?" >> "$logsFile"
    else
      #Reset tmp variables to 0 when there is no wifi driver issue
      FirstWifiDriverIssueTime=0
      ["$IsWifiReassociated" -eq 0 ] && IsWifiReset=0 #$IsWifiReassociated=1 indicates wifi reassociation done already and still packetloss happens hence don't make IsWifiReset=0
      return 0
    fi
  fi
  #Note down the time when first wifi driver issue is detected
  [ "$FirstWifiDriverIssueTime" -eq 0 ] && FirstWifiDriverIssueTime=$(($(date +%s)))
  return 1
}

checkPacketLoss()
{
  currentTime=$(($(date +%s)))
  #Check IPV4
  gwIpv4=$(/sbin/ip -4 route show default | awk 'NR==1 {print $3; exit}')
  if [ "$gwIpv4" != "" ] ; then
    gwResponse=$(ping -c "$pingCount" -i "$pingInterval"  "$gwIpv4")
    ret=$(echo "$gwResponse" | grep "packet"|awk '{print $7}'|cut -d'%' -f1)
    packetsLostipv4=$ret
    gwResponseTime=$(echo "$gwResponse" | sed '$!d;s|.*/\([0-9.]*\)/.*|\1|')
    #print ipv4 Gateway logs after $GatewayLoggingInterval
    if [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] ; then
      echo "$(/bin/timestamp) v4 gateway = $gwIpv4 " >> "$logsFile"
      if [ "$ret" = "100" ] ; then
        echo "$(/bin/timestamp) TELEMETRY_GATEWAY_RESPONSE_TIME:NR,$gwIpv4" >> "$logsFile"
        t2CountNotify "SYST_WARN_GW100PERC_PACKETLOSS"
      else
        echo "$(/bin/timestamp) TELEMETRY_GATEWAY_RESPONSE_TIME:$gwResponseTime,$gwIpv4" >>"$logsFile"
      fi
      echo "$(/bin/timestamp) TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIpv4" >> "$logsFile"
    fi
  else
    #print ipv4 Gateway logs after $GatewayLoggingInterval
    if [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] ; then
      echo "$(/bin/timestamp) TELEMETRY_GATEWAY_NO_ROUTE_V4" >> "$logsFile"
      t2CountNotify "WIFIV_INFO_NOV4ROUTE"
    fi
  fi

  #Check IPV6
  gwIpv6=$(/sbin/ip -6 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}')
  if [ "$gwIpv6" != "" ] && [ "$gwIpv6" != "dev" ] ; then
    #get default interface name for ipv6 and pass it with ping6 command
    gwIp6_interface=$(/sbin/ip -6 route show default | awk 'NR==1 {print $3; exit}')
    gwResponse=$(ping6 -I "$gwIp6_interface" -c "$pingCount" -i "$pingInterval" "$gwIpv6")
    ret=$(echo "$gwResponse" | grep "packet"|awk '{print $7}'|cut -d'%' -f1)
    packetsLostipv6=$ret
    gwResponseTime=$(echo "$gwResponse" | sed '$!d;s|.*/\([0-9.]*\)/.*|\1|')
    #print ipv6 Gateway logs after $GatewayLoggingInterval
    if [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] ; then
      echo "$(/bin/timestamp) v6 gateway = $gwIpv6 " >> "$logsFile"
      if [ "$ret" = "100" ]; then
        echo "$(/bin/timestamp) TELEMETRY_GATEWAY_RESPONSE_TIME:NR,$gwIpv6" >> "$logsFile"
        t2CountNotify "SYST_WARN_GW100PERC_PACKETLOSS"
      else
        echo "$(/bin/timestamp) TELEMETRY_GATEWAY_RESPONSE_TIME:$gwResponseTime,$gwIpv6" >> "$logsFile"
      fi
      echo "$(/bin/timestamp) TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIpv6" >> "$logsFile"
    fi
  else
    #print ipv6 Gateway logs after $GatewayLoggingInterval
    if [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] ; then
      echo "$(/bin/timestamp) TELEMETRY_GATEWAY_NO_ROUTE_V6" >> "$logsFile"
      t2CountNotify "WIFIV_INFO_NOV6ROUTE"
    fi
  fi

  [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] && GatewayLogTimeStamp=$(($(date +%s)))

  if [ "$packetsLostipv4" -gt "$lossThreshold" ] || [ "$packetsLostipv6" -gt "$lossThreshold" ] ; then
    echo "$(/bin/timestamp) Packet loss more than $lossThreshold% observed." >> "$logsFile"
    [ "$lossThreshold" -eq 10 ] && t2CountNotify "WIFIV_WARN_PL_10PERC"
  fi

  if [ "$packetsLostipv4" = "100" ] && [ "$packetsLostipv6" = "100" ]; then
    echo "$(/bin/timestamp) 100% Packet loss is observed for both ipv4 and ipv6." >> "$logsFile"
    #Note down $FirstPacketLossTime when 100% packetloss is detected for the first time
    [ "$FirstPacketLossTime" -eq 0 ] && FirstPacketLossTime=$(($(date +%s)))
    #Note down $PacketLossLogTimeStamp when PacketLossLogTimeStamp is 0
    [ "$PacketLossLogTimeStamp" -eq 0 ] && PacketLossLogTimeStamp=$(($(date +%s)))
    #Note down $EthernetLogTimeStamp when EthernetLogTimeStamp is 0 and ethernet connected
    [ "$IsEthernetConnected" -eq 1 ] && [ "$EthernetLogTimeStamp" -eq 0 ] && EthernetLogTimeStamp=$(($(date +%s)))
    return 1
  fi

  #Reset tmp parameters to default values when there is no 100% packet loss
  FirstPacketLossTime=0
  PacketLossLogTimeStamp=0
  EthernetLogTimeStamp=0
  IsWifiReassociated=0
  [ "$wifiDriverErrors" -eq 0 ] && IsWifiReset=0 #Make IsWifiReset=0 only when there is no wifidriverissue
  return 0
}

printLogsDuringPacketLoss()
{
  { arp -a; ifconfig; route -n; ip -6 route show; } >> "$logsFile"
  #Print wifi logs
}

wifiReset()
{
  #When usr/sbin/wifi_reset.sh is missing then exit
  #Note down the time when wifi reset is done
  WifiResetTime=$(($(date +%s)))
  #Set IsWifiReset to 1 after wifi reset
  IsWifiReset=1
  StoreTotmpFile
  echo "$(/bin/timestamp) Start WiFi Reset. !!!!!!!!!!!!!!"  >> "$logsFile"
  
  systemctl restart wifi.service
  if [ -f /lib/systemd/system/moca.service ];then
    systemctl restart moca.service
  fi
  systemctl restart netsrvmgr.service
  echo "$(/bin/timestamp) WiFi Reset done as part of  Recovery. !!!!!!!!!!!!!!"  >> "$logsFile"
  exit 0
}

checkDnsFile()
{
  if [ -f "$dnsFile" ] ; then
    if [ $(tr -d ' \r\n\t' < $dnsFile | wc -c ) -eq 0 ] ; then
      echo "$(/bin/timestamp) DNS File($dnsFile) is empty" >> "$logsFile"
      t2CountNotify "SYST_ERR_DNSFileEmpty" 
      gwIpv4=$(/sbin/ip -4 route show default | awk 'NR==1 {print $3; exit}')
      gwIpv6=$(/sbin/ip -6 route show default | awk 'NR==1 {print $3; exit}')
      routeIpv4=$(/sbin/ip -4 route)
      routeIpv6=$(/sbin/ip -6 route)      
      if [ "$gwIpv4" != "" ] || [ "$gwIpv6" != "" ] ; then
	  dnsFailures=$((dnsFailures + 1))
	  case $routeIpv4 in
              *"error"*)
                  dnsFailures=0
                 ;;
          esac
	  case $routeIpv6 in
              *"error"*)
                  dnsFailures=0
                  ;;
          esac
      else
          dnsFailures=0
      fi

      if [ "$dnsFailures" -gt "$maxdnsFailures" ] ; then
          echo "$(/bin/timestamp) Restarting udhcpc to recover" >> "$logsFile"
          InterfaceList="$ethernet_interface $WIFI_INTERFACE"
          for interface in $InterfaceList
          do
              UDHCPC_PID_FILE="/tmp/udhcpc.$interface.pid"
              if [ -f "$UDHCPC_PID_FILE" ]; then
                  UDHCPC_PID="$(cat "$UDHCPC_PID_FILE")"
                  if [ "x$UDHCPC_PID" != "x" ]; then
                      /bin/kill -9 "$UDHCPC_PID"
                      /sbin/udhcpc -b -o -i "$interface" -p /tmp/udhcpc."$interface".pid
                  fi
              fi
          done
      fi
  else
      dnsFailures=0
    fi
  else
    echo "$(/bin/timestamp) DNS File is not there $dnsFile" >> "$logsFile"
  fi
}

checkRfc()
{
  rfcWifiResetEnable="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.WiFiReset.Enable 2>&1 > /dev/null)"
  if [ "$rfcWifiResetEnable" = "true" ] ; then
    echo "$(/bin/timestamp) WiFiReset RFC is true " >> "$logsFile"
    rfcEthernetLoggingInterval="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.WiFiReset.EthernetLoggingInterval 2>&1 > /dev/null)"
    if [ ! -z "$rfcEthernetLoggingInterval" ] && [ "$rfcEthernetLoggingInterval" != 0 ] ; then
      EthernetLoggingInterval="$rfcEthernetLoggingInterval"
    fi
    rfcWifiLoggingInterval="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.WiFiReset.WifiLoggingInterval 2>&1 > /dev/null)"
    if [ ! -z "$rfcWifiLoggingInterval" ] && [ "$rfcWifiLoggingInterval" != 0 ] ; then
      WifiLoggingInterval="$rfcWifiLoggingInterval"
    fi
    rfcPacketLossLoggingInterval="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.WiFiReset.PacketLossLoggingInterval 2>&1 > /dev/null)"
    if [ ! -z "$rfcPacketLossLoggingInterval" ] && [ "$rfcPacketLossLoggingInterval" != 0 ] ; then
      PacketLossLoggingInterval="$rfcPacketLossLoggingInterval"
    fi
    rfcWifiReassociateInterval="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.WiFiReset.WifiReassociateInterval 2>&1 > /dev/null)"
    if [ ! -z "$rfcWifiReassociateInterval" ] && [ "$rfcWifiReassociateInterval" != 0 ] ; then
      WifiReassociateInterval="$rfcWifiReassociateInterval"
    fi
    rfcWifiResetIntervalForPacketLoss="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.WiFiReset.WifiResetIntervalForPacketLoss 2>&1 > /dev/null)"
    if [ ! -z "$rfcWifiResetIntervalForPacketLoss" ] && [ "$rfcWifiResetIntervalForPacketLoss" != 0 ] ; then
      WifiResetIntervalForPacketLoss="$rfcWifiResetIntervalForPacketLoss"
    fi
    rfcWifiResetIntervalForDriverIssue="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.WiFiReset.WifiResetIntervalForDriverIssue 2>&1 > /dev/null)"
    if [ ! -z "$rfcWifiResetIntervalForDriverIssue" ] && [ "$rfcWifiResetIntervalForDriverIssue" != 0 ] ; then
      WifiResetIntervalForDriverIssue="$rfcWifiResetIntervalForDriverIssue"
    fi
  fi
}

#If RFC is enabled, then load the customized RFC parameters
checkRfc

#Load the contents of tmpFile
LoadFromtmpFile

#After a wifi reset, skip all for a interval of $wifiResetTime
if [ "$IsWifiReset" -eq 1 ] ; then
  currentTime=$(($(date +%s)))
  if [ "$(($WifiResetTime+$wifiResetWaitTime))" -gt "$currentTime" ] ; then
    echo "$(/bin/timestamp) Skip all checks since wifi reset is done recently"  >> "$logsFile"
    exit 0
  fi
fi

checkEthernetConnected
IsEthernetConnected=$?
checkWifiConnected
IsWifiConnected=$?

if [ "$IsEthernetConnected" -eq 1 ] ; then
    currentTime=$(($(date +%s)))
    #When packetloss is detected, print debug logs after $EthernetLoggingInterval
    if [ "$(($EthernetLogTimeStamp+$EthernetLoggingInterval))" -le "$currentTime" ] ; then
      EthernetLogTimeStamp=$(($(date +%s)))
      printEthernetDetails
    fi
  fi

elif [ "$IsWifiConnected" -eq 1 ] ; then
  currentTime=$(($(date +%s)))
  #print wifi logs after $WifiLoggingInterval
  if [ "$(($WifiLogTimeStamp+$WifiLoggingInterval))" -le "$currentTime" ] ; then
    WifiLogTimeStamp=$(($(date +%s)))
    printWifiDetails
  fi


  #Check packetloss
  checkPacketLoss
  packetLoss=$?
  if [ "$packetLoss" -eq 1 ] ; then
    currentTime=$(($(date +%s)))
    #Print debug logs during a packetloss after $PacketLossLoggingInterval
    if [ "$(($PacketLossLogTimeStamp+$PacketLossLoggingInterval))" -le "$currentTime" ] ; then
      PacketLossLogTimeStamp=0
      printLogsDuringPacketLoss
    fi
    if [ "$IsWifiReassociated" -eq 0 ] && [ "$IsWifiReset" -eq 0 ] ; then
      #If packetloss happens, do a wifi reassociate after $WifiReassociateInterval
      [ "$(($FirstPacketLossTime+$WifiReassociateInterval))" -le "$currentTime" ] && wifiReassociate
    elif [ "$IsWifiReset" -eq 0 ] && [ "$rfcWifiResetEnable" = "true" ] ; then
      #If wifi reassociate also does not help packetloss, then do a wifi reset after $WifiResetIntervalForPacketLoss
      [ "$(($FirstPacketLossTime+$WifiResetIntervalForPacketLoss))" -le "$currentTime" ] && wifiReset
    fi
  fi
fi
checkDnsFile
#Store tmp variables to tmpFile
StoreTotmpFile
