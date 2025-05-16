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

if [ -f /tmp/warehouse_reset_suppress_reboot_clear ]; then
   #sending CLEAR_STARTED event
   t=`/usr/bin/WPEFrameworkSecurityUtility`; t=${t%\",*}; t=${t#*:\"}
   result=$( curl -H "Content-Type: application/json"  -H "Authorization: Bearer $t" -X POST -d '{"jsonrpc":"2.0", "id":3, "method":"org.rdk.PersistentStore.1.setValue", "params":{"namespace":"FactoryTest", "key":"FTAClearStatus", "value":"CLEAR_STARTED"}}' http://127.0.0.1:9998/jsonrpc )
   echo "Warehouse_clear set value: $result"
fi

echo "Warehouse Reset:Clearing Remote Pairing Data"
# clear pairing data
if [ -f /usr/bin/controlFactory ]; then
    controlFactory -f ;          # unpair controllers
fi

# shut down controlMgr
/bin/systemctl stop ctrlm-main ;
if [ -f /opt/ctrlm.back ]; then rm -f /opt/ctrlm.back; fi # remove symlink
if [ -f /opt/ctrlm.sql ]; then rm -f /opt/ctrlm.sql; fi # remove symlink
if [ -f /opt/secure/ctrlm.back ]; then rm -f /opt/secure/ctrlm.back; fi # remove original file
if [ -f /opt/secure/ctrlm.sql ]; then rm -f /opt/secure/ctrlm.sql; fi # remove original file

WIFI_BIN_LOC=${WIFI_BIN_LOC:=/usr/bin/}

# Wifi data cleanup
if [ -f $WIFI_BIN_LOC/mfr_wifiEraseAllData ]; then
    $WIFI_BIN_LOC/mfr_wifiEraseAllData
fi

if [ -f /etc/os-release ];then
    echo "Warehouse Reset:Stopping the services"
    /bin/systemctl stop rmfstreamer.service
    /bin/systemctl stop fog.service
    /bin/systemctl stop authservice.service
    if [ "$WHITEBOX_ENABLED" == "true" ];  then
        /bin/systemctl stop whitebox.service
    fi
    /bin/systemctl stop swupdate.service
    /bin/systemctl stop dcm-log.service
    /bin/systemctl stop storagemgrmain.service
    /bin/systemctl stop xupnp.service

    if [ "$DEVICE_TYPE" != "mediaclient" ];then
	/bin/systemctl --quiet is-active cecdaemon.path && /bin/systemctl stop cecdaemon.path
       	/bin/systemctl --quiet is-active cecdaemon.service && /bin/systemctl stop  cecdaemon.service
	/bin/systemctl --quiet is-active cecdevmgr.service && /bin/systemctl stop  cecdevmgr.service
        /bin/systemctl stop xcal-device.path
        /bin/systemctl stop xcal-device.service
    else
        /bin/systemctl stop dsmgr.service
        /bin/systemctl stop iarmbusd.service
    fi
    if [ -e /lib/rdk/device-specific-reset.sh ]; then
	    echo "Warehouse Reset: Stop services specific to the device"
	    /lib/rdk/device-specific-reset.sh "WAREHOUSE" "STOP-SERVICE"
    fi
else
    /etc/init.d/swupdate stop
fi

if [ ! -f /tmp/.warehouse-reset ]; then
     touch /tmp/.warehouse-reset
fi

echo "Warehouse Reset:Starting file cleanUp"
# /opt override cleanup
ls /opt/*.conf | grep -v receiver.conf | xargs rm
rm -rf /opt/*.ini
if [ -f /opt/hosts ]; then rm -rf /opt/hosts; fi
if [ -f /opt/dcm.properties ];then rm -rf /opt/dcm.properties ; fi
if [ -f /opt/rfc.properties ];then rm -rf /opt/rfc.properties ; fi
# power state cleanup
if [ -f /opt/uimgr_settings.bin ];then rm -rf /opt/uimgr_settings.bin; fi
if [ -f /opt/user_preferences.conf ];then rm -rf /opt/user_preferences.conf; fi
if [ -f /opt/continuewatching.json ];then rm -rf /opt/continuewatching.json ; fi

if [ -d /opt/wifi ]; then rm -rf /opt/wifi/*; fi
if [ -d /opt/secure/wifi ]; then rm -rf /opt/secure/wifi/*; fi
if [ -d /opt/NetworkManager/system-connections ]; then rm -rf /opt/NetworkManager/system-connections/*; fi
if [ -d /nvram/NetworkManager/system-connections ]; then rm -rf /nvram/NetworkManager/system-connections/*; fi
if [ -d /var/lib/NetworkManager/system-connections ]; then rm -rf /var/lib/NetworkManager/system-connections/*; fi
if [ -d /opt/QT ]; then rm -rf /opt/QT/*; fi
if [ -d /opt/QT/.sparkStorage ]; then rm -rf /opt/QT/.sparkStorage; fi
if [ -d "${SD_CARD_MOUNT_PATH}/QT/.sparkStorage" ]; then rm -rf "${SD_CARD_MOUNT_PATH}/QT/.sparkStorage"; fi
if [ -d /opt/data ];then rm -rf /opt/data;fi
if [ -e /opt/.gstreamer ]; then rm -rf /opt/.gstreamer; fi
if [ -d /opt/persistent/dvr ]; then rm -rf /opt/persistent/dvr; fi
if [ -d /opt/etc ];then rm -rf /opt/etc;fi
if [ -d /opt/certs ];then rm -rf /opt/certs; fi

if [ -f /opt/secure/Apparmor_blocklist ];then rm -rf /opt/secure/Apparmor_blocklist ; fi

if [ -e /lib/rdk/device-specific-reset.sh ]; then
    echo "Warehouse Reset: Clean configs specific to the device"
    /lib/rdk/device-specific-reset.sh "WAREHOUSE" "CLEAN-CONFIG"
fi

# DRM data cleanup
PROVISION_PROPERTIES=/etc/provision.properties
RT_PROTOCOL_VERSION=$(sed -n 's/^RT_PROTOCOL_VERSION=//p' $PROVISION_PROPERTIES)
if [ ! -z $RT_PROTOCOL_VERSION ]; then
  . ${PROVISION_PROPERTIES}
      if [ ! -z "$TYPES" ]; then
          DRM_TYPES=TYPES[@]
          DRM_TYPES=("${!DRM_TYPES}")
          for drm_type in ${DRM_TYPES[*]}; do
            if [ ! -z "$drm_type" ]; then
                ARRAY_DIRS=$drm_type
                DRM_DIRS=$ARRAY_DIRS[@]
                DRM_DIRS=("${!DRM_DIRS}")
                for drm_dir in ${DRM_DIRS[*]}; do
                  if [ ! -z "$drm_dir" ]; then
                    if [ -d $drm_dir ]; then
                      rm -rf "${drm_dir:?}/"*
                    fi
                  fi
                done
            fi
          done
      fi
else
  if [ -d /opt/drm ]; then rm -rf /opt/drm/*;fi
fi

# persistent data cleanup
if [ -d /opt/persistent ]; then
    find /opt/persistent/ -mindepth 1 -maxdepth 1 ! -name 'store-mode-video' ! -name 'odm-data' -exec rm -rf {} \;
fi
if [ -d /tmp/mnt/diska3/persistent ]; then
    find /tmp/mnt/diska3/persistent/ -mindepth 1 -maxdepth 1 ! -name 'store-mode-video' ! -name 'odm-data' -exec rm -rf {} \;
fi
rm -rf /opt/secure/persistent/System
if [ ! -f /tmp/warehouse_reset_suppress_reboot_clear ]; then
    rm -rf /opt/secure/persistent/rdkservicestore
fi
# authservice data cleanup
if [ -d /opt/www/authService ]; then rm -rf /opt/www/authService/*; fi
if [ -d /mnt/nvram2/authService ]; then rm -rf /mnt/nvram2/authService/*; fi
# project red cleanup
# XRE-9970: Kill the nrdPluginApp first, else the /opt/netflix would be re-created by this process.
killall -s SIGKILL nrdPluginApp
if [ -e /opt/netflix ]; then rm -rf /opt/netflix; fi
if [ -d "${SD_CARD_APP_MOUNT_PATH}/netflix" ]; then rm -rf "${SD_CARD_APP_MOUNT_PATH}/netflix"; fi
if [ -d "${SD_CARD_MOUNT_PATH}/netflix" ]; then rm -rf "${SD_CARD_MOUNT_PATH}/netflix"; fi
# Remove apps data
if [ -d "/media/apps/sky" ]; then rm -rf "/media/apps/sky"; fi
# remove only store-mode-video files if SDCARD path is non empty and exits
if [ -d "$SD_CARD_APP_MOUNT_PATH" ]; then
    find "$SD_CARD_APP_MOUNT_PATH" -mindepth 1 -maxdepth 1 -name 'store-mode-video' -exec rm -rf {} \;
fi
if [ -d "$HDD_APP_MOUNT_PATH" ]; then rm -rf $HDD_APP_MOUNT_PATH/*; fi
# BT data cleanup
if [ -d /opt/lib/bluetooth ]; then rm -rf /opt/lib/bluetooth; fi
# RFC data cleanup
if [ -d /opt/RFC ]; then rm -rf /opt/RFC; fi
if [ -d /opt/secure/RFC ]; then rm -rf /opt/secure/RFC; fi
# Downloadable certs cleanup
if [ -d /opt/dl/certs ]; then rm -rf /opt/dl/certs; fi
# Downloadable creds cleanup
if [ -d /opt/dl/lxy ]; then rm -rf /opt/dl/lxy; fi
#Removing the tmpfs files from XCONF
rm -rf /tmp/device_initiated_snmp_cdl_in_progress
rm -rf /tmp/device_initiated_rcdl_in_progress
rm -rf /tmp/ecm_initiated_cdl_in_progress
rm -rf /tmp/.imageDnldInProgress
rm -rf /tmp/currently_running_image_name

rm -rf /opt/.dnldURL
#Removing proxy mapping file
rm -rf /opt/apps/common/proxies.conf

if [ -L /opt/www/htmldiag ]; then rm -f /opt/www/htmldiag; fi
if [ -L /opt/www/htmldiag2 ]; then rm -f /opt/www/htmldiag2; fi

rm -rf /opt/secure/securityagent

# clear systemd settings
if [ -d /opt/systemd ]; then rm -rf /opt/systemd; fi


if [ -f /etc/lxy.conf ];then
    LXYDBNAME="$(grep '^NAME=' /etc/lxy.conf | sed -e 's/NAME=//')"
    L1="$(grep '^L1=' /etc/lxy.conf | sed -e 's/L1=//')"
    L2="$(grep '^L2=' /etc/lxy.conf | sed -e 's/L2=//')"
    L3="$(grep '^L3=' /etc/lxy.conf | sed -e 's/L3=//')"
    if [ -w $L1/$LXYDBNAME ];then rm -rf $L1/$LXYDBNAME/*; fi
    if [ -w $L2/$LXYDBNAME ];then rm -rf $L2/$LXYDBNAME/*; fi
    if [ -w $L3/$LXYDBNAME ];then rm -rf $L3/$LXYDBNAME/*; fi
fi

if [ "$MODEL_NUM" = "pi" ] || [ "$DEVICE_TYPE" = "mediaclient" ];then
     if [ -f /opt/prefered-gateway ]; then rm -rf /opt/prefered-gateway; fi

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

     fi

     sleep 1
     if [ ! -f /tmp/warehouse_reset_suppress_reboot ] && [ ! -f /tmp/warehouse_reset_suppress_reboot_clear ]; then
         echo "Warehouse Reset:Restarting STB after hrvinit WH Reset flag check..!"
         echo "Warehouse Reset:Deleting receiver.conf override"
         rm /opt/receiver.conf
         sh /rebootNow.sh -s WarehouseReset -o "Rebooting the box after hrvinit WareHouse Reset flag check..."
     else
         echo "Warehouse Reset:Suppressing reboot after WH Reset"
         rm -f /tmp/.warehouse-reset
         rm -f /tmp/warehouse_reset_suppress_reboot
        
         /bin/systemctl restart iarmbusd.service

         if [ ! -f /tmp/warehouse_reset_suppress_reboot_clear ]; then
             echo "Warehouse Reset:Restarting code download service"
             /bin/systemctl restart swupdate.service

             sleep 20
         else
              #sending CLEAR_COMPLETED event
              result=$( curl -H "Content-Type: application/json"  -H "Authorization: Bearer $t" -X POST -d '{"jsonrpc":"2.0", "id":3, "method":"org.rdk.PersistentStore.1.setValue", "params":{"namespace":"FactoryTest", "key":"FTAClearStatus", "value":"CLEAR_COMPLETED"}}' http://127.0.0.1:9998/jsonrpc )
              echo "Warehouse_clear set value: $result"
	      rm -rf /opt/secure/persistent/rdkservicestoreos-release
              rm -f /tmp/warehouse_reset_suppress_reboot_clear
         fi
         echo "Warehouse Reset:Deleting receiver.conf override"
         rm /opt/receiver.conf
     fi
else
     echo 0 > /opt/.rebootFlag
     if [ -f /SetEnv.sh ] ; then
         source /SetEnv.sh
     fi
     if [ ! -f /tmp/warehouse_reset_suppress_reboot ]; then
         echo `/bin/timestamp` ---- Rebooting due to Cold Init Warehouse Reset process ---- >> /opt/logs/ocapri_log.txt
     fi
     /hrvinit "180" "2"
fi

exit 0
