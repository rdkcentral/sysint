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

. $RDK_PATH/utils.sh

sigsegv_function()
{
    echo "sigsegv_function caught error on Line: $1, Command: $2"
}
trap 'sigsegv_function $LINENO $BASH_COMMAND EXIT' SIGSEGV

sigup_function()
{
    echo "sigup_function caught error on Line: $1, Command: $2"
}
trap 'sigup_function $LINENO $BASH_COMMAND EXIT' SIGHUP

sigint_function()
{
    echo "sigint_function caught error on Line: $1, Command: $2"
}
trap 'sigint_function $LINENO $BASH_COMMAND EXIT' SIGINT

sigquit_function()
{
    echo "sigquit_function caught error on Line: $1, Command: $2"
}
trap 'sigquit_function $LINENO $BASH_COMMAND EXIT' SIGQUIT

sigkill_function()
{
    echo "sigkill_function caught error on Line: $1, Command: $2"
}
trap 'sigkill_function $LINENO $BASH_COMMAND EXIT' SIGKILL

sigpipe_function()
{
    echo "sigpipe_function caught error on Line: $1, Command: $2"
}
trap 'sigpipe_function $LINENO $BASH_COMMAND EXIT' SIGPIPE

sigabrt_function()
{
    echo "sigabrt_function caught error on Line: $1, Command: $2"
}
trap 'sigabrt_function $LINENO $BASH_COMMAND EXIT' SIGABRT

sigterm_function()
{
    echo "sigterm_function caught error on Line: $1, Command: $2"
}
trap 'sigterm_function $LINENO $BASH_COMMAND EXIT' SIGTERM

sigill_function()
{
    echo "sigill_function caught error on Line: $1, Command: $2"
}
trap 'sigill_function $LINENO $BASH_COMMAND EXIT' SIGILL

sigusr1_function()
{
    echo "sigusr1_function caught error on Line: $1, Command: $2"
}
trap 'sigusr1_function $LINENO $BASH_COMMAND EXIT' SIGUSR1

#Set flag to indicate log rotation
LOG_ROTATE_FLAG=0

# exit if an instance is already running
if [ ! -f /etc/os-release ];then
    if [ ! -f /tmp/.log-rotate-daemon.pid ];then
        # store the PID
        echo $$ > /tmp/.log-rotate-daemon.pid
    else
        pid=`cat /tmp/.log-rotate-daemon.pid`
        if [ -d /proc/$pid ];then
             exit 0
        fi
    fi
fi

pidCleanup()
{
     # PID file cleanup
     if [ -f /tmp/.log-rotate-daemon.pid ];then
          rm -rf /tmp/.log-rotate-daemon.pid
     fi
}

# Disable the log rotate in stand by mode
if [ -f $RAMDISK_PATH/.standby ]; then
     if [ ! -f /etc/os-release ];then pidCleanup; fi
     exit 0
fi

# Set the log rotate property file
propertyFile="/etc/logRotate.properties"
if [ "$BUILD_TYPE" != "prod" ]; then
      if [ -f $PERSISTENT_PATH/logRotate.properties ]; then
            propertyFile="$PERSISTENT_PATH/logRotate.properties"
      fi
fi
 
# include the log rotate property file
. $propertyFile

if [ "$logRotateEnable" ] && [ "$logRotateEnable" != "true" ]; then
       echo "Log Rotate Disabled"
       if [ ! -f /etc/os-release ];then pidCleanup; fi
       exit 0
fi
# Verify the log rotate flag
if [ ! /etc/os-release ]; then
    if [ ! -f $RAMDISK_PATH/.normalRebootFlag ]; then
       echo "Log Rotate Disabled"
       if [ ! -f /etc/os-release ];then pidCleanup; fi
       exit 0
    fi
fi

if [ "$BUILD_TYPE" = "dev" ]; then
    LOG_SERVER=10.253.97.249
else
    LOG_SERVER=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.LogServerUrl 2>&1)
fi

if [ -z $LOG_SERVER ]; then
    . /etc/dcm.properties
fi

backupRotatedFile()
{
   dirName=$1
   fileName=$2 
   . /etc/dcm.properties
   # Get Mac Address of eSTB                                              
   MAC=`getMacAddressOnly`                                                
   count=`cat /tmp/.rotateCount`                              
   extn="$count.tgz"
   Name="_Rotate"
   
   file=$MAC$Name$extn                           
   tar -zcvf ${dirName}/$file ${dirName}/${fileName}.${COUNT}        
   
   tftp -b 8192 -p -r $file -l ${dirName}/$file $LOG_SERVER    
   sleep 3
   echo "Rotating the file: $file & uploading"
   rm -rf ${dirName}/$file                     
   count=`expr $count + 1`                                    
   echo $count > /tmp/.rotateCount 
}

