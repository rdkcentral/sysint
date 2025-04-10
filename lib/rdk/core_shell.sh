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
. /etc/include.properties
. /etc/device.properties

if [ -f /etc/env_setup.sh ]; then
    . /etc/env_setup.sh
fi

. /etc/config.properties

if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

MEMORY_LOG="/opt/logs/core_log.txt"

if [ -f /etc/os-release ]; then
	CORE_PATH=$CORE_PATH
fi

if [ ! -d "$CORE_PATH" ]; then
     mkdir -p "$CORE_PATH"
fi

if [ "$DEVICE_TYPE" = "broadband" ];then
      MINDUMP_DIR=/minidumps/
else
      MINDUMP_DIR=$MINIDUMPS_PATH
fi

upload() {
    TS=`date +%Y-%m-%d-%H-%M-%S`
    # core+mini dumps to Crash Portal
    # Coredump Upload call
    if [ ! -f /etc/os-release ];then
         echo $(/bin/timestamp) "Starting upload processes from core_shell.sh" >> $LOG_PATH/core_log.txt
         if [ ! -z "$(ls -A $CORE_PATH 2> /dev/null)" ]; then
              sh $RDK_PATH/uploadDumps.sh ${TS} 1 &
         fi
         if [ ! -z "$(ls -A $MINDUMP_DIR 2> /dev/null)" ]; then
              sh $RDK_PATH/uploadDumps.sh ${TS} 0 &
         fi
    fi
    # Checking whether cores are leading to /opt size exceeding.
    count=`ls $CORE_PATH | grep $process | wc -l`
    while [ $count -gt 5 ]; do
        oldcore=`ls -t $CORE_PATH | grep $process | tail -1`
        echo $(/bin/timestamp) "Deleting $oldcore as the same process has more than 5 cores in $CORE_PATH" >> $LOG_PATH/core_log.txt
        rm -rf $CORE_PATH/$oldcore
        count=`ls $CORE_PATH | grep $process | wc -l`
    done

    sh /lib/rdk/diskCleanup.sh
}

notifyCrashedMarker()
{
   crashedProcess=$1 
   case $crashedProcess in
           *mfr_sv*)
               t2CountNotify "MFR_ERR_MFRSV_coredetected"
               ;;
           *overflowMon*)
               t2CountNotify "SYST_ERR_OverflowMon_crash"
               ;;
           *Connection169*)
               t2CountNotify "SYST_ERR_PC_Conn169"
               ;;
           *MAF_StackMgrd*)
               t2CountNotify "SYST_ERR_PC_MAF"
               ;;
           *filter-rbi*)
               t2CountNotify "SYST_ERR_PC_RBI"
               ;;
           *systemd*)
               t2CountNotify "SYST_ERR_PC_Systemd"
               ;;
           *TTSEngine*)
               t2CountNotify "SYST_ERR_PC_TTSEngine"
               ;;
           *vodClientApp*)
               t2CountNotify "SYST_ERR_VodApp_restart"
               ;;
           *syslog-ng*)
               t2CountNotify "SYST_ERR_syslogng_crash"
               ;;
           *xraudio*)
               t2CountNotify "SYST_ERR_xraudio_crash"
               ;;
           *RF4CE*)
               t2CountNotify "SYST_INFO_PC_RF4CE"
               ;;
           *rtrmfplayer*)
               t2CountNotify "WPE_ERR_rtrmfplayer_crash"
               ;;
           *nrdPluginApp*)
               t2CountNotify "NF_INFO_codedumped"
               ;;
           *xcal-device*)
               t2CountNotify "SYST_ERR_XCALDevice_crash"
               ;;
           *rmfStreamer*)
               # External tools tied with this case sensitive data  
               t2CountNotify "SYST_ERR_Rmfstreamer_crash"
               ;;            
           *)
               # For future markers triage can follow below naming convention
               t2CountNotify "SYST_ERR_"$crashedProcess"_crash"
               ;;
   esac
}

dumpMemoryStats()
{
    # dump needed statistics to $MEMORY_LOG, it will be archived to mini/coredump
    free >> $MEMORY_LOG 2>&1
    TERM=vt100 top -b -n1 >> $MEMORY_LOG 2>&1
    df >> $MEMORY_LOG 2>&1
}

dumpInfo()
{
   echo $(/bin/timestamp) "process crashed = $1" >> $LOG_PATH/core_log.txt
   notifyCrashedMarker "$1"
   echo $(/bin/timestamp) "signal causing dump = $2" >> $LOG_PATH/core_log.txt
   echo $(/bin/timestamp) "time of dump = $3" >> $LOG_PATH/core_log.txt
   echo $(/bin/timestamp) "Process ID = $4" >> $LOG_PATH/core_log.txt
   echo $(/bin/timestamp) "Thread ID within process = $5" >> $LOG_PATH/core_log.txt
}

