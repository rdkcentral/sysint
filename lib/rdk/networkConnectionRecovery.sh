#!/bin/sh
set -x
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
ipv4PacketLoss=0
ipv6PacketLoss=0
ipv4GwPresent=0
ipv6GwPresent=0
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

# Append a timestamped line to $logsFile.
log()
{
  echo "$(/bin/timestamp) $*" >> "$logsFile"
}

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
          log "TELEMETRY_WIFI_CONNECTED_LNF"
          #Reset count when lnf ssid is connected
          count=0
          t2CountNotify "SYST_INFO_WIFIConn"
        else
          #Skip printing wifi not connected log for the first time
          [ $count -gt 0 ] && log "TELEMETRY_WIFI_NOT_CONNECTED"
          count=$((count + 1))
        fi
        return 0
      else
        log "TELEMETRY_WIFI_CONNECTED"
        #Reset count when connectivity is good
        count=0
        t2CountNotify "SYST_INFO_WIFIConn"
        return 0
      fi
    else
      log "TELEMETRY_ETHERNET_CONNECTED"
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
  log "Packet Loss WiFi Reassociating"
  t2CountNotify "WIFIV_ERR_reassoc"
  wpa_cli reassociate
  #set IsWifiReassociated to 1 after wifi reassociation
  IsWifiReassociated=1
}

checkWifiDrvErrors()
{
  dir=$(find /sys/kernel/debug/ieee80211  -type d -maxdepth 1 | sed '1d')
  if [ -z "$dir" ] ; then
    log "phy directory not in /sys/kernel/debug/ieee80211"
  elif [ ! -f "$dir"/ath10k/fw_stats ]; then
    log "fw_stats file not in /sys/kernel/debug/ieee80211/$dir/ath10k/"
  else
    cat "$dir"/ath10k/fw_stats > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      log "Cant open file /sys/kernel/debug/ieee80211/$dir/ath10k/ status=$?"
    else
      #Reset tmp variables to 0 when there is no wifi driver issue
      FirstWifiDriverIssueTime=0
      [ "$IsWifiReassociated" -eq 0 ] && IsWifiReset=0 #$IsWifiReassociated=1 indicates wifi reassociation done already and still packetloss happens hence don't make IsWifiReset=0
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
  packetLoss=""
  currentTime=$(($(date +%s)))

  if [ -f "/tmp/checkpacketloss" ] ; then
    if [ "$version" = "V4" ] ; then
      gwIp=$(cat /tmp/checkpacketloss)
      pingCmd="ping"
    else
      gwIp=""
    fi
  else
    if [ "$version" = "V4" ] ; then
      gwIp=$(/sbin/ip -4 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}')
      gwIp_interface=$(/sbin/ip -4 route | awk '/default/ { print $5 }' | head -n1 | awk '{print $1;}')
      pingCmd="ping -I $gwIp_interface"
    elif [ "$version" = "V6" ] ; then
      gwIp=$(/sbin/ip -6 route | awk '/default/ { print $3 }' | head -n1 | awk '{print $1;}')
      gwIp_interface=$(/sbin/ip -6 route | awk '/default/ { print $5 }' | head -n1 | awk '{print $1;}')
      pingCmd="ping6 -I $gwIp_interface"
    fi
  fi

  if [ "$gwIp" != "" ] && [ "$gwIp" != "dev" ] ; then
    gwResponse=$($pingCmd -c "$pingCount" -i "$pingInterval" "$gwIp")
    packetLoss=$(echo "$gwResponse" | grep "packet"|awk '{print $7}'|cut -d'%' -f1)

    if [ "$version" = "V4" ] ; then
      ipv4PacketLoss=$packetLoss
      ipv4GwPresent=1
    elif [ "$version" = "V6" ] ; then
      ipv6PacketLoss=$packetLoss
      ipv6GwPresent=1
    fi

    gwResponseTime=$(echo "$gwResponse" | sed '$!d;s|.*/\([0-9.]*\)/.*|\1|')
    #Notify 100% gateway packet loss on every run, independent of GatewayLoggingInterval,
    #so the marker is not skipped when the run cadence is shorter than GatewayLoggingInterval.
    if [ "$packetLoss" = "100" ] ; then
      log "$version SYST_WARN_GW100PERC_PACKETLOSS, gateway $gwIp"
      t2CountNotify "SYST_WARN_GW100PERC_PACKETLOSS"
    fi
    if [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] ; then
      if [ "$packetLoss" = "100" ] ; then
        log "TELEMETRY_GATEWAY_RESPONSE_TIME:NR,$gwIp"
      else
        log "TELEMETRY_GATEWAY_RESPONSE_TIME:$gwResponseTime,$gwIp"
      fi
      log "TELEMETRY_GATEWAY_PACKET_LOSS:$packetLoss,$gwIp"
    fi
  else
    if [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] ; then
      log "TELEMETRY_GATEWAY_NO_ROUTE_$version"
      t2CountNotify "WIFIV_INFO_NO${version}ROUTE"
    fi
  fi

  [ "$(($GatewayLogTimeStamp+$GatewayLoggingInterval))" -le "$currentTime" ] && GatewayLogTimeStamp=$(($(date +%s)))

  #Send telemetry notification for 20%,30%....90% packet loss
  if [ -n "$packetLoss" ] ; then
    if [ "$packetLoss" -gt "$lossThreshold" ] ; then
      log "$version packet loss more than $lossThreshold% observed (packetLoss=$packetLoss)"
      if [ "$packetLoss" -ne 100 ] ; then
        for i in {1..9}; do
            if [ "$packetLoss" -ge $((i*10)) ] && [ "$packetLoss" -lt $((i*10+10)) ] ; then
              log "$version packet loss is WIFIV_WARN_PL_$((i*10))PERC"
              t2CountNotify "WIFIV_WARN_PL_"$((i*10))"PERC"
              break
            fi
        done
      fi
    elif [ "$packetLoss" -ne 0 ] ; then
      #Send telemetry notification for 10% packet loss
      log "$version packet loss is WIFIV_WARN_PL_10PERC"
      t2CountNotify "WIFIV_WARN_PL_10PERC"
    fi
  fi

  #Evaluate the packet-loss trigger only on the V6 call, once both stacks have
  #been probed (globals set during the preceding V4 call persist here). Classify
  #each routed stack as good (loss < tolerance = acceptable connectivity) or bad
  #(loss >= tolerance); a stack with no default route or an unparseable ping
  #result is ignored. Because any acceptable stack means we should not tear down
  #L2, recovery is warranted only when NO routed stack is good and at least one
  #routed stack is bad:
  #  - dual-stack (IPv4 + IPv6): both must be at/above tolerance to return 1
  #  - IPv4-only              : IPv4 packet loss alone controls the result
  #  - IPv6-only              : IPv6 packet loss alone controls the result
  if [ "$version" = "V6" ] ; then
    anyGood=0
    anyBad=0
    if [ "$ipv4GwPresent" -eq 1 ] && [ -n "$ipv4PacketLoss" ] ; then
      if [ "$ipv4PacketLoss" -ge "$WifiReassociateTolerance" ] ; then anyBad=1 ; else anyGood=1 ; fi
    fi
    if [ "$ipv6GwPresent" -eq 1 ] && [ -n "$ipv6PacketLoss" ] ; then
      if [ "$ipv6PacketLoss" -ge "$WifiReassociateTolerance" ] ; then anyBad=1 ; else anyGood=1 ; fi
    fi

    if [ "$anyGood" -eq 0 ] && [ "$anyBad" -eq 1 ] ; then
      #No routed stack has acceptable connectivity and at least one is bad -> recover.
      log "Packet loss is observed on all routed IP stacks (ipv4Route=$ipv4GwPresent ipv6Route=$ipv6GwPresent ipv4PacketLoss=$ipv4PacketLoss ipv6PacketLoss=$ipv6PacketLoss tolerance=${WifiReassociateTolerance}%)"
      #Note down $FirstPacketLossTime when threshold packetloss is detected for the first time
      [ "$FirstPacketLossTime" -eq 0 ] && FirstPacketLossTime=$(($(date +%s)))
      #Note down $PacketLossLogTimeStamp when PacketLossLogTimeStamp is 0
      [ "$PacketLossLogTimeStamp" -eq 0 ] && PacketLossLogTimeStamp=$(($(date +%s)))
      #Note down $EthernetLogTimeStamp when EthernetLogTimeStamp is 0 and ethernet connected
      [ "$IsEthernetConnected" -eq 1 ] && [ "$EthernetLogTimeStamp" -eq 0 ] && EthernetLogTimeStamp=$(($(date +%s)))
      return 1
    elif [ "$anyGood" -eq 1 ] ; then
      #At least one routed stack has acceptable connectivity (below tolerance) -> clear packet-loss state.
      log "[DEBUG_NCR] checkPacketLoss: acceptable connectivity on a routed stack (ipv4PacketLoss=$ipv4PacketLoss ipv6PacketLoss=$ipv6PacketLoss) - resetting FirstPacketLossTime/PacketLossLogTimeStamp/IsWifiReassociated. wifiDriverErrors=$wifiDriverErrors"
      FirstPacketLossTime=0
      PacketLossLogTimeStamp=0
      EthernetLogTimeStamp=0
      IsWifiReassociated=0
      [ "$wifiDriverErrors" -eq 0 ] && IsWifiReset=0 #Make IsWifiReset=0 only when there is no wifidriverissue
    else
      #No routed stack was measurable (no route / unparseable) -> skip reset so a total loss of
      #routes does not wipe an in-progress packet-loss timer.
      log "[DEBUG_NCR] checkPacketLoss: no routed-stack measurement (version=$version) - skipping reset. wifiDriverErrors=$wifiDriverErrors"
    fi
  fi

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
  log "Start WiFi Reset. !!!!!!!!!!!!!!"
  
  systemctl restart wifi.service
  log "WiFi Reset done as part of  Recovery. !!!!!!!!!!!!!!"
  exit 0
}