logrotate()
{
	ret=0
	DIRNAME=$1
	FILENAME=$2
	COUNT=$3
	SIZE=$4

	#FILESIZE=`du -ks ${DIRNAME}/${FILENAME}  | cut -f1`
        FILESIZE=`ls -l ${DIRNAME}/${FILENAME} | awk -F" " '{print $5}'`

        file="${DIRNAME}/${FILENAME}.${COUNT}"
        #if [ -f $file ]; then 
        #     backupRotatedFile $DIRNAME $FILENAME
        #fi

	cd $DIRNAME
	if [[ ${FILESIZE} -gt ${SIZE} ]];
	then
        	echo "logrotate started: ${FILENAME} size: ${FILESIZE} inode : `ls -i ${DIRNAME}/${FILENAME} | awk '{print $1;}'` date : `date +"%d/%m/%Y - %H.%M.%S"` "
                LOG_ROTATE_FLAG=1
		i=$COUNT
		while [ $i -ge 2 ]
		do
			j=`expr $i - 1`
			segment2=${FILENAME}.${i}
			segment1=${FILENAME}.${j}
			if [ -f ${DIRNAME}/${segment1} ]
			then
				mv $segment1 $segment2 
            fi
			i=`expr $i - 1`
		done
		cp ${FILENAME} ${FILENAME}."1"
		cat /dev/null > ${DIRNAME}/${FILENAME}
	fi
}

logRotateFramework()
{
   logFile=$1
   rotationCount=$2
   rotationSize=$3

   if [ "$logFile" != "" ] && [ -f "$logFile" ] ; then
        log=`basename $logFile`
   else
      return 0
   fi
   if [ ! -s $logFile ]; then return 0; fi
   if [ -z $rotationCount ] || [ -z $rotationSize ] ; then 
        return 0; 
   fi
   # rotate the file
   logrotate $logFileBase $log $rotationCount $rotationSize
}

if [ ! -h $pumalog ]; then
     logRotateFramework $pumalog $pumalogRotatCount $pumalogRotatSize
fi
 
if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     logRotateFramework $ecmLog $ecmLogRotatCount $ecmLogRotatSize
     logRotateFramework $vodLog $vodLogRotateCount $vodLogRotateSize
     logRotateFramework $podLog $podLogRotateCount $podLogRotateSize
     logRotateFramework $mainMONLog $mainMONLogRotatCount $mainMONLogRotatSize
     logRotateFramework $receiverMONLog $receiverMONLogRotatCount $receiverMONLogRotatSize
     logRotateFramework $mfrLog $mfrLogRotateCount $mfrLogRotateSize
     logRotateFramework $snmpdLog $logRotateGenericCount $logRotateGenericSize
     logRotateFramework $dibblerLog $logRotateGenericCount $logRotateGenericSize
     logRotateFramework $upstreamStatsLog $logRotateGenericCount $logRotateGenericSize
     logRotateFramework $xiRecoveryLog $logRotateGenericCount $logRotateGenericSize
     logRotateFramework $parodusLog $logRotateGenericCount $parodusLogRotateSize
     logRotateFramework $cpuprocanalyzerLog $cpuprocanalyzerLogRotateCount $cpuprocanalyzerLogRotateSize
     logRotateFramework $namedLog $namedLogRotateCount $namedLogRotateSize
     logRotateFramework $dnsqueryLog $dnsqueryLogRotateCount $dnsqueryLogRotateSize
     logRotateFramework $sslendpointsLog $sslendpointsLogRotateCount $sslendpointsLogRotateSize
else
     logRotateFramework $wifiTelemetryLog $wifiTelemetryLogRotateCount $wifiTelemetryLogRotateSize
     logRotateFramework $tr69AgentLog $tr69AgentHttpLogRotateCount $tr69AgentHttpLogRotateSize
     logRotateFramework $tr69AgentHttpLog $tr69AgentHttpLogRotateCount $tr69AgentHttpLogRotateSize
     logRotateFramework $tr69AgentSoapLog $tr69AgentSoapLogRotateCount $tr69AgentSoapLogRotateSize
     logRotateFramework $ConnectionStatusLog $logRotateGenericCount $logRotateGenericSize
     logRotateFramework $parodusLog $logRotateGenericCount $parodusLogRotateSize
     logRotateFramework $cpuprocanalyzerLog $cpuprocanalyzerLogRotateCount $cpuprocanalyzerLogRotateSize
     logRotateFramework $namedLog $namedLogRotateCount $namedLogRotateSize
     logRotateFramework $dnsqueryLog $dnsqueryLogRotateCount $dnsqueryLogRotateSize
     logRotateFramework $sslendpointsLog $sslendpointsLogRotateCount $sslendpointsLogRotateSize