dumpCoreInfo()
{
   echo $(/bin/timestamp) "$process crash and uploading the cores" >> $LOG_PATH/core_log.txt
   echo $(/bin/timestamp) "corename = $corename" >> $LOG_PATH/core_log.txt
   t2ValNotify "core_split" "$corename"
   echo $(/bin/timestamp) "processing_corename = $processing_corename" >> $LOG_PATH/core_log.txt
}

dumpFile()
{
    if [ -f /tmp/coredump_mutex_release ];then rm /tmp/coredump_mutex_release ; fi
    dumpCoreInfo
    echo $(/bin/timestamp) "core-shell core started pid : $$"  >> /opt/logs/core_log.txt
    nice -n 19 gzip -f > $CORE_PATH/$processing_corename
    if [[ $? -ne 0 ]]; then
         rm $CORE_PATH/$processing_corename
         exit 1
    fi
    mv $CORE_PATH/$processing_corename $CORE_PATH/$corename
    echo $(/bin/timestamp) "core-shell core created pid : $$"  >> /opt/logs/core_log.txt
    # fix file permissions
    chmod a+r $CORE_PATH/$corename
    touch /tmp/.$corename.core_dump
    touch /tmp/coredump_mutex_release
}

dumpSystemdLogs()
{
    echo $(/bin/timestamp) "****************SYSTEMD CRASHED DUMPING LOGS START*****************" >> $LOG_PATH/core_log.txt
    journalctl -b  >> $LOG_PATH/core_log.txt
    echo $(/bin/timestamp) "****************SYSTEMD CRASHED DUMPING LOGS END*****************" >> $LOG_PATH/core_log.txt
    
    if [ "$SYSLOG_NG_ENABLED" != "true" ] ; then
        sh /lib/rdk/dumpLogs.sh
    fi
    sync
}

dumpMemoryStats

#fallthrough rule: saving last url as crashed url for crashportal processing
if [ "$1" = "WPEWebProcess" ]; then
    cp /opt/logs/last_url.txt /opt/logs/crashed_url.txt || true
fi

process=$1
signal=$2
timestamp=$3
pid=$4
tid=$5
dumpInfo $process $signal $timestamp $pid $tid
corename="$3_core.prog_$1.signal_$2.gz"
# we have to have processing_corename that is not touched by uploadDumps.sh
processing_corename="$3_core_prog_$1.signal_$2.gz.tmp"
# always try to upload core/minidumps at exit
trap "{ upload ; }" EXIT;
if [ "$HDD_ENABLED" = "true" ];then 
     dumpFile
     # Call dumpLogs.sh script for systemd crash
     if [ "$1" = "systemd" ]; then
        echo $(/bin/timestamp) "$1 crashed with SIGNAL $2, Dumping Journal logs from boot"  >> $LOG_PATH/core_log.txt
        dumpSystemdLogs
     fi
     exit 0
fi
# uimanager support
if [ "$IARM_DEPENDENCY_ENABLE" = "false" ]; then
     if [ "$1" = "uimgr_main" ]; then
          dumpFile
          exit 0
     fi
fi
# Delia build specific
if [ "$DEVICE_TYPE" = "hybrid" ]; then
     if [ "$1" = "rmfStreamer" ]; then
          echo 0 > /tmp/.uploadRMFCores
          echo $corename >> /tmp/.rmf_crashed
          dumpFile
          exit 0
     fi
     if [ "$1" = "runPod" ]; then
          echo 0 > /tmp/.uploadPodCores
          echo $corename >> /tmp/.pod_crashed
          dumpFile
          exit 0
     fi
     if [ "$1" = "runSnmp" ]; then
          echo 0 > /tmp/.uploadSnmpCores
          echo $corename >> /tmp/.snmp_crashed
          dumpFile
          exit 0
     fi
# Regular build specific
elif [ "$DEVICE_TYPE" != "mediaclient" ]; then
     if [ "$1" = "mpeos-main" ]; then
          echo 0 > /opt/.uploadMpeosCores
          echo $corename >> /opt/.mpeos_crashed
          dumpFile
          exit 0
     fi
