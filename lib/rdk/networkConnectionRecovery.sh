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

#Purpose : To recover from the network breakages and log the details
#Scope   : RDK Devices
#Usage   : Invoked by systemd service
 
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
pingCount=10
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
WifiReassociateTolerance=100
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
    echo "count=$count" ;
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
  count=0
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
    echo "count=$count" ;
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
  count=$(grep "count" $tmpFile|awk -F  "=" '{print $2}')
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
          #Reset count when lnf ssid is connected
          count=0
          t2CountNotify "SYST_INFO_WIFIConn"
        else
          #Skip printing wifi not connected log for the first time
          [ $count -gt 0 ] && echo "$(/bin/timestamp) TELEMETRY_WIFI_NOT_CONNECTED" >> "$logsFile"
          count=$((count + 1))
        fi
        return 0
      else
        echo "$(/bin/timestamp) TELEMETRY_WIFI_CONNECTED" >> "$logsFile"
        #Reset count when connectivity is good
        count=0
        t2CountNotify "SYST_INFO_WIFIConn"
        return 0
      fi
    else
      echo "$(/bin/timestamp) TELEMETRY_ETHERNET_CONNECTED" >> "$logsFile"
      #Reset count when connectivity is good
      count=0
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
  echo "$(/bin/timestamp) [DEBUG_NCR] wifiReassociate TRIGGERED: IsWifiReassociated=$IsWifiReassociated IsWifiReset=$IsWifiReset FirstPacketLossTime=$FirstPacketLossTime WifiReassociateInterval=$WifiReassociateInterval currentTime=$currentTime packetsLostipv4=$packetsLostipv4 packetsLostipv6=$packetsLostipv6" >> "$logsFile"
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
  version=$1
  currentTime=$(($(date +%s)))
  echo "$(/bin/timestamp) [DEBUG_NCR] checkPacketLoss ENTER: version=$version currentTime=$currentTime WifiReassociateTolerance=$WifiReassociateTolerance packetsLostipv4=$packetsLostipv4 packetsLostipv6=$packetsLostipv6 FirstPacketLossTime=$FirstPacketLossTime PacketLossLogTimeStamp=$PacketLossLogTimeStamp IsWifiReassociated=$IsWifiReassociated IsWifiReset=$IsWifiReset" >> "$logsFile"

  if [ -f "/tmp/checkpacketloss" ] ; then
    if [ "$version" = "V4" ] ; then
      gwIp=$(cat /tmp/checkpacketloss)
      pingCmd="ping"
    fi
  else
    if [ "$version" = "V4" ] ; then
      gwIp=$(/sbin/ip -4 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}')
      pingCmd="ping"
    elif [ "$version" = "V6" ] ; then
      gwIp=$(/sbin/ip -6 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}')
      gwIp_interface=$(/sbin/ip -6 route | awk '/default/ { print $5 }' | head -n1 | awk '{print $1;}')
      pingCmd="ping6 -I $gwIp_interface"
    fi
  fi
  echo "$(/bin/timestamp) [DEBUG_NCR] checkPacketLoss: resolved gwIp='$gwIp' pingCmd='$pingCmd'" >> "$logsFile"

  if [ "$gwIp" != "" ] && [ "$gwIp" != "dev" ] ; then
    gwResponse=$($pingCmd -c "$pingCount" -i "$pingInterval" "$gwIp")
    ret=$(echo "$gwResponse" | grep "packet"|awk '{print $7}'|cut -d'%' -f1)

    if [ "$version" = "V4" ] ; then
      packetsLostipv4=$ret
    elif [ "$version" = "V6" ] ; then
      packetsLostipv6=$ret
    fi
    echo "$(/bin/timestamp) [DEBUG_NCR] checkPacketLoss: ping result ret=$ret packetsLostipv4=$packetsLostipv4 packetsLostipv6=$packetsLostipv6" >> "$logsFile"

    gwResponseTime=$(echo "$gwResponse" | sed '$!d;s|.*/\([0-9.]*\)/.*|\1|')
    if [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] ; then
      echo "$(/bin/timestamp) $version gateway = $gwIp " >> "$logsFile"
      if [ "$ret" = "100" ] ; then
        echo "$(/bin/timestamp) TELEMETRY_GATEWAY_RESPONSE_TIME:NR,$gwIp" >> "$logsFile"
        echo "$(/bin/timestamp) Current Packet loss is SYST_WARN_GW100PERC_PACKETLOSS"
        t2CountNotify "SYST_WARN_GW100PERC_PACKETLOSS"
      else
        echo "$(/bin/timestamp) TELEMETRY_GATEWAY_RESPONSE_TIME:$gwResponseTime,$gwIp" >> "$logsFile"
      fi
      echo "$(/bin/timestamp) TELEMETRY_GATEWAY_PACKET_LOSS:$ret,$gwIp" >> "$logsFile"
    fi
  else
    if [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] ; then
      echo "$(/bin/timestamp) TELEMETRY_GATEWAY_NO_ROUTE_$version" >> "$logsFile"
      t2CountNotify "WIFIV_INFO_NO${version}ROUTE"
    fi
  fi

  [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] && GatewayLogTimeStamp=$(($(date +%s)))

    #Send telemetry notification for 20%,30%....90% packet loss
  if [ "$packetsLostipv4" -gt "$lossThreshold" ] || [ "$packetsLostipv6" -gt "$lossThreshold" ] ; then
    echo "$(/bin/timestamp) Packet loss more than $lossThreshold% observed." >> "$logsFile"
    if [ "$packetsLostipv4" -ne 100 ] && [ "$packetsLostipv6" -ne 100 ]; then
      for i in {1..9}; do
          if ([ "$packetsLostipv4" -ge $((i*10)) ] && [ "$packetsLostipv4" -lt $((i*10+10)) ]) || ([ "$packetsLostipv6" -ge $((i*10)) ] && [ "$packetsLostipv6" -lt $((i*10+10)) ]); then
            echo "$(/bin/timestamp) Current Packet loss is WIFIV_WARN_PL_"$((i*10))"PERC"  >> "$logsFile"
            t2CountNotify "WIFIV_WARN_PL_"$((i*10))"PERC"
            break
          fi
      done
    fi
  else
    if [ "$packetsLostipv4" -ne 0 ] && [ "$packetsLostipv6" -ne 0 ]; then
      #Send telemetry notification for 10% packet loss
      echo "$(/bin/timestamp) Current Packet loss is WIFIV_WARN_PL_10PERC" >>  "$logsFile"
      t2CountNotify "WIFIV_WARN_PL_10PERC"
    fi
  fi

  echo "$(/bin/timestamp) [DEBUG_NCR] checkPacketLoss: WifiReassociateTolerance check - packetsLostipv4=$packetsLostipv4 packetsLostipv6=$packetsLostipv6 WifiReassociateTolerance=$WifiReassociateTolerance" >> "$logsFile"
  if [ "$packetsLostipv4" -ge "$WifiReassociateTolerance" ] && [ "$packetsLostipv6" -ge "$WifiReassociateTolerance" ]; then
    echo "$(/bin/timestamp) ${WifiReassociateTolerance}% Packet loss is observed for both ipv4 and ipv6." >> "$logsFile"
    #Note down $FirstPacketLossTime when threshold packetloss is detected for the first time
    [ "$FirstPacketLossTime" -eq 0 ] && FirstPacketLossTime=$(($(date +%s)))
    #Note down $PacketLossLogTimeStamp when PacketLossLogTimeStamp is 0
    [ "$PacketLossLogTimeStamp" -eq 0 ] && PacketLossLogTimeStamp=$(($(date +%s)))
    #Note down $EthernetLogTimeStamp when EthernetLogTimeStamp is 0 and ethernet connected
    [ "$IsEthernetConnected" -eq 1 ] && [ "$EthernetLogTimeStamp" -eq 0 ] && EthernetLogTimeStamp=$(($(date +%s)))
    echo "$(/bin/timestamp) [DEBUG_NCR] checkPacketLoss: ABOVE TOLERANCE returning 1 - FirstPacketLossTime=$FirstPacketLossTime PacketLossLogTimeStamp=$PacketLossLogTimeStamp EthernetLogTimeStamp=$EthernetLogTimeStamp IsEthernetConnected=$IsEthernetConnected" >> "$logsFile"
    return 1
  fi

  #Reset tmp parameters to default values when packet loss is below threshold
  echo "$(/bin/timestamp) [DEBUG_NCR] checkPacketLoss: BELOW TOLERANCE returning 0 - resetting FirstPacketLossTime/PacketLossLogTimeStamp/IsWifiReassociated. wifiDriverErrors=$wifiDriverErrors" >> "$logsFile"
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
  echo "$(/bin/timestamp) [DEBUG_NCR] wifiReset TRIGGERED: IsWifiReset=$IsWifiReset rfcWifiResetEnable=$rfcWifiResetEnable FirstPacketLossTime=$FirstPacketLossTime WifiResetIntervalForPacketLoss=$WifiResetIntervalForPacketLoss currentTime=$currentTime packetsLostipv4=$packetsLostipv4 packetsLostipv6=$packetsLostipv6" >> "$logsFile"
  #When usr/sbin/wifi_reset.sh is missing then exit
  #Note down the time when wifi reset is done
  WifiResetTime=$(($(date +%s)))
  #Set IsWifiReset to 1 after wifi reset
  IsWifiReset=1
  StoreTotmpFile
  echo "$(/bin/timestamp) Start WiFi Reset. !!!!!!!!!!!!!!"  >> "$logsFile"
  
  systemctl restart wifi.service
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
    rfcWifiReassociateTolerance="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.WiFiReset.ReassociateTolerance 2>&1 > /dev/null)"
    if [ ! -z "$rfcWifiReassociateTolerance" ] && [ "$rfcWifiReassociateTolerance" != 0 ] ; then
      WifiReassociateTolerance="$rfcWifiReassociateTolerance"
    fi
  fi
}

