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

echo "Factory Reset:Clearing Remote Pairing Data"
touch /tmp/Dropbear_restart_disabled
# clear pairing data
if [ -f /usr/bin/controlFactory ]; then
    controlFactory -f ;                  # unpair controllers
fi
# shut down controlMgr
/bin/systemctl stop ctrlm-main ;
if [ -f /opt/ctrlm.back ]; then rm -f /opt/ctrlm.back; fi # remove symlink
if [ -f /opt/ctrlm.sql ]; then rm -f /opt/ctrlm.sql; fi # remove symlink
if [ -f /opt/secure/ctrlm.back ]; then rm -f /opt/secure/ctrlm.back; fi # remove original file
if [ -f /opt/secure/ctrlm.sql ]; then rm -f /opt/secure/ctrlm.sql; fi # remove original file

if [ -f /etc/os-release ];then
    echo "Factory Reset:Stopping the services"
   
    if [ "$WHITEBOX_ENABLED" == "true" ]; then
        /bin/systemctl stop whitebox.service
    fi
    /bin/systemctl stop sysmgr.service
    /bin/systemctl stop storagemgrmain.service
    /bin/systemctl stop socprovisioning.service
    /bin/systemctl stop rf4ce.service
    /bin/systemctl stop lighttpd.service
    /bin/systemctl stop dump-backup.service
    /bin/systemctl stop dnsmasq.service
    /bin/systemctl stop syslog.socket
    if [ "$DOBBY_ENABLED" == "true" ]; then
        /bin/systemctl stop dobby.service
    fi
    if [ "$DEVICE_TYPE" != "mediaclient" ];then
        /bin/systemctl stop cecdaemon.service
        /bin/systemctl stop cecdevmgr.service
        /bin/systemctl stop xcal-device.path
        /bin/systemctl stop xcal-device.service
    else
        if [ "$WIFI_SUPPORT" == "true" ];
        then
            /bin/systemctl stop wpa_supplicant.service
        fi
    fi
    if [ -e /lib/rdk/device-specific-reset.sh ]; then
        echo "Factory Reset: Stop services specific to the device"
	/lib/rdk/device-specific-reset.sh "FACTORY" "STOP-SERVICE"
    fi
fi

echo "Factory Reset:Starting file cleanUp"
# persistent data cleanup
if [ -d /opt/persistent ]; then
    find /opt/persistent -mindepth 1 -maxdepth 1 ! -name 'store-mode-video' -exec rm -rf {} \;
fi
if [ -d /tmp/mnt/diska3/persistent ]; then
    find /tmp/mnt/diska3/persistent -mindepth 1 -maxdepth 1 ! -name 'store-mode-video' -exec rm -rf {} \;
fi
rm -rf /opt/secure/persistent/rdkservicestore
rm -rf /opt/secure/persistent/rdkservicestore-journal
rm -rf /opt/secure/persistent/System

