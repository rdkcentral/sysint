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

. /lib/rdk/utils.sh
. /etc/device.properties
. /etc/include.properties
. /etc/config.properties

. /etc/env_setup.sh

flag=0
sleep 90

coreUpload()
{
    export crashTS=`date +%Y-%m-%d-%H-%M-%S`
    if [ "$POTOMAC_SVR" != "" ] && [ "$BUILD_TYPE" != "dev" ]; then
         nice sh $RDK_PATH/uploadDumps.sh $crashTS 1 $POTOMAC_SVR &
         nice sh $RDK_PATH/uploadDumps.sh $crashTS 0 $POTOMAC_SVR &
    else
         nice sh $RDK_PATH/uploadDumps.sh $crashTS 1&
         nice sh $RDK_PATH/uploadDumps.sh $crashTS 0&
    fi
    sleep 1
}

mfrsv_Recovery()
{
   # check for platform where the binary name is mfr_sv
   pidOne=`pidof "mfr_sv"`
   # check for platform where the binary name is MfrLibApp
   pidTwo=`pidof "MfrLibApp"`
   if [ "$pidOne" = "" ] && [ "$pidTwo" = "" ]; then
         echo "`/bin/timestamp` Re-starting mfr server : mfr_sv is not running ..!" >> $LOG_PATH/mfrlib_log.txt
         if [ -f /tmp/mfr_library_socket ];then
             rm /tmp/mfr_library_socket
         fi
         /etc/init.d/mfrlib-services stop
         /etc/init.d/mfrlib-services start
   fi
}

count=0
trmCheck=0
trm_startupCheck()
{
   if [ -f /tmp/.trm_started ]; then
        stat=`pidof "trmsrv"`
        if [ "$stat" = "" ]; then
             count=`expr $count + 1`
        fi
        stat1=`pidof "websocket-trm-proxy"`
        if [ ! "$stat1" ]; then
             count=`expr $count + 1`
        fi
        if [ "$stat" ] && [ "$stat1" ]; then
             trmCheck=1
        fi
        if [ $count -ge 4 ]; then   
             trmCheck=1
        fi
   else
        echo "`/bin/timestamp` TRM Not started yet..!" >> /opt/logs/trm.log
        count=`expr $count + 1`
        if [ $count -ge 20 ]; then   
             trmCheck=1
        fi
   fi
}

trm_Recovery()
{
   stat=`pidof "trmsrv"`
   if [ ! "$stat" ]; then
         echo "`/bin/timestamp` Re-starting trm service: trmsrv is not running ..!" >> $LOG_PATH/trm.log
         /etc/init.d/trm-service restart
         # upload dumps if any
         coreUpload
   fi
   stat=`pidof "websocket-trm-proxy"`
   if [ ! "$stat" ]; then
         echo "`/bin/timestamp` Re-starting trm service: websocket-trm-proxy is not running ..!" >> $LOG_PATH/trm.log
         /etc/init.d/trm-service restart
         # upload dumps if any
         coreUpload
   fi
}

trmmgr_Recovery()
{
   stat=`pidof "TRMMgr"`
   if [ ! "$stat" ]; then
        echo "`/bin/timestamp` Re-starting TRM Manager ..!" >> $LOG_PATH/trmmgr.log
        /etc/init.d/trm-mgr-service restart
        # upload dumps if any
        coreUpload
   fi
}

dnsmasq_Recovery()
{
   stat=`pidof "dnsmasq"`
   if [ ! "$stat" ]; then
        echo "`/bin/timestamp` Re-starting DNSMASQ ..!" >> $LOG_PATH/system.log
        dnsmasq -N -a 127.0.0.1 -z
        # upload dumps if any
        coreUpload
   fi
}
snmpd_Recovery()
{
   stat=`pidof "snmpd"`
   if [ ! "$stat" ]; then
        echo "`/bin/timestamp` Re-starting snmp manager daemon ..!" >> $LOG_PATH/ocapri_log.txt
        pWD=`pwd`
        cd /mnt/nfs/env
        sh ../bin/target-snmp/sbin/restart_snmpd.sh &       
        cd $pWD
        # upload dumps if any
        coreUpload
   fi
}

authservice_Recovery()
{
   stat=`pidof "authservice"`
   if [ ! "$stat" ]; then
        echo "`/bin/timestamp` Re-starting authservice server....!" >> $LOG_PATH/authservice.log
        if [ -f /etc/authservice.sh ];then
             /etc/authservice.sh start &
        fi 
        # upload dumps if any
        coreUpload
   fi
}

siSnmpAgent_Recovery()
{
   stat=`pidof "syssnmpagent"`
   if [ ! "$stat" ]; then
       sh $RDK_PATH/runSysSnmpAgent.sh "recovery-start" &
       coreUpload
   fi
   # upload dumps if any
}

runSnmp_Recovery()
{
    stat=`pidof "runSnmp"`
    if [ ! "$stat" ]; then
          if [ -f $PERSISTENT_PATH/debug.ini ] && [ "$BUILD_TYPE" != "prod" ] ; then
                dbgenvPath=$PERSISTENT_PATH/debug.ini
          fi
          if [ -f $dbgenvPath ]; then
                isSeparateLog=`grep "SEPARATE.LOGFILE.SUPPORT" "$dbgenvPath" | cut -d '=' -f2`
          fi
          if [ "$isSeparateLog" = "TRUE" ] ; then
                LOG_FILE=$LOG_PATH/snmp_log.txt
          else
                LOG_FILE=$LOG_PATH/ocapri_log.txt
          fi
          echo "`/bin/timestamp` Restarting runSnmp since it is not running ..!" >> $LOG_FILE
          /etc/init.d/snmp-manager-service stop
          /etc/init.d/snmp-manager-service start
          coreUpload
    fi
}

