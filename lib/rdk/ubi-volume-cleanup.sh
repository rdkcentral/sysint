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

# input argument validation
inputArg=$1
if [ "$inputArg" = "" ];then
      echo "Usage: $0 <partition>"
fi

if [ ! -f /etc/os-release ]; then
      SCRUB_BIN_LOC=/usr/local/bin
else
      SCRUB_BIN_LOC=/usr/bin
fi

partition_cleanup() 
{
    rm -rf $2/*
    mountpoint=`mount | cut -d ' ' -f3 | grep $2`
    if [ "$mountpoint" != "" ]; then
        fuser -mk $2; umount $2
    fi

    if [ "$3" != "" ]; then
        mountpoint=`mount | cut -d ' ' -f3 | grep $3`
        if [ "$mountpoint" != "" ]; then
             fuser -mk $3; umount $3
       fi
    fi

    sleep 2
    ubi_device="ubi0"
    if [ "$1" == "$TRANSFER_PARTITION" ]; then
        ubi_device="ubi1"
    fi
    ubirmvol /dev/$ubi_device -N $1

    sleep 1
}


if [ "$inputArg" = "$PERSISTENT_PARTITION" ];then
    # persistent partition cleanup
    DIR_PATH="/opt/persistent"
    NVRAM_PATH="/mnt/nvram1"
    partition_cleanup $PERSISTENT_PARTITION $DIR_PATH $NVRAM_PATH

elif [ "$inputArg" = "$AUTH_DATA_PARTITION" ];then
    # authentication data partition cleanup
    DIR_PATH="/opt/www"
    NVRAM_PATH="/mnt/nvram2"
    partition_cleanup $AUTH_DATA_PARTITION $DIR_PATH $NVRAM_PATH

elif [ "$inputArg" = "$OPT_PARTITION" ];then
    # persistent partition cleanup
    DIR_PATH="/opt"
    NVRAM_PATH="/mnt/nvram"
	  
    #Umount dependencies
    fuser -mk /opt/secure; umount /opt/secure
    fuser -mk /var/lib; umount /var/lib
    fuser -mk /var/volatile/log; umount /var/volatile/log

    partition_cleanup $OPT_PARTITION $DIR_PATH $NVRAM_PATH 

elif [ "$inputArg" = "$TRANSFER_PARTITION" ]; then
    # common partition cleanup
    DIR_PATH="/common"
    partition_cleanup $TRANSFER_PARTITION $DIR_PATH

elif [ "$inputArg" = "PDRI-cleanup" ];then
      # PDRI image cleanup
      if [ -f $SCRUB_BIN_LOC/mfr_deletePDRI ]; then
           echo "Erasing the PDRI image"
           $SCRUB_BIN_LOC/mfr_deletePDRI
      fi

elif [ "$inputArg" = "scrubAllBanks" ];then
      echo "Erasing the images from the banks"
      # Banks erase for image cleanup
      if [ "$VENDOR_FACTORY_RESET" == "true" ]; then
           /lib/rdk/vendor-factory-reset.sh PCI
      fi 
      if [ -f $SCRUB_BIN_LOC/mfr_scrubAllBanks ]; then
           $SCRUB_BIN_LOC/mfr_scrubAllBanks
      fi

elif [ "$inputArg" = "$SDCARD" ];then

      # unmount the SDCARD-MMCBLK0P1 device
      if mountpoint -q $SDCARD
      then
          sleep 2
          output=`umount -l $SDCARD`
          if [ "$output" != "" ]; then
              echo "sdcard(mmcblk0p1) device unmount Error..!"
          else
              echo "sdcard(mmcblk0p1) device unmount Success..!"
          fi
      else
          echo "sdcard(mmcblk0p1) device NOT mounted...!"
      fi
else
     echo "Unknown argument for $0"
fi