# authservice data cleanup
if [ -d /opt/www/authService ]; then rm -rf /opt/www/authService/*; fi
if [ -d /mnt/nvram2/authService ]; then rm -rf /mnt/nvram2/authService/*; fi

# opt data cleanup
if [ -d /opt/logs ]; then rm -rf /opt/logs/*; fi
if [ -d /var/logs ]; then rm -rf /var/logs/*; fi

# Erasing the override configurations
rm -rf /opt/*.conf
rm -rf /opt/*.conf.*
rm -rf /opt/*.ini
if [ -f /opt/no-upnp ]; then rm -rf /opt/no-upnp; fi
if [ -f /opt/dcm.properties ];then rm -rf /opt/dcm.properties ; fi
if [ -d /opt/wifi ]; then rm -rf /opt/wifi/*;fi
if [ -d /opt/NetworkManager/system-connections ]; then rm -rf /opt/NetworkManager/system-connections/*; fi
if [ -d /nvram/NetworkManager/system-connections ]; then rm -rf /nvram/NetworkManager/system-connections/*; fi
if [ -d /var/lib/NetworkManager/system-connections ]; then rm -rf /var/lib/NetworkManager/system-connections/*; fi
if [ -d /opt/secure/wifi ]; then rm -rf /opt/secure/wifi/*;fi
if [ -f /opt/DCMscript.out ]; then rm -f /opt/DCMscript.out;fi
if [ -d /opt/QT ]; then rm -rf /opt/QT/*;fi
if [ -d /opt/corefiles ]; then rm -rf /opt/corefiles/*;fi
if [ -d /opt/corefiles_back ]; then rm -rf /opt/corefiles_back/*;fi
if [ -d /opt/secure/corefiles ]; then rm -rf /opt/secure/corefiles/*;fi
if [ -d /opt/secure/corefiles_back ]; then rm -rf /opt/secure/corefiles_back/*;fi
if [ -e /opt/.gstreamer ]; then rm -rf /opt/.gstreamer; fi
if [ -d /opt/ds ]; then rm -rf /opt/ds/*;fi
if [ -f /opt/hn_service_settings.conf ]; then rm -f /opt/hn_service_settings.conf;fi
if [ -f /opt/lof.eth1 ]; then rm -f /opt/lof.eth1;fi
if [ -f /opt/logFileBackup ]; then rm -f /opt/logFileBackup;fi
if [ -d /opt/minidumps ]; then rm -rf /opt/minidumps/*;fi
if [ -d /opt/secure/minidumps ]; then rm -rf /opt/secure/minidumps/*;fi
if [ -f /opt/uimgr_settings.bin ]; then rm -f /opt/uimgr_settings.bin;fi
if [ -f /opt/uploadSTBLogs.out ]; then rm -f /opt/uploadSTBLogs.out;fi
if [ -d /opt/upnp ]; then rm -rf /opt/upnp/*;fi
if [ -L /opt/www/htmldiag ]; then rm -f /opt/www/htmldiag;fi
if [ -f /opt/user_preferences.conf ];then rm -rf /opt/user_preferences.conf; fi
if [ -f /opt/continuewatching.json ];then rm -rf /opt/continuewatching.json ; fi
if [ -d /opt/NetworkManager ];then rm -rf /opt/NetworkManager ; fi
if [ -d /opt/secure/NetworkManager ];then rm -rf /opt/secure/NetworkManager ; fi

if [ -f /opt/secure/Apparmor_blocklist ];then rm -rf /opt/secure/Apparmor_blocklist ; fi

if [ -e /lib/rdk/device-specific-reset.sh ]; then
    echo "Factory Reset: Clean configs specific ti the device"
    /lib/rdk/device-specific-reset.sh "FACTORY" "CLEAN-CONFIG"
fi

# RFC data cleanup
if [ -d /opt/RFC ]; then rm -rf /opt/RFC; fi
if [ -d /opt/secure/RFC ]; then rm -rf /opt/secure/RFC; fi
# Downloadable certs cleanup
if [ -d /opt/dl/certs ]; then rm -rf /opt/dl/certs; fi
# Downloadable creds cleanup
if [ -d /opt/dl/lxy ]; then rm -rf /opt/dl/lxy; fi

# clear systemd settings
if [ -d /opt/systemd ]; then rm -rf /opt/systemd; fi

# Kill the nrdPluginApp first, else the /opt/netflix would be re-created by this process.
killall -s SIGKILL nrdPluginApp
if [ -e /opt/netflix ]; then rm -rf /opt/netflix; fi
if [ -d "${SD_CARD_APP_MOUNT_PATH}/netflix" ]; then rm -rf "${SD_CARD_APP_MOUNT_PATH}/netflix"; fi
if [ -d "${SD_CARD_MOUNT_PATH}/netflix" ]; then rm -rf "${SD_CARD_MOUNT_PATH}/netflix"; fi
# BT data cleanup
if [ -d /opt/lib/bluetooth ]; then rm -rf /opt/lib/bluetooth; fi

# remove all apps data only if path is non empty and exits
if [ -d "$SD_CARD_APP_MOUNT_PATH" ]; then rm -rf $SD_CARD_APP_MOUNT_PATH/*; fi
if [ -d "$HDD_APP_MOUNT_PATH" ]; then rm -rf $HDD_APP_MOUNT_PATH/*; fi

rm -rf /opt/secure/securityagent

if [ "$DEVICE_TYPE" = "mediaclient" ];then
     WIFI_BIN_LOC=${WIFI_BIN_LOC:=/usr/bin/}

    # Wifi data cleanup
     if [ -f $WIFI_BIN_LOC/mfr_wifiEraseAllData ]; then
         $WIFI_BIN_LOC/mfr_wifiEraseAllData
     fi
     
     if [ "$SD_CARD_TYPE" = "EMMC" ]; then
         if [ -f /lib/rdk/emmc_format.sh ]; then
             sh /lib/rdk/emmc_format.sh
         fi
     else
         if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then

             if [ "$SDCARD" != "" ]; then
                 sh /lib/rdk/ubi-volume-cleanup.sh $SDCARD
             fi
             
             if [ "$PERSISTENT_PARTITION" != "" ]; then
                 sh /lib/rdk/ubi-volume-cleanup.sh $PERSISTENT_PARTITION
             fi

             if [ "$AUTH_DATA_PARTITION" != "" ]; then
                 sh /lib/rdk/ubi-volume-cleanup.sh $AUTH_DATA_PARTITION
             fi

             if [ "$OPT_PARTITION" != "" ]; then
                 sh /lib/rdk/ubi-volume-cleanup.sh $OPT_PARTITION
             fi
         
             if [ "$TRANSFER_PARTITION" != "" ]; then
                 sh /lib/rdk/ubi-volume-cleanup.sh $TRANSFER_PARTITION
             fi
         
         fi
     fi
     
     if [ -f /lib/rdk/ubi-volume-cleanup.sh ];then
         sh /lib/rdk/ubi-volume-cleanup.sh "scrubAllBanks"
     fi

     sleep 1
     sh /rebootNow.sh -s FactoryReset -o "Rebooting the box after Factory Reset Process..."

else

     sleep 1
     echo 0 > /opt/.rebootFlag
     echo `/bin/timestamp` ---- Rebooting due to Factory Reset process ---- >> /opt/logs/ocapri_log.txt
     /hrvcoldinit3.31 120 2
fi

exit 0