#If RFC is enabled, then load the customized RFC parameters
checkRfc

#Load the contents of tmpFile
LoadFromtmpFile
echo "$(/bin/timestamp) [DEBUG_NCR] ##########################################################" >> "$logsFile"
echo "$(/bin/timestamp) [DEBUG_NCR] ###### networkConnectionRecovery.sh RUN START ######" >> "$logsFile"
echo "$(/bin/timestamp) [DEBUG_NCR] ##########################################################" >> "$logsFile"
echo "$(/bin/timestamp) [DEBUG_NCR] State loaded - IsWifiReassociated=$IsWifiReassociated IsWifiReset=$IsWifiReset FirstPacketLossTime=$FirstPacketLossTime PacketLossLogTimeStamp=$PacketLossLogTimeStamp WifiReassociateInterval=$WifiReassociateInterval WifiResetIntervalForPacketLoss=$WifiResetIntervalForPacketLoss rfcWifiResetEnable=$rfcWifiResetEnable" >> "$logsFile"

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
echo "$(/bin/timestamp) [DEBUG_NCR] Connection status - IsEthernetConnected=$IsEthernetConnected IsWifiConnected=$IsWifiConnected" >> "$logsFile"

if [ "$IsEthernetConnected" -eq 1 ] ; then
  checkPacketLoss V4
  packetLoss_v4=$?
  checkPacketLoss V6
  packetLoss_v6=$?
  echo "$(/bin/timestamp) [DEBUG_NCR] Ethernet packetloss results - packetLoss_v4=$packetLoss_v4 packetLoss_v6=$packetLoss_v6 packetsLostipv4=$packetsLostipv4 packetsLostipv6=$packetsLostipv6" >> "$logsFile"
  if [ "$packetLoss_v4" -eq 1 ] || [ "$packetLoss_v6" -eq 1 ]; then
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
  checkPacketLoss V4
  packetLoss_v4=$?
  checkPacketLoss V6
  packetLoss_v6=$?
  echo "$(/bin/timestamp) [DEBUG_NCR] WiFi packetloss results - packetLoss_v4=$packetLoss_v4 packetLoss_v6=$packetLoss_v6 packetsLostipv4=$packetsLostipv4 packetsLostipv6=$packetsLostipv6" >> "$logsFile"
  if [ "$packetLoss_v4" -eq 1 ] || [ "$packetLoss_v6" -eq 1 ]; then
    currentTime=$(($(date +%s)))
    #Print debug logs during a packetloss after $PacketLossLoggingInterval
    if [ "$(($PacketLossLogTimeStamp+$PacketLossLoggingInterval))" -le "$currentTime" ] ; then
      PacketLossLogTimeStamp=0
      printLogsDuringPacketLoss
    fi
    echo "$(/bin/timestamp) [DEBUG_NCR] Recovery decision - IsWifiReassociated=$IsWifiReassociated IsWifiReset=$IsWifiReset rfcWifiResetEnable=$rfcWifiResetEnable" >> "$logsFile"
    echo "$(/bin/timestamp) [DEBUG_NCR] Recovery decision - FirstPacketLossTime=$FirstPacketLossTime PacketLossLogTimeStamp=$PacketLossLogTimeStamp WifiReassociateInterval=$WifiReassociateInterval TimeToReassociate=$((FirstPacketLossTime+WifiReassociateInterval)) currentTime=$currentTime" >> "$logsFile"
    echo "$(/bin/timestamp) [DEBUG_NCR] Recovery decision - WifiResetIntervalForPacketLoss=$WifiResetIntervalForPacketLoss TimeToReset=$((FirstPacketLossTime+WifiResetIntervalForPacketLoss))" >> "$logsFile"
    if [ "$IsWifiReassociated" -eq 0 ] && [ "$IsWifiReset" -eq 0 ] ; then
      echo "$(/bin/timestamp) [DEBUG_NCR] Recovery path: reassociate candidate (IsWifiReassociated=0 IsWifiReset=0) - TimeToReassociate=$((FirstPacketLossTime+WifiReassociateInterval)) <= currentTime=$currentTime?" >> "$logsFile"
      #If packetloss happens, do a wifi reassociate after $WifiReassociateInterval
      [ "$(($FirstPacketLossTime+$WifiReassociateInterval))" -le "$currentTime" ] && wifiReassociate
    elif [ "$IsWifiReset" -eq 0 ] && [ "$rfcWifiResetEnable" = "true" ] ; then
      echo "$(/bin/timestamp) [DEBUG_NCR] Recovery path: reset candidate (already reassociated, rfcWifiResetEnable=true) - TimeToReset=$((FirstPacketLossTime+WifiResetIntervalForPacketLoss)) <= currentTime=$currentTime?" >> "$logsFile"
      #If wifi reassociate also does not help packetloss, then do a wifi reset after $WifiResetIntervalForPacketLoss
      [ "$(($FirstPacketLossTime+$WifiResetIntervalForPacketLoss))" -le "$currentTime" ] && wifiReset
    else
      echo "$(/bin/timestamp) [DEBUG_NCR] Recovery path: NO ACTION - IsWifiReassociated=$IsWifiReassociated IsWifiReset=$IsWifiReset rfcWifiResetEnable=$rfcWifiResetEnable" >> "$logsFile"
    fi
  fi
fi
checkDnsFile
#Store tmp variables to tmpFile
StoreTotmpFile
