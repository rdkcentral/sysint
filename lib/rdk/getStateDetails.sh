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

DEVICE_PROPERTY_FILE="/tmp/common.properties"

. /etc/device.properties
# get eSTB IP address

getHDMIStatus()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 127.0.0.1 OC-STB-HOST-MIB::ocStbHostDVIHDMIConnectionStatus | cut -d "=" -f2 |  sed 's/[ ]*//'
}

getHDCPStatus()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 127.0.0.1 OC-STB-HOST-MIB::ocStbHostDVIHDMIHDCPStatus | cut -d "=" -f2 |  sed 's/[ ]*//'
}

getEDIDStatus()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 127.0.0.1 OC-STB-HOST-MIB::ocStbHostDVIHDMIEdidVersion | cut -d "=" -f2 |  sed 's/[ ]*//'
}

getCASystem()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 127.0.0.1 ocStbHostCardMfgId | cut -d "=" -f2 |  sed 's/[ ]*//'
}

getCMACStatus()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk  -OQqx -Ci -v 2c -c "$snmpCommunityVal" 127.0.0.1 OC-STB-HOST-MIB::ocStbHostSoftwareApplicationInfoTable | grep Barcelona | awk '{print $5}'
}
getFWDownloadStatus()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  #snmpwalk -v 2c -c public 127.0.0.1 swUpdateStatus | awk '{print $4}'
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 192.168.100.1 docsDevSwOperStatus | awk '{print $3}'
}

getIPAddress()
{
    interface=`cat $DEVICE_PROPERTY_FILE | grep INTERFACE |cut -d "=" -f2`
    ifconfig $interface | grep inet | tr -s " " | cut -d ":" -f2 | cut -d " " -f1
}

getLANIPAddress()
{
   interface=`cat /etc/device.properties | grep ETHERNET_INTERFACE |cut -d "=" -f2` 
   ifconfig $interface | grep inet | tr -s " " | cut -d ":" -f2 | cut -d " " -f1
}
getEcmIp()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 192.168.100.1 IP-MIB::ipAdEntAddr | grep -v 127.0.0.1 | grep -v 192.168 | cut -d "=" -f2 | sed 's/[ /t]*//'
}

getDACInitTimestamp()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -OQ -v 2c -c "$snmpCommunityVal" localhost INIT-HISTORY-MIB::initTime.0 |grep UTC | awk '{print $3}'
}
getCardSerialNo()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 127.0.0.1 OC-STB-HOST-MIB::ocStbHostCCAppInfoPage.4 | cut -d">" -f28 | cut -d"<" -f1|sed 's/[ /t]*//'
}

getSTBSerialNo()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 127.0.0.1 OC-STB-HOST-MIB::ocStbHostSerialNumber| cut -d "=" -f2|sed 's/[ /t]*//'
}

getEcmMac()
{
  export SNMP_BIN_DIR=/mnt/nfs/bin/target-snmp/bin
  export MIBS=ALL
  export MIBDIRS=$SNMP_BIN_DIR/../share/snmp/mibs:/usr/share/snmp/mibs
  export PATH=$PATH:$SNMP_BIN_DIR:
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
  #snmpwalk -OQ -v 2c -c public 192.168.100.1 IF-MIB::ifPhysAddress.2 | cut -d "=" -f2 | sed 's/[ /t]*//'
  snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
  snmpwalk -O0x -m IF-MIB -v 2c -c "$snmpCommunityVal" 192.168.100.1 IF-MIB::ifPhysAddress.2 | cut -d "=" -f2 | sed 's/[ /t]*//'|cut -d " " -f2
}
## get eSTB mac address 
getMacAddress()
{
    interface=`cat $DEVICE_PROPERTY_FILE | grep INTERFACE |cut -d "=" -f2`
    ifconfig $interface | grep $interface | tr -s ' ' | cut -d ' ' -f5
}

getLocalTime()
{
   timeValue=`date`
   echo "$timeValue"
}       

getTimeZone()
{
  zoneValue=""
  if [ -f /opt/etc/saved_timezone ]; then
       zoneValue=`cat /opt/etc/saved_timezone | cut -d "=" -f2 | cut -d "," -f1`
  fi
  echo "$zoneValue"
}

getFWVersion()
{
   versionTag1=`cat $DEVICE_PROPERTY_FILE | grep FW_VERSION_TAG1 |cut -d "=" -f2`
   versionTag2=`cat $DEVICE_PROPERTY_FILE | grep FW_VERSION_TAG2 |cut -d "=" -f2`
   verStr=`cat /version.txt | grep ^imagename:$versionTag1`
   if [ $? -eq 0 ]
   then
       echo $verStr | cut -d ":" -f 2
   else
       cat /version.txt | grep ^imagename:$versionTag2 | cut -d ":" -f 2
   fi
}

# identifies whether it is a VBN or PROD build
getBuildType()
{
  cat $DEVICE_PROPERTY_FILE | grep BUILD_TYPE |cut -d "=" -f2 | tr '[:lower:]' '[:upper:]'
}

getModelNum()
{
  cat $DEVICE_PROPERTY_FILE | grep MODEL_NUM |cut -d "=" -f2
}