runVodClient_Recovery()
{
    stat=`checkProcess "vodClientApp"`
    if [ "$stat" = "" ]; then
          LOG_FILE=$LOG_PATH/vodclient_log.txt
          echo "`/bin/timestamp` Restarting runVodClientApp since it is not running ..!" >> $LOG_FILE
          /etc/init.d/vod-service stop
          /etc/init.d/vod-service start
          echo -n "VOD_CRASHED" > /tmp/vod_crash_monpipe
    fi
}

runPod_Recovery()
{
    stat=`pidof "runPod"`
    if [ ! "$stat" ]; then
          if [ -f $PERSISTENT_PATH/debug.ini ] && [ "$BUILD_TYPE" != "prod" ] ; then
                dbgenvPath=$PERSISTENT_PATH/debug.ini
          fi
          if [ -f $dbgenvPath ]; then
                isSeparateLog=`grep "SEPARATE.LOGFILE.SUPPORT" "$dbgenvPath" | cut -d '=' -f2`
          fi
          if [ "$isSeparateLog" = "TRUE" ] ; then
                LOG_FILE=$LOG_PATH/pod_log.txt
          else
                LOG_FILE=$LOG_PATH/ocapri_log.txt
          fi
          echo "`/bin/timestamp` Rebooting the box since runPod crash is not running ..!" >> $LOG_FILE
          #if [ -f /rebootNow.sh ]; then
          #      sh /rebootNow.sh
          #fi
          sh $RDK_PATH/rebootRecovery.sh "runPod" $LOG_FILE &
    fi
}

rmfStreamer_Recovery()
{
    stat=`pidof "rmfStreamer"`
    if [ ! "$stat" ]; then
          echo `/bin/timestamp` rmf-streamer crashed, restarting the process >> $LOG_PATH/rmfstr_log.txt
          /etc/init.d/rmf-streamer stop
          /etc/init.d/rmf-streamer start
          coreUpload
    fi
}

syslogd_Recovery()
{
  num=`pidof syslogd`
  if [ ! "$num" ]; then
       /etc/init.d/syslogd stop
       /etc/init.d/syslogd start
  fi
}

rsyslogd_Recovery()
{
    if [ -f /etc/init.d/rsyslog ]; then
       num=`pidof rsyslogd`
       if [ ! "$num" ]; then
            /etc/init.d/rsyslog stop
            /etc/init.d/rsyslog start
       fi
    fi
}

dropbear_Recovery()
{
   if [ -f /etc/init.d/dropbear-service ]; then
       stat=`pidof "dropbear"`
       if [ ! "$stat" ]; then
           killall dropbear
           /lib/rdk/startSSH.sh &
       fi
   fi
}

fog_Recovery()
{
   if [ -f /etc/init.d/fog-service ]; then
	fog_pid=`pidof "fogcli"`
        if [ ! "$fog_pid" ]; then
                  echo "`/bin/timestamp` Re-starting fog service: fog-service is not running...!" >> $LOG_PATH/fog.log
                  /etc/init.d/fog-service stop
                  /etc/init.d/fog-service start
        fi
   fi
}



if [ "$DEVICE_TYPE" = "hybrid" ]; then
     # HYBRID Devices
     while [ true ]
     do
         sleep 15
         if [ -f $RAMDISK_PATH/.pod_started ]; then runPod_Recovery; fi
         sleep 15
         if [ -f $RAMDISK_PATH/.pod_started ]; then runPod_Recovery;fi
         lighttpd_Recovery
         if [ "$TRM_ENABLED" = "true" ]; then
             if [ $trmCheck -eq 1 ]; then
                  trm_Recovery
             else
                  trm_startupCheck         
            fi
            if [ -f /usr/local/bin/TRMMgr ]; then
                trmmgr_Recovery
            fi
         fi
         if [ -f /etc/init.d/mfrlib-services ];then
        		 mfrsv_Recovery
         fi
         snmpd_Recovery
         if [ -f $RAMDISK_PATH/.syssnmpagent_started ];then siSnmpAgent_Recovery; fi
         if [ -f $RAMDISK_PATH/.snmpmanager_started ]; then runSnmp_Recovery;fi
         if [ -f $RAMDISK_PATH/.cec_mgrs_on ]; then cecMgrs_Recovery;fi
	 if [ -f $RAMDISK_PATH/.vodClient_started ]; then runVodClient_Recovery ; fi
         rsyslogd_Recovery
         syslogd_Recovery
         dropbear_Recovery
         authservice_Recovery
	 if [ -f /tmp/.fog_started ];then fog_Recovery ; fi
         dnsmasq_Recovery
     done
elif [ "$DEVICE_TYPE" != "mediaclient" ]; then
     # Regular Devices
     while [ true ]
     do
         sleep 30
         lighttpd_Recovery
         if [ "$TRM_ENABLED" = "true" ]; then 
             trm_Recovery
             if [ -f /usr/local/bin/TRMMgr ]; then
                 trmmgr_Recovery
             fi
         fi
         if [ -f /etc/init.d/mfrlib-services ];then
        		 mfrsv_Recovery
         fi
         snmpd_Recovery
         siSnmpAgent_Recovery
         syslogd_Recovery
         dropbear_Recovery
         authservice_Recovery
	 if [ -f /tmp/.fog_started ];then fog_Recovery ; fi
         dnsmasq_Recovery
     done
else
     # Mediaclient Devices
     while [ true ]
     do
         sleep 30
         if [ -f $RAMDISK_PATH/.rmfstreamer_started ]; then rmfStreamer_Recovery; fi
         syslogd_Recovery
         authservice_Recovery
         dnsmasq_Recovery
     done
fi