fi


	logRotateFramework $receiverLog $receiverLogRotatCount $receiverLogRotatSize
	logRotateFramework $ttsLog $ttsLogRotatCount $ttsLogRotatSize
	logRotateFramework $applnLog $applnLogRotateCount $applnLogRotateSize
	logRotateFramework $rmfLog $rmfLogRotateCount $rmfLogRotateSize
	logRotateFramework $sysLog $sysLogRotatCount $sysLogRotatSize
        logRotateFramework $ntpLog $ntpLogRotateCount $ntpLogRotateSize
	logRotateFramework $fusionDaleLog $fusionDaleLogRotateCount $fusionDaleLogRotateSize
	logRotateFramework $xDiscoveryLog $xdisRotateCount $xdisRotateSize
	logRotateFramework $xDiscoveryLogList $xdisRotateCount $xdisRotateSize
	logRotateFramework $lighttpdErrorLog $lighttpdRotateCount $lighttpdRotateSize
	logRotateFramework $lighttpdAccessLog $lighttpdRotateCount $lighttpdRotateSize
	logRotateFramework $dcmLog $dcmLogRotateCount $dcmLogRotateSize
        logRotateFramework $telemetry2Log $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $fdsLog $fdsRotateCount $fdsRotateSize
	logRotateFramework $uimngrFile $uimngrRotateCount $uimngrRotateSize
	logRotateFramework $storagemgrLog $storagemgrLogRotateCount $storagemgrLogRotateSize
	logRotateFramework $ctrlmFile $ctrlmRotateCount $ctrlmRotateSize
	logRotateFramework $trmLog $trmRotateCount $trmRotateSize
	logRotateFramework $trmMgrLog $trmRotateCount $trmRotateSize
	logRotateFramework $xDeviceLog $xDeviceRotateCount $xDeviceRotateSize
	logRotateFramework $socProvLog $socProvRotateCount $socProvRotateSize
        logRotateFramework $socProvCryptoLog $socProvRotateCount $socProvRotateSize
	logRotateFramework $vlThreadLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $mocaStatusLog $mocaStatRotateCount $mocaStatRotateSize
	logRotateFramework $mocaServiceLog $mocaServiceRotateCount $mocaServiceRotateSize
	logRotateFramework $snmp2jsonLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $decoderStatusLog $decoderStatusLogRotateCount $decoderStatusLogRotateSize
	logRotateFramework $mfrLog $mfrLogRotateCount $mfrLogRotateSize
	logRotateFramework $sysDmesgLog $sysLogRotatCount $sysLogRotatSize
	logRotateFramework $diskStatusLog $diskStatusLogRotateCount $diskStatusLogRotateSize
	logRotateFramework $systemLog $systemLogRotateCount $systemLogRotateSize
	logRotateFramework $netsrvLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $samhainLog $logRotateGenericCount $logRotateGenericSize
        logRotateFramework $fogLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $hddStatusLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $mountLog $mountLogRotateCount $mountLogRotateSize
	logRotateFramework $rbiDaemonLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $rfcLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $pingTelemetryLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $dnsmasqLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $tlsLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $nlmonLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $hwselfLog $logRotateGenericCount $logRotateGenericSize
        logRotateFramework $wpeframeworkLog $logRotateWPEFrameworkCount $logRotateGenericSize
        logRotateFramework $residentAppLog $logRotateResidentAppCount $logRotateGenericSize
        logRotateFramework $servicenumberLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $dropbearLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $rebootReasonLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $appmanagerLog $appmanagerLogRotateCount $appmanagerLogRotateSize
        logRotateFramework $xdialLog $logRotateGenericCount $logRotateGenericSize
        logRotateFramework $bluetoothLog $bluetoothLogRotateCount $bluetoothLogRotateSize
        logRotateFramework $bluezLog $bluezLogRotateCount $bluezLogRotateSize
        logRotateFramework $appsRdmLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $dibblerclientLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $ecfsLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $iptablesLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $perfmonstatusLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $rdkmilestonesLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $stunnelLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $tr69HostIfLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $adobeCleanupLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $cgrpmemoryLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $cgrmemorytestLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $hdcpLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $threadLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $bootUpLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $LastUrlLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $CrashedUrlLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $rtroutedLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $rtkfwlog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $rtkafwlicensechecklog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $remoteDebuggerLog $logRotateGenericCount $logRotateGenericSize
        logRotateFramework $rippleLog $logRotateGenericCount $logRotateGenericSize