# mediaclient specific
else
     if [ "$1" = "rmfStreamer" ]; then
          echo 0 > /tmp/.uploadRMFCores
          echo $corename >> /tmp/.rmf_crashed
          dumpFile
     elif [ "$1" = "tr69agent" ] || [ "$1" =  "tr69hostif" ] || [ "$1" = "runTR69HostIf" ] ||
                [ "$1" = "tr69BusMain" ] || [ "$1" = "dimclient" ] || [ "$1" = "rfcMgr" ]; then
          dumpFile
     elif [ "$1" = "nxserver" ]; then
         dumpFile
     elif [ "$1" = "fogcli" ] || [ "$1" = "BaseDlFragDl" ]; then
         dumpFile
     else
           echo ""
     fi
fi

# enable CEF coredumps for non-PROD builds
if [ "$1" = "cef_subprocess" ]; then
    if [ "$BUILD_TYPE" == "prod" ]; then
        echo "Not writing CEF core-dump in PROD"
    else
        dumpFile
    fi
    exit 0
fi

if [ "$1" = "Receiver" ]; then
     if [ "$BUILD_TYPE" != "dev" ]; then
           echo "Not writing Receiver core-dump in VBN/PROD"
     else
           if [ "$DEVICE_TYPE" = "mediaclient" ]; then
		cp /tmp/typefind.ts $PERSISTENT_SEC_PATH/$3_$1_signal_$2_typefind.ts
           fi
           dumpFile
     fi
     exit 0
fi

if [ "$1" = "rdkbrowser2" ]; then
     if [ "$2" = "11" ]; then
           echo "Writing rdkbrowser2 core-dump when signal is SIGSEGV"
           dumpFile
     fi
     exit 0
fi

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     if [ "$1" = "WPEWebProcess" ] || [ "$1" = "WPEIPVideo" ]; then
          dumpFile
          exit 0
     fi
fi

if [ "$HDD_ENABLED" = "false" ] && [ "$1" = "rf4ceMgr" ];then
      echo "No space to hold rf4ceMgr coredump and no support for minidump..!"
      exit 0
fi

if  [ "$1" = "xcal-discovery-" ] || [ "$1" = "xdiscovery" ] || [ "$1" = "IARMDaemonMain" ] ||
    [ "$1" = "AppMSOTarget" ] || [ "$1" = "dsMgrMain" ] || [ "$1" = "irMgrMain" ] ||
    [ "$1" = "pwrMgrMain" ] || [ "$1" = "mfrMgrMain" ] || [ "$1" = "sysMgrMain" ] ||
    [ "$1" = "vrexMgrMain" ] || [ "$1" = "deviceUpdateMgrMain" ] || [ "$1" = "CecDaemonMain" ] ||
    [ "$1" = "socprovisioning" ] || [ "$1" = "xcal-device" ] || [ "$1" = "vodClientApp" ] ||
    [ "$1" = "dvrsrc:src" ] || [ "$1" = "qsrc:src" ] ||
    [ "$1" = "qamsrc_bin-queu" ] || [ "$1" = "authservice" ] || [ "$1" = "named" ] ||
    [ "$1" = "slave_callback" ]  || [ "$1" = "telemetry2_0" ] || [ "$1" = "WorkerPool::Thr" ] ||
    [ "$1" = "subttxrend-app" ] || [ "$1" = "logrotate" ] || [ "$1" = "NetworkManager" ] || 
    [ "$1" = "NWMgrPlugin" ] || [ "$1" = "nm_event_thrd" ] ||
    [ "$1" = "Monitor::IResou" ] || [ "$1" = "DRMSYSTEM" ] || [ "$1" = "HTTPREQUEST_MAN" ]; then
        dumpFile
        exit 0
fi

   if [ "$1" = "audio_server" ] || [ "$1" = "Airplay" ] || [ "$1" = "AirplayDaemon" ] ; then
        dumpFile
	exit 0
   fi
   APP_NAMES=( "appsserviced" "dropbear"
        "asrdkplayer" "asproxy" "DobbyDaemon"
        "DobbyInit" "epg_ui" "asmockservice"
        "ASSystemService" "BleRcuDaemon"
        "VoiceSearchDaemon" "VoiceSearchDaem"
        "ASNetworkService" "ASNetworkServic"
        "ASConviva" "SkyBrowserLaunc"
        "AS_CHERRY_STATU" "QNetworkAccessM" 
	"civetweb-worker" )

    for anAppName in "${APP_NAMES[@]}"; do
        if [ "$1" = "${anAppName}" ]; then
            dumpFile
            exit 0
        fi
    done
    
echo $(/bin/timestamp) "$1 process is not listed to upload, we are not processing the core file" >> $LOG_PATH/core_log.txt

exit 0