checkDnsFile()
{
  if [ -f "$dnsFile" ] ; then
    if [ $(tr -d ' \r\n\t' < $dnsFile | wc -c ) -eq 0 ] ; then
      log "DNS File($dnsFile) is empty"
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
          log "Restarting udhcpc to recover"
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
    log "DNS File is not there $dnsFile"
  fi
}

checkRfc()
{
  rfcWifiResetEnable="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.WiFiReset.Enable 2>&1 > /dev/null)"
  if [ "$rfcWifiResetEnable" = "true" ] ; then
    log "WiFiReset RFC is true "
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

  rfcWifiReassociateTolerance="$(tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.WiFiReset.ReassociateTolerance 2>&1 > /dev/null)"
  if [ ! -z "$rfcWifiReassociateTolerance" ] && [ "$rfcWifiReassociateTolerance" != 0 ] ; then
    WifiReassociateTolerance="$rfcWifiReassociateTolerance"
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
    log "Skip all checks since wifi reset is done recently"
    exit 0
  fi
fi

checkEthernetConnected
IsEthernetConnected=$?
checkWifiConnected
IsWifiConnected=$?

if [ "$IsEthernetConnected" -eq 1 ] ; then
  checkPacketLoss V4
  packetLoss_v4=$?
  checkPacketLoss V6
  packetLoss_v6=$?
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
  if [ "$packetLoss_v4" -eq 1 ] || [ "$packetLoss_v6" -eq 1 ]; then
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
