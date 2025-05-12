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


eMMCFW_UPGRADE_RETRY_COUNT_FILE=/opt/eMMCFwCount
eMMCFW_UPGRADE_VERS_FILE=/opt/eMMCFwVers
MAX_RETRY_COUNT=5

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

if [ ! -f $eMMCFW_UPGRADE_RETRY_COUNT_FILE ]; then
     touch $eMMCFW_UPGRADE_RETRY_COUNT_FILE
fi

if [ ! -f $eMMCFW_UPGRADE_VERS_FILE ]; then
     touch $eMMCFW_UPGRADE_VERS_FILE
fi


SWLOG_FILE=/opt/logs/swupdate.log
if [ ! -f $SWLOG_FILE ]; then
     touch $SWLOG_FILE
fi

# Check if we need a eMMC Firmware Upgrade.Assuming version will have
# only numbers not special Characters.

version=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.eMMCFirmware.Version 2>&1 > /dev/null`
count=`cat $eMMCFW_UPGRADE_RETRY_COUNT_FILE`
if [ -z $count ]; then
    count=0
    echo $count > $eMMCFW_UPGRADE_RETRY_COUNT_FILE
fi


echo "`/bin/timestamp` : eMMC Firmware version from RFC: $version." >> $SWLOG_FILE
echo "`/bin/timestamp` : eMMC_FW_VERS_RFC_split:$version." >> $SWLOG_FILE

if [ "$version" != "" ] && [ ! -f /tmp/.eMMC_Upgrade ]; then
     currVers=`mmc extcsd read /dev/mmcblk0 |grep Version`
# The command returns version Ex: "eMMC Firmware Version: 33040117%P"
# So get only the version number excluding all.

     currVers=`echo $currVers | awk -F'[: %]' '{print $(NF-1)}'`
     echo "`/bin/timestamp` : Current running eMMC FW Version:  $currVers" >> $SWLOG_FILE
     echo "`/bin/timestamp` : Current_eMMC_FW_Version_split:$currVers" >> $SWLOG_FILE
     t2ValNotify "emmcVer_split" "$currVers"

     prevUpgVers=`cat $eMMCFW_UPGRADE_VERS_FILE`
     if [ -z $prevUpgVers ]; then
           echo $count > $eMMCFW_UPGRADE_RETRY_COUNT_FILE
     elif [ "$currVers" != "$prevUpgVers" ]; then
          echo "`/bin/timestamp` : CurrVersion($currVers) & PrevUpgradedVersion($prevUpgVers) are NOT same" >> $SWLOG_FILE
          echo "`/bin/timestamp` : WARNING: Previous eMMC Upgrade($prevUpgVers) may have FAILED." >> $SWLOG_FILE
          echo "`/bin/timestamp` : Current Retry Count is $count. Max=5" >> $SWLOG_FILE
          if [ $count -eq 0 ]; then
# Save the current fluf files version names
              fwname="ls /usr/bin/*.fluf"
              eval $fwname > /opt/FwVersions 2>&1
              echo "`/bin/timestamp` : Saving current image Fluf files into /opt/FwVersions" >> $SWLOG_FILE
              echo "`/bin/timestamp` : `cat /opt/FwVersions` " >> $SWLOG_FILE
          fi
          count=`expr $count + 1`
          echo $count > $eMMCFW_UPGRADE_RETRY_COUNT_FILE
     else
#Versions are same implies Previous FW upgrade was successfull. Reset the retry count
          count=0
          echo $count > $eMMCFW_UPGRADE_RETRY_COUNT_FILE
# Remove the version names file if present
          if [ -f /opt/FwVersions ]; then
               rm -rf /opt/FwVersions
          fi
     fi

     if [ $count -gt $MAX_RETRY_COUNT ]; then
# We might have good firmware image, so compare the previous image fluf's with current.
          curfw="ls /usr/bin/*.fluf"
          eval $curfw > /tmp/curFw 2>&1
          diff /opt/FwVersions /tmp/curFw 2>&1 > /tmp/Fwdiff
          cmp=$?
          if [ $cmp -eq 1 ]; then
# Fluf files are different implies we may have good FW. Resetting the counter to zero so that upgrade happens.
               echo "`/bin/timestamp` : Count($count) >=5, Fluf files are different. Reset the count to Zero" >> $SWLOG_FILE
               echo "`/bin/timestamp` : `cat /tmp/Fwdiff` " >> $SWLOG_FILE
               count=0
               echo $count > $eMMCFW_UPGRADE_RETRY_COUNT_FILE
          fi
     fi

     if [ "$version" != "$currVers" ] && [ $count -lt $MAX_RETRY_COUNT ]; then
           touch /tmp/.eMMC_Upgrade
# Upgrade the firmware
           if [ -f /usr/bin/*_$version.fluf ]; then
                 echo "`/bin/timestamp` : Upgrading Firmware from $currVers to $version.Retry Count= $count" >> $SWLOG_FILE
                 mmc ffu /usr/bin/*_$version.fluf /dev/mmcblk0
                 status=$?
                 echo "`/bin/timestamp` : Upgrade Return Status: $status" >> $SWLOG_FILE
                 if [ $status -eq 0 ]; then
                      echo "`/bin/timestamp` : Firmware Upgrade Successful status: $status" >> $SWLOG_FILE
                      echo "`/bin/timestamp` : FW_Upgrade_Successful_split:$status" >> $SWLOG_FILE
                      echo $version > $eMMCFW_UPGRADE_VERS_FILE
                 else
                      echo "`/bin/timestamp` : Firmware Upgrade Failed status: $status" >> $SWLOG_FILE
                      echo "`/bin/timestamp` : FW_Upgrade_Failed_split:$status" >> $SWLOG_FILE
# Retry counter increment
                      count=`expr $count + 1`
                      echo $count > $eMMCFW_UPGRADE_RETRY_COUNT_FILE
                 fi
            else
                 echo "`/bin/timestamp` : Upgrade $version DOES NOT EXIST. Cannot Upgrade: " >> $SWLOG_FILE
                 echo "`/bin/timestamp` : FILE_DOES_NOT_EXIST_split:$version" >> $SWLOG_FILE
                 t2ValNotify "emmcNoFile_split" "$version"
            fi
      else
            echo "`/bin/timestamp` : Cannot Upgrade. Either versions($version & $currVers) are same or Retry count($count) exceeded 5" >> $SWLOG_FILE
            t2CountNotify "SCARD_INFO_emmc_noUpgd"
      fi
else
      echo "`/bin/timestamp` : Cannot Upgrade. RFC version string is NULL or Upgrade already issued." >> $SWLOG_FILE
fi