if [ "$1" = "CMAC" ] ; then
    status=`getCMACStatus`
    if [ "X$status" == "X" ] ; then
        echo 0 > /tmp/.$1
    elif [ "$status" = "loaded" ] ; then
          echo 1 > /tmp/.$1
    elif [ "$status" = "notLoaded" ] ; then
          echo 0 > /tmp/.$1
    elif [ "$status" = "paused" ] ; then
          echo 3 > /tmp/.$1
    elif [ "$status" = "running" ] ; then
          echo 2 > /tmp/.$1
    elif [ "$status" = "destroyed" ] ; then
          echo 4 > /tmp/.$1
    else
          echo 0 > /tmp/.$1
    fi
elif [ "$1" = "com.comcast.tune_ready" ] ; then
      if [ -f "/tmp/si_aquired" -a -f "$APP_PERSISTENT_PATH/usr/1112/703e/proxy-is-up"  ] ; then
        echo 1 > /tmp/.$1
      else
        echo 0 > /tmp/.$1
    fi
elif [ "$1" = "com.comcast.video_presenting" ] ; then
    if [ -f "/tmp/ocap_video_is_up" ] ; then
      echo 1 > /tmp/.$1
    else
      echo 0 > /tmp/.$1
    fi
elif [ "$1" = "HDMI_OUT"  ] ; then
    status=`getHDMIStatus`
    if [ "$status" = "true" ] ; then
      echo 1 > /tmp/.$1
    else
      echo 0 > /tmp/.$1
    fi
elif [ "$1" = "HDCP_ENABLED"  ] ; then
    status=`getHDCPStatus`
    if [ "$status" = "true" ] ; then
      echo 1 > /tmp/.$1
    else
      echo 0 > /tmp/.$1
    fi
elif [ "$1" = "HDMI_EDID_READ"  ] ; then
    status=`getEDIDStatus`
    if [ "$status" != "0.0" ] ; then
      echo 1 > /tmp/.$1
    else
      echo 0 > /tmp/.$1
    fi
elif [ "$1" = "FIRMWARE_DWNLD"  ] ; then
    status=`getFWDownloadStatus`
    if [ "$status" = "inProgress" ] ; then
      echo 1 > /tmp/.$1
    elif [ "$status" = "CompleteFromMgt" o- "$status" = "CompleteFromProvisioning" ] ; then
      echo 2 > /tmp/.$1
    elif [ "$status" = "failed" ] ; then
      echo 3 > /tmp/.$1
    else
      echo 0 > /tmp/.FWDownloadStatus
    fi
elif [ "$1" = "TIME_SOURCE"  ] ; then
    #system=`getCASystem`
    system=`cat /tmp/.CA_SYSTEM`
    if [ "X$system" = "X" -o "X$system" = "X0" ] ; then
      ps | grep ntpclient | grep -v grep
      if [ $? -ne 0 ] ; then
        echo 0 > /tmp/.$1
      else
        echo 3 > /tmp/.$1
      fi
    else
      echo 1 > /tmp/.$1
    fi
elif [ "$1" = "TIME_ZONE" ] ; then
  zone=`getTimeZone`
  echo "zone = $zone"
  if [ "X$zone" == "X" ] ; then
      echo 0 > /tmp/.$1
  else
      echo 1 > /tmp/.$1
  fi
elif [ "$1" = "CA_SYSTEM"  ] ; then
    system=`getCASystem`
    if [ "X$system" = "X" ] ; then
      echo 0 > /tmp/.$1
    elif [ "$system" = "\"00 00 \"" ] ; then
      echo 1 > /tmp/.$1
    else
      echo 2 > /tmp/.$1
    fi
elif [ "$1" = "ESTB_IP" ] ; then
    status=`getIPAddress`
    if [ $status ] ; then
      echo 1 > /tmp/.$1
    else
      echo 0 > /tmp/.$1
    fi
elif [ "$1" = "ECM_IP" ] ; then
    status=`getEcmIp`
    if [ $status ] ; then
      echo 1 > /tmp/.$1
    else
      echo 0 > /tmp/.$1
    fi
elif [ "$1" = "LAN_IP" ] ; then
    status=`getLANIPAddress`
    if [ $status ] ; then
      echo 2 > /tmp/.$1
    else
      echo 0 > /tmp/.$1
    fi
elif [ "$1" = "MOCA" ] ; then
  echo 0 > /tmp/.$1
elif [ "$1" = "DOCSIS" ] ; then
  echo 0 > /tmp/.$1
elif [ "$1" = "DSG_BROADCAST_CHANNEL" ] ; then
  echo 0 > /tmp/.$1
elif [ "$1" = "DSG_CA_TUNNEL" ] ; then
  echo 0 > /tmp/.$1
elif [ "$1" = "CABLE_CARD" ] ; then
  echo 0 > /tmp/.$1
elif [ "$1" = "CABLE_CARD_DWNLD" ] ; then
  echo 0 > /tmp/.$1
elif [ "$1" = "VOD_AD" ] ; then
  echo 0 > /tmp/.$1
elif [ "$1" = "DAC_INIT_TIMESTAMP" ] ; then
  echo `getDACInitTimestamp` > /tmp/.$1
elif [ "$1" = "CARD_SER_NO" ] ; then
  echo `getCardSerialNo` > /tmp/.$1
elif [ "$1" = "STB_SER_NO" ] ; then
  echo `getSTBSerialNo` > /tmp/.$1
else
  echo 0 > /tmp/.$1
fi