if [ "$WIFI_SUPPORT" == "true" ];then
	logRotateFramework $wpaSupplicantLog $logRotateGenericCount $logRotateGenericSize
	logRotateFramework $dhcpWifiLog $logRotateGenericCount $logRotateGenericSize
fi
if [ "$CONTAINER_SUPPORT" == "true" ];then
    logRotateFramework $lxcxreLog  $logRotateGenericCount $lxcxreLogRotateSize
    logRotateFramework $lxcxreAppLog $logRotateGenericCount $lxcxreAppLogRotateSize
fi
if [ "$DOBBY_ENABLED" == "true" ];then
    logRotateFramework $dobbyLog $logRotateGenericCount $logRotateGenericSize
fi
if [ "x$SYSLOG_NG_ENABLED" == "xtrue" ];then
    logRotateFramework $syslogFallbackLog $logRotateGenericCount $logRotateGenericSize
fi

logRotateFramework $cecLog $cecLogRotateCount $cecLogRotateSize


if [ "$MEDIARITE" == "true" ];then
	logRotateFramework $MediaRiteLog $logRotateMediaRiteGenericCount $logRotateMediaRiteGenericSize
fi

trap "" 13

if [ "$DEVICE_TYPE" != "mediaclient"  ]; then
      if [ -f ${riLog} ]; then
           if [ "$BUILD_TYPE" = "dev" ] && [ "$HDD_ENABLED" = "false" ]; then
	             logrotate $logFileBase `basename $riLog` 4 $riLogRotateSize
           else
               logrotate $logFileBase `basename $riLog` $riLogRotateCount $riLogRotateSize
               maxFile=`find /opt/logs -type f | grep -v -E 'PreviousLogs|pcap|logbackup|[0-9]$|\.tgz$|\.gz$' | xargs ls -S  | head -n 1`

               if [ -f "$maxFile" ]; then
                   size=`stat $maxFile | grep Size: | cut -d ":" -f2 | awk '{print $1}'`
                   if [[ $size -gt 22020096 ]]; then
                       echo "HDD:logrotate started for maxfile: ${maxFile} size: ${size} inode : `ls -i ${maxFile} | awk '{print $1;}'` date : `date +"%d/%m/%Y - %H.%M.%S"` "
                       if [ ! -s $maxFile ]; then echo "$maxFile is empty"; return 0; fi
                       cp $maxFile $maxFile.1
                       cat /dev/null > $maxFile
                   fi
               fi
           fi
      fi
fi

if [ "$HDD_ENABLED" = "false" ]; then
     maxFile=`find /opt/logs -maxdepth 1 -type f -name '*.log' -o -name '*.txt' -o -name '*.txt.0' | xargs ls -S | head -n 1`
     if  [ -f "$maxFile" ]; then
          size=`stat $maxFile | grep Size: | cut -d ":" -f2 | awk '{print $1}'`
          if [[ $size -gt 2097152 ]]; then
               echo "logrotate started for maxfile: ${maxFile} size: ${size} inode : `ls -i ${maxFile} | awk '{print $1;}'` date : `date +"%d/%m/%Y - %H.%M.%S"` "
               if [ ! -s $maxFile ]; then echo "$maxFile is empty"; return 0; fi
               mv $maxFile $maxFile.1
               LOG_ROTATE_FLAG=1
               cat /dev/null > $maxFile
          fi
     fi
fi

if [ ! -f /etc/os-release ];then
    #Adding a work around to create core_log.txt whith restricted user privilege
    #if linux multi user is enabled
    if [ "$ENABLE_MULTI_USER" == "true" ] ; then
       if [ "$BUILD_TYPE" == "prod" ] ; then
           touch /opt/logs/core_log.txt
           chown restricteduser:restrictedgroup /opt/logs/core_log.txt
       else
           if [ ! -f /opt/disable_chrootXREJail ]; then
              touch /opt/logs/core_log.txt
              chown restricteduser:restrictedgroup /opt/logs/core_log.txt
           fi
       fi
    fi
fi

#After rotating log files, sending SIGHUP to syslog-ng to close the fd of the log file
if [ "$SYSLOG_NG_ENABLED" == "true" ] ; then
    if [ $LOG_ROTATE_FLAG -eq 1 ]; then
        echo "Sending SIGHUP to reload syslog-ng"
        killall -HUP syslog-ng
        if [ $? -eq 0 ]; then
            echo "syslog-ng reloaded successfully"
        fi
    fi
fi

if [ ! -f /etc/os-release ];then pidCleanup; fi
exit 0

