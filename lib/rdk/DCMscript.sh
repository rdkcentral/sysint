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

#
##################################################################
## Script to do Device Configuration Management
## Updates the following information in the settop box 
##    * Check Schedule
##    * Check Log Upload Settings
##    * Check Configuration
## Author: Ajaykumar/Shakeel/Suraj
##################################################################

. /etc/include.properties
. /etc/device.properties

if [ -f /etc/telemetry2_0.properties ]; then
    . /etc/telemetry2_0.properties
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
        source /lib/rdk/t2Shared_api.sh
fi

if [ -f $RDK_PATH/exec_curl_mtls.sh ]; then
        source $RDK_PATH/exec_curl_mtls.sh
fi

T2_ENABLE=`tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.Telemetry.Enable 2>&1`

# exit if an instance is already running
pid_file="/tmp/.dcm-utility.pid"
if [ -f $pid_file ] && [ -d /proc/`cat $pid_file` ]; then
   exit 0
fi
echo $$ > $pid_file

DCM_SKIP_RETRY_FLAG='/tmp/dcm_not_configured'
WAREHOUSE_ENV="$RAMDISK_PATH/warehouse_mode_active"

# Adding a sleep of 1 minute to avoid the initial 
# CPU load due to ip address check
sleep 90

if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
      . /opt/dcm.properties
else
      . /etc/dcm.properties
fi

if [ "$DEVICE_TYPE" != "mediaclient" ]; then 
   . /lib/rdk/snmpUtils.sh
else
   . /lib/rdk/utils.sh
fi

if [ -z $LOG_PATH ]; then
    LOG_PATH="/opt/logs/"
fi
if [ -z $PERSISTENT_PATH ]; then
    PERSISTENT_PATH="/tmp"
fi

export PATH=$PATH:/usr/bin:/bin:/usr/local/bin:/sbin:/usr/local/lighttpd/sbin:/usr/local/sbin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Qt/lib:/usr/local/lib
TELEMETRY_PATH="/opt/.telemetry"
SORTED_PATTERN_CONF_FILE="$TELEMETRY_PATH/dca_temp_file.conf"
DCMFLAG="/tmp/.DCMSettingsFlag"
DCM_LOG_FILE="$LOG_PATH/dcmscript.log"
TLS_LOG_FILE="$LOG_PATH/tlsError.log"
HTTP_CODE="/tmp/dcm_http_code"
rm -rf $HTTP_CODE

#setting TLS value only for Yocto builds
TLS=""
if [ -f /etc/os-release ]; then
    TLS="--tlsv1.2"
fi

TLSRet=""
HTTPS_URL=""
cron_update=0
reboot_flag=$4

dcmLog() {
    echo "`/bin/timestamp`: $0: $*" >> $DCM_LOG_FILE
}

tlsLog() {
    echo "`/bin/timestamp`: $0: $*" >> $TLS_LOG_FILE
}

if [ $# -ne 5 ]
then
    dcmLog "Argument does not match"
    echo 0 > $DCMFLAG
    exit 1
fi

. $RDK_PATH/utils.sh

# initialize partnerId
. $RDK_PATH/getPartnerId.sh

dcmLog "Starting execution of DCMscript.sh"

## Trigger Telemetry run for previous boot log files 
dcmLog "Telemetry run for previous boot log files"
TELEMETRY_PREVIOUS_LOG="/tmp/.telemetry_previous_log"

###########################################################################################
TELEMETRY_PATH_TEMP="$TELEMETRY_PATH/tmp"
T2_SERVICE_PATH="/tmp/enable_t2_service"

SYSTEM_METRIC_CRON_INTERVAL="*/15 * * * *"

t2Log() {
    timestamp=`date +%Y-%b-%d_%H-%M-%S`
    echo "$0 : $timestamp $*" >> $T2_0_LOGFILE
}

systemHealthLog=`sh /lib/rdk/cronjobs_update.sh "check-entry" "vm_cpu_temp-check.sh"`
if [ "$systemHealthLog" != "0" ]; then
    sh /lib/rdk/cronjobs_update.sh "remove" "vm_cpu_temp-check.sh"
fi

sh /lib/rdk/cronjobs_update.sh "update" "vm_cpu_temp-check.sh" "$SYSTEM_METRIC_CRON_INTERVAL nice -n 10 sh $RDK_PATH/vm_cpu_temp-check.sh"

# Check for RFC Telemetry.Enable settings
# Internal syscfg database used by RFC parameter -  Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.Telemetry.Enable

t2Log "RFC value for Telemetry 2.0 Enable is $T2_ENABLE ."
if [ ! -f $T2_0_BIN ]; then
    t2Log "Unable to find $T2_0_BIN ... Switching T2 Enable to false !!!"
    T2_ENABLE="false"
fi

###########################################################################################

if [ "x$T2_ENABLE" != "xtrue" ]; then
    touch $TELEMETRY_PREVIOUS_LOG
    # Running previous logs telemetry run in background as previous logs directory will be removed after 7mins sleep in uploadSTBLogs.sh
    sh /lib/rdk/dca_utility.sh 1 1 &
fi

# initialize partnerId
. $RDK_PATH/getPartnerId.sh

# initialize accountId
. $RDK_PATH/getAccountId.sh

#---------------------------------
# Initialize Variables
#---------------------------------
# URL
URL=$2
tftp_server=$3
checkon_reboot=$5

#Flag to use Secure endpoints
useXpkiMtlsLogupload=false
checkXpkiMtlsBasedLogUpload()
{
    if [ "$DEVICE_TYPE" = "broadband" ]; then
        dycredpath="/nvram/lxy"
    else
        dycredpath="/opt/lxy"
    fi

    if [ -d $dycredpath ] && [ -f /usr/bin/rdkssacli ] && [ -f /opt/certs/devicecert_1.pk12 ] && [ "$MODEL_NUM" != "SX022AN" ]; then
        useXpkiMtlsLogupload="true"
    else
        useXpkiMtlsLogupload="false"
    fi
    dcmLog "xpki based mtls support = $useXpkiMtlsLogupload"
}
checkXpkiMtlsBasedLogUpload

if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
    dcmLog "opt override is present. Ignore settings from Bootstrap config"
else
    LOG_CONFIG_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Bootstrap.XconfUrl 2>&1 > /dev/null)

    if [ "$LOG_CONFIG_URL" ]; then
        URL="$LOG_CONFIG_URL/loguploader/getSettings"
        dcmLog "Setting URL to $URL from Bootstrap config LOG_CONFIG_URL:$LOG_CONFIG_URL"
    fi
fi

dcmLog "URL: $URL"
dcmLog "REBOOT_FLAG: $reboot_flag"
dcmLog "CHECK_ON_REBOOT: $checkon_reboot"


if [ -f "/tmp/DCMSettings.conf" ]
then
    Check_URL=`grep 'urn:settings:ConfigurationServiceURL' /tmp/DCMSettings.conf | cut -d '=' -f2 | head -n 1`
    if [ -n "$Check_URL" ]
    then
        URL=`grep 'urn:settings:ConfigurationServiceURL' /tmp/DCMSettings.conf | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//' | head -n 1`
        #last_char=`echo $URL | sed -e 's/\(^.*\)\(.$\)/\2/'`
        last_char=`echo $URL | awk '$0=$NF' FS=`
        if [ "$last_char" != "?" ]
        then
            URL="$URL?"
        fi
    fi
fi
# File to save curl response 
FILENAME="$PERSISTENT_PATH/DCMresponse.txt"
# File to save http code
CURL_INFO="$PERSISTENT_PATH/dcm_curl_info"
rm -rf $CURL_INFO
# Timeout value
timeout=10
CURL_TLS_TIMEOUT=30
# http header
HTTP_HEADERS='Content-Type: application/json'

## RETRY DELAY in secs
RETRY_DELAY=60
RETRY_DELAY_DCM=300
RETRY_COUNT=3
default_IP=$DEFAULT_IP
upload_protocol='HTTP'

upload_httplink_url=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.SsrUrl 2>&1)
if [ ! -z "$upload_httplink_url" ]; then
    upload_httplink=${upload_httplink_url}/cgi-bin/S3.cgi
else
    upload_httplink=$HTTP_UPLOAD_LINK
fi

if [ "$BUILD_TYPE" != "prod" ] && [ -f /opt/dcm.properties ]; then
    dcmLog "opt override is present. Ignore settings from Bootstrap config"
else
   #check if we have bootstrap parameter
   bootstrap_upload_httplink=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.LogUploadEndpoint.URL 2>&1 > /dev/null)
   if [ ! -z "$bootstrap_upload_httplink" ]; then
       dcmLog "Overriding the upload url with bootstrap url"
       upload_httplink="$bootstrap_upload_httplink"
   fi
fi

MAX_UPLOAD_ATTEMPTS=3
CB_MAX_UPLOAD_ATTEMPTS=1
DIRECT_BLOCK_FILENAME="/tmp/.lastdirectfail_dcm"
CB_BLOCK_FILENAME="/tmp/.lastcodebigfail_dcm"

EnableOCSPStapling="/tmp/.EnableOCSPStapling"
EnableOCSP="/tmp/.EnableOCSPCA"

cron=""
sleep_time=0
PREVIOUS_CRON_FILE="/opt/.telemetry_previous_cron_file"
#---------------------------------
# Function declarations
#---------------------------------
IsDirectBlocked()
{
    directret=0
    if [ -f $DIRECT_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $DIRECT_BLOCK_FILENAME)))
        remtime=$((($DIRECT_BLOCK_TIME/3600) - ($modtime/3600)))
        if [ "$modtime" -le "$DIRECT_BLOCK_TIME" ]; then
            dcmLog "Last direct failed blocking is still valid for $remtime hrs, preventing direct"
            directret=1
        else
            dcmLog "Last direct failed blocking has expired, removing $DIRECT_BLOCK_FILENAME, allowing direct"
            rm -f $DIRECT_BLOCK_FILENAME
        fi
    fi
    return $directret
}

IsCodeBigBlocked()
{
    codebigret=0
    if [ -f $CB_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $CB_BLOCK_FILENAME)))
        cbremtime=$((($CB_BLOCK_TIME/60) - ($modtime/60)))
        if [ "$modtime" -le "$CB_BLOCK_TIME" ]; then
            dcmLog "Last Codebig failed blocking is still valid for $cbremtime mins, preventing Codebig"
            codebigret=1
        else
            dcmLog "Last Codebig failed blocking has expired, removing $CB_BLOCK_FILENAME, allowing Codebig"
            rm -f $CB_BLOCK_FILENAME
        fi
    fi
    return $codebigret
}

## FW version from version.txt 
getFWVersion()
{
    #cat /version.txt | grep ^imagename:PaceX1 | grep -v image
    verStr=`cat /version.txt | grep ^imagename: | cut -d ":" -f 2`
    echo $verStr
}

## Identifies whether it is a VBN or PROD build
getBuildType()
{
   echo $BUILD_TYPE
}

## Get ECM mac address
getECMMacAddress()
{
    mac=""
    if [ "$DEVICE_TYPE" != "mediaclient" ]; then
        address=`getECMMac`
        mac=`echo $address | tr -d ' ' | tr -d '"'`
    fi
    echo $mac
}

## Get Controller Id
getControllerId()
{
    echo "2504"
}

## Get ChannelMap Id
getChannelMapId()
{
    echo "2345"
}

## Get VOD Id
getVODId()
{
    echo "15660"
}

## Process the responce and update it in a file DCMSettings.conf
processJsonResponse()
{  	 

    if [ -f "$FILENAME" ]
    then
        OUTFILE='/tmp/DCMSettings.conf'
		OUTFILEOPT='/opt/.DCMSettings.conf'
        sed -i 's/,"urn:/\n"urn:/g' $FILENAME # Updating the file by replacing all ',"urn:' with '\n"urn:'
        sed -i 's/^{//g' $FILENAME # Delete first character from file '{'
        sed -i 's/}$//g' $FILENAME # Delete first character from file '}'
        echo "" >> $FILENAME         # Adding a new line to the file 

        #rm -f $OUTFILE #delete old file
        cat /dev/null > $OUTFILE #empty old file
		cat /dev/null > $OUTFILEOPT

        while read line
        do  
            
            # Parse the settings  by
            # 1) Replace the '":' with '='
            # 2) Updating the result in a output file
            profile_Check=`echo "$line" | grep -ci 'TelemetryProfile'`
            if [ $profile_Check -ne 0 ];then
                #echo "$line"
                echo "$line" | sed 's/"header":"/"header" : "/g' | sed 's/"content":"/"content" : "/g' | sed 's/"type":"/"type" : "/g' >> $OUTFILE
				echo "$line" | sed 's/"header":"/"header" : "/g' | sed 's/"content":"/"content" : "/g' | sed 's/"type":"/"type" : "/g'  | sed -e 's/uploadRepository:URL.*","//g'  >> $OUTFILEOPT
            else
                cron_Check=`echo "$line" | grep 'urn:settings:CheckSchedule:cron' | grep -c '\-1'`
                if [ $cron_Check -ne 0 ];then
                   # correct bad cron rules (-1) from the DCM server
                   dcmLog "Corrected bad cron rule from DCM server: $line"
                   line=`echo "$line" | sed 's/\-1/0/g'`
                fi 
                echo "$line" | sed 's/":/=/g' | sed 's/"//g' >> $OUTFILE 		
            fi            
        done < $FILENAME
        
        rm -rf $FILENAME #Delete the /opt/DCMresponse.txt
    else
        dcmLog "$FILENAME not found."
        return 1
    fi
}

sendTLSDCMCodebigRequest()
{
    CB_SIGNED_REQUEST=$1
    dcmLog "Attempting $TLS connection to Codebig DCM server"
    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        CURL_CMD="curl $TLS -w '%{http_code} %{remote_ip} %{remote_port}\n' --cert-status --connect-timeout $CURL_TLS_TIMEOUT -m $timeout -o  \"$FILENAME\" \"$CB_SIGNED_REQUEST\""
    else
        CURL_CMD="curl $TLS -w '%{http_code} %{remote_ip} %{remote_port}\n' --connect-timeout $CURL_TLS_TIMEOUT -m $timeout -o  \"$FILENAME\" \"$CB_SIGNED_REQUEST\""
    fi
    dcmLog "CURL_CMD: $CURL_CMD"
    eval $CURL_CMD > $CURL_INFO
    TLSRet=$?
    FQDN=`echo "$CB_SIGNED_REQUEST" | awk -F/ '{print $3}'`
    http_code=$(awk '{print $1}' $CURL_INFO)
    server_ip=$(awk '{print $2}' $CURL_INFO)
    port_num=$(awk '{print $3}' $CURL_INFO)
    dcmLog "Curl Connected to $FQDN ($server_ip) port $port_num"
    dcmLog "Curl return code: $TLSRet, http code: $http_code"

    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            tlsLog "CERTERR, DCM, $TLSRet, $FQDN"
            t2ValNotify "certerr_split" "DCM, $TLSRet, $FQDN"
            ;;
    esac
}

sendTLSDCMRequest()
{
    TLSRet=1
    dcmLog "Attempting $TLS connection to DCM server"
    dcmLog "MTLS preferred for DCM Request"

        if [ "$useXpkiMtlsLogupload" == "true" ]; then
            msg_tls_source="mTLS certificate from xPKI"
            dcmLog "Connect with $msg_tls_source"
            CURL_CMD="-w '%{http_code} %{remote_ip} %{remote_port}\n' --connect-timeout $CURL_TLS_TIMEOUT -m $timeout -o  \"$FILENAME\" '$HTTPS_URL$JSONSTR'"  
        fi
    
    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        CURL_CMD="$CURL_CMD --cert-status"
    fi
    TLSRet=` exec_curl_mtls "$CURL_CMD" "dcmLog"`
    cat $HTTP_CODE > $CURL_INFO
    FQDN=`echo "$HTTPS_URL" | awk -F/ '{print $3}'`
    http_code=$(awk '{print $1}' $CURL_INFO)
    server_ip=$(awk '{print $2}' $CURL_INFO)
    port_num=$(awk '{print $3}' $CURL_INFO)
    dcmLog "Curl Connected to $FQDN ($server_ip) port $port_num"
    dcmLog "Curl return code with $msg_tls_source: $TLSRet, http code: $http_code"
    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            tlsLog "CERTERR, DCM, $TLSRet, $FQDN"
            t2ValNotify "certerr_split" "DCM, $TLSRet, $FQDN"
            ;;

    esac
}

checkCodebigAccess() 
{
    local request_type=3
    local retval=0
    eval "GetServiceUrl $request_type temp > /dev/null 2>&1"
    local checkExitcode=$?
    dcmLog "Exit code for codebigcheck $checkExitcode"
    if [ $checkExitcode -eq 255 ]; then
        retval=1
    fi
    return $retval
}

DoCodebig()
{
    SIGN_CMD="GetServiceUrl 3 \"$JSONSTR\""
    eval $SIGN_CMD > /tmp/.signedRequest
    if [ -s /tmp/.signedRequest ]
    then
        dcmLog "GetServiceUrl success"
    else
        dcmLog "GetServiceUrl failed"
        exit 1
    fi
    CB_SIGNED_REQUEST=`cat /tmp/.signedRequest`
    rm -f /tmp/.signedRequest

    CB_SIGNED_REQUEST=`echo $CB_SIGNED_REQUEST | sed "s/http:/https:/g"`
    sendTLSDCMCodebigRequest $CB_SIGNED_REQUEST
}

sendHttpRequestToServer()
{
    resp=0
    FILENAME=$1
    URL=$2
    #Create json string
    JSONSTR='estbMacAddress='$(getEstbMacAddress)'&firmwareVersion='$(getFWVersion)'&env='$(getBuildType)'&model='$(getModel)'&ecmMacAddress='$(getECMMacAddress)'&controllerId='$(getControllerId)'&channelMapId='$(getChannelMapId)'&vodId='$(getVODId)'&timezone='$zoneValue'&partnerId='$(getPartnerId)'&accountId='$(getAccountId)'&experience='$(getExperience)'&version=2'
    #echo JSONSTR: $JSONSTR

    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/lib:/usr/local/lib

    # Generate curl command
    last_char=`echo $URL | awk '$0=$NF' FS=`
    if [ "$last_char" != "?" ]; then
        URL="$URL?"
    fi
        
    # Force https
    HTTPS_URL=`echo $URL | sed "s/http:/https:/g"`
    http_code="000"
    retries=0
    cbretries=0

    if [ $UseCodebig -eq 1 ]; then
        dcmLog "sendHttpRequestToServer: Codebig is enabled UseCodebig:$UseCodebig"
        dcmLog "Check if codebig is applicable for the Device"
        checkCodebigAccess
        codebigapplicable=$?
        if [ "$DEVICE_TYPE" = "mediaclient" -a $codebigapplicable -eq 0 ]; then
            # Use Codebig connection connection on XI platforms
            IsCodeBigBlocked
            skipcodebig=$?
            if [ $skipcodebig -eq 0 ]; then
                while [ $cbretries -le $CB_MAX_UPLOAD_ATTEMPTS ]
                do
                    dcmLog "sendHttpRequestToServer: Attempting Codebig DCM connection"
                    DoCodebig
                    ret=$TLSRet
                    http_code=$(awk '{print $1}' $CURL_INFO)
                    if [ "$http_code" = "200" ]; then
                        dcmLog "sendHttpRequestToServer: Codebig DCM connection success return:$ret, httpcode:$http_code"
                        IsDirectBlocked
                        skipDirect=$?
                        if [ $skipDirect -eq 0 ]; then
                            UseCodebig=0
                        fi
                        break
                    elif [ "$http_code" = "404" ]; then
                       dcmLog "sendHttpRequestToServer: Received 404 response for Codebig DCM connection, Retry logic not needed"
                       break
                    fi
                    dcmLog "sendHttpRequestToServer: Codebig DCM connection return: retry:$cbretries ret:$ret, httpcode:$http_code"
		    cbretries=`expr $cbretries + 1`
                    sleep 10
                done
            fi

            if [ "$http_code" = "000" ]; then
                dcmLog "sendHttpRequestToServer: Codebig DCM connection failed: httpcode:$http_code, attempting direct"
                IsDirectBlocked
                skipdirect=$?
                if [ $skipdirect -eq 0 ]; then
                    # try direct on the last time through
                    UseCodebig=0
                    sendTLSDCMRequest
                    ret=$TLSRet
                    http_code=$(awk '{print $1}' $CURL_INFO)
                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        dcmLog "sendHttpRequestToServer: Direct DCM connection failover attempt failed, return:$ret, httpcode:$http_code"
                    else
                        dcmLog "sendHttpRequestToServer: Direct DCM connection failover attempt received, return:$ret, httpcode:$http_code"
                    fi
                fi
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    dcmLog "sendHttpRequestToServer: Codebig blocking is released"
                fi
            elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                dcmLog "sendHttpRequestToServer: Codebig DCM Query failed with return=$ret, httpcode:$http_code"
            fi
        else
            dcmLog "sendHttpRequestToServer: Codebig DCM connection not supported"
        fi
    else
        dcmLog "sendHttpRequestToServer: Codebig is disabled: UseCodebig=$UseCodebig"
        IsDirectBlocked
        skipdirect=$?
        if [ $skipdirect -eq 0 ]; then
            while [ $retries -lt $MAX_UPLOAD_ATTEMPTS ]
            do
                dcmLog "sendHttpRequestToServer: Attempting direct DCM connection"
                sendTLSDCMRequest
                ret=$TLSRet
                http_code=$(awk '{print $1}' $CURL_INFO)
                if [ "$http_code" = "200" ];then
                    dcmLog "sendHttpRequestToServer: Direct DCM connection success, return:$ret, httpcode:$http_code"
                    break
                elif [ "$http_code" = "404" ]; then
                    dcmLog "sendHttpRequestToServer: Received 404 response for Direct DCM connection, Retry logic not needed"
                    break
                fi
                dcmLog "sendHttpRequestToServer: Direct DCM connection retry:$retries, return:$ret, httpcode:$http_code"
                retries=`expr $retries + 1`
                sleep 60
            done
        fi

        if [ "$http_code" = "000" ]; then
            dcmLog "Check if codebig is applicable for the Device"
            checkCodebigAccess
            codebigapplicable=$?
            if [ "$DEVICE_TYPE" = "mediaclient" -a $codebigapplicable -eq 0 ]; then
                dcmLog "sendHttpRequestToServer: Direct DCM connection failed: httpcode:$http_code, attempting Codebig"
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    while [ $cbretries -le $CB_MAX_UPLOAD_ATTEMPTS ]
                    do
                        dcmLog "sendHttpRequestToServer: Attempting Codebig DCM connection"
                        DoCodebig 
                        ret=$TLSRet
                        http_code=$(awk '{print $1}' $CURL_INFO)
                        if [ "$http_code" = "200" ]; then
                            dcmLog "sendHttpRequestToServer: Codebig DCM connection success return:$ret, httpcode:$http_code"
                            UseCodebig=1
                            if [ ! -f $DIRECT_BLOCK_FILENAME ]; then
                                touch $DIRECT_BLOCK_FILENAME
                                dcmLog "sendHttpRequestToServer: Use Codebig and Block Direct for 24 hrs"
                            fi
                            break
                        elif [ "$http_code" = "404" ]; then
                            dcmLog "sendHttpRequestToServer: Received 404 response for Codebig DCM connection, Retry logic not needed"
                            break
                        fi
                        dcmLog "sendHttpRequestToServer: Codebig DCM connection return: retry:$cbretries, ret:$ret, httpcode:$http_code"
                        cbretries=`expr $cbretries + 1`
                        sleep 10
                    done

                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        dcmLog "sendHttpRequestToServer: Codebig DCM connection failed return=$ret, httpcode:$http_code"
                        UseCodebig=0
                        if [ ! -f $CB_BLOCK_FILENAME ]; then
                            touch $CB_BLOCK_FILENAME
                            dcmLog "sendHttpRequestToServer: Switch Direct and Blocking Codebig for 30mins"
                        fi
                    fi
                fi
            else
                dcmLog "sendHttpRequestToServer: Codebig DCM connection not supported"
            fi
        elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
            dcmLog "sendHttpRequestToServer: Direct DCM connection failed return:$ret, httpcode:$http_code"
        fi
    fi

    if [ $ret = 0 ] && [ "$http_code" = "404" ] ; then
	resp=1
        touch $DCM_SKIP_RETRY_FLAG
    elif [ $ret -ne 0 -o "$http_code" != "200" ] ; then
        dcmLog "https request failed"
        rm -rf /tmp/DCMSettings.conf
        resp=1
    else
        dcmLog "https request success. Processing response.."
        # Process the JSON response
        processJsonResponse
        stat=$?
        dcmLog "processJsonResponse returned $stat"
        if [ "$stat" != 0 ] ; then
            dcmLog "Processing response failed."
            rm -rf /tmp/DCMSettings.conf
            resp=1
        else
            echo 1 > $DCMFLAG
        fi
    fi
    
    dcmLog "resp = $resp"
    return $resp
}

scheduleSupplementaryServices() 
{
    T2_DCM_CONFIG=$1
    cp $T2_DCM_CONFIG $FILENAME
    local OUTFILE='/tmp/DCMSettings.conf'
    processJsonResponse
    
    #--------------------------------- START : Derive URL For Upload Logs Based On Different RFC's And Value from Config  --------------------------------------------------
    # Cannot move away from all mTls and new device specific workarounds present today due to deployment complexity. Clean up effort will take care of this.

    upload_protocol=`cat $OUTFILE | grep 'LogUploadSettings:UploadRepository:uploadProtocol' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
    if [ -n "$upload_protocol" ]; then
        dcmLog "upload_protocol: $upload_protocol"
    else
        upload_protocol='HTTP'
        dcmLog "'urn:settings:LogUploadSettings:Protocol' is not found in DCMSettings.conf"
    fi
    if [ -z "$bootstrap_upload_httplink" ]; then
        httplink=`cat $OUTFILE | grep 'LogUploadSettings:UploadRepository:URL' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
        if [ -z "$httplink" ]; then
           dcmLog "'LogUploadSettings:UploadRepository:URL' is not found in DCMSettings.conf, upload_httplink is '$upload_httplink'"
           httplink=$upload_httplink
        else
           upload_httplink=$httplink
           dcmLog "upload_httplink is $upload_httplink"
        fi
    fi
    dcmLog "upload_httplink is $upload_httplink"
    #--------------------------------- END : Derive URL For Upload Logs Based On Different RFC's And Value from Config  --------------------------------------------------

    #Check the value of 'UploadOnReboot' in DCMSettings.conf
    uploadCheck=`cat $OUTFILE | grep 'urn:settings:LogUploadSettings:UploadOnReboot' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
    logUploadcron=`cat $OUTFILE | grep 'urn:settings:LogUploadSettings:UploadSchedule:cron' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
    difdCron=`cat $OUTFILE | grep 'urn:settings:CheckSchedule:cron' | cut -d '=' -f2`

    if [ "$uploadCheck" == "true" ] && [ "$reboot_flag" == "0" ]; then
        dcmLog "The value of 'UploadOnReboot' is 'true', executing script uploadSTBLogs.sh"
        nice -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 1 $upload_protocol $upload_httplink &
    elif [ "$uploadCheck" == "false" ] && [ "$reboot_flag" == "0" ]; then
        dcmLog "The value of 'UploadOnReboot' is 'false', executing script uploadSTBLogs.sh"
        nice  -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 0 $upload_protocol $upload_httplink &
    else 
        dcmLog "Nothing to do here for uploadCheck value = $uploadCheck"
    fi
    if [ -z "$logUploadcron" ] || [ "$logUploadcron" == "null" ]; then
        dcmLog "Uploading logs as DCM response is either null or not present"
        nice  -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 0 $upload_protocol $upload_httplink &
    else
        dcmLog "'UploadSchedule:cron' is present setting cron jobs "
        sh /lib/rdk/cronjobs_update.sh "update" "uploadSTBLogs.sh" "$logUploadcron nice -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 0 1 0 $upload_protocol $upload_httplink"
    fi

    if [ -n "$difdCron" ]; then
        dcmLog "Configuring cron job for swupdate_utility.sh"
        sh /lib/rdk/cronjobs_update.sh "update" "swupdate_utility.sh" "$difdCron /bin/sh $RDK_PATH/swupdate_utility.sh 0 2 >> /opt/logs/swupdate.log 2>&1"
    fi
}


#---------------------------------
#        Main App
#---------------------------------

if [ "x$T2_ENABLE" == "xtrue" ]; then

    PROCESS_CONFIG_COMPLETE_FLAG="/tmp/t2DcmComplete"
    T2_DCM_CONFIG="$PERSISTENT_PATH/.t2persistentfolder/DCMresponse.txt"

    t2Pid=`pidof $T2_0_APP`
    if [ -z "$t2Pid" ]; then
        dcmLog "${T2_BIN} is present, XCONF config fetch and parse will be handled by T2 implementation"
        t2Log "Clearing markers from $TELEMETRY_PATH"
        rm -rf $TELEMETRY_PATH
        mkdir -p $TELEMETRY_PATH
        mkdir -p $TELEMETRY_PATH_TEMP
        touch $T2_SERVICE_PATH
        #${T2_0_BIN}
    else
         mkdir -p $TELEMETRY_PATH_TEMP
         t2Log "telemetry daemon is already running .. Trigger from maintenance window."
         t2Log "Send signal 15 $T2_0_APP to restart for config fetch "
         kill -12 $t2Pid
    fi
    ## Clear any dca_utility.sh cron entries if present from T1.1 previous execution
    dcaCheck=`sh /lib/rdk/cronjobs_update.sh "check-entry" "dca_utility.sh"`
    if [ "$dcaCheck" != "0" ]; then
        sh /lib/rdk/cronjobs_update.sh "remove" "dca_utility.sh"
    fi
    
    ## Schedule rest of the secondary services as part of DCM .
    #1] Device initiated FW download 
    #2] Log upload cron 
    MAX_RETRY_T2_RESPONSE=12
    count=0
    t2_dcm_config=$PERSISTENT_PATH
    
    while [ ! -f $PROCESS_CONFIG_COMPLETE_FLAG ]
    do
        dcmLog "Wait for config fetch complete"
        sleep 10
        let count++
        if [ $count -eq $MAX_RETRY_T2_RESPONSE ]; then 
            break 
        fi
    done 
    scheduleSupplementaryServices $T2_DCM_CONFIG

    exit 0
fi

dcmLog "Waiting for IP"
#get timezone value
if [ -f ${RDK_PATH}/getTimeZone.sh ]; then
    . ${RDK_PATH}/getTimeZone.sh
fi
loop=1
counter=0
while [ $loop -eq 1 ]
do
    estbIp=`getIPAddress`
    if [ "X$estbIp" == "X" ]; then
         sleep 10
    else
         if [ "$IPV6_ENABLED" = "true" ]; then
               if [ "Y$estbIp" != "Y$DEFAULT_IP" ] && [ -f $WAREHOUSE_ENV ]; then
                   loop=0
               elif [ ! -f /tmp/estb_ipv4 ] && [ ! -f /tmp/estb_ipv6 ]; then
                   sleep 10
                   dcmLog "waiting for IPv6 IP"
                   let counter++
                   if [ "$counter" -eq 30 ] || [ "$counter" -eq 90 ]; then
                       sh $RDK_PATH/dca_utility.sh 0 0
                   fi
               elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv4 ]; then
                   dcmLog "waiting for IPv4 IP"
                   let counter++
                   if [ "$counter" -eq 30 ] || [ "$counter" -eq 90 ]; then
                       sh $RDK_PATH/dca_utility.sh 0 0
                   fi
                   sleep 10
               else
                   loop=0
               fi
          else
               if [ "Y$estbIp" == "Y$DEFAULT_IP" ]; then
                   sleep 10
                   let counter++
                   if [ "$counter" -eq 30 ] || [ "$counter" -eq 90 ]; then
                       sh $RDK_PATH/dca_utility.sh 0 0
                   fi
               else
                    loop=0
               fi
          fi
    fi

    # Do not keep spinning too long for RPI models 
    if [ "$BOX_TYPE" == "pi" ] && [ "$counter" -eq 6 ] ; then
        loop=0
    fi

done

# Enable telemetry profile creation during boot-up

UseCodebig=0

dcmLog "Check UseCodebig flag"
IsDirectBlocked
UseCodebig=$?

if [ ! $estbIp ] ;then
dcmLog "Waiting for IP"
fi

loop=1
while [ $loop -eq 1 ]
do
    ret=1
    if [ "$DEVICE_TYPE" != "mediaclient" ] && [ "$estbIp" == "$default_IP" ] ; then
        ret=0
    fi
    while [ $ret -ne 0 ]
    do
        sleep 1
        loop=0
        dcmLog "--------- box got an ip $estbIp"
        #Checking the value of 'checkon_reboot'
        #The value of 'checkon_reboot' will be 0, if the value of 'urn:settings:CheckOnReboot' is false in DCMSettings.conf
        #The value of 'checkon_reboot' will be always 1, if DCMscript.sh is executing from cronjob
        if [ $checkon_reboot -eq 1 ]; then
            sendHttpRequestToServer $FILENAME $URL
            ret=$?
            dcmLog "sendHttpRequestToServer returned $ret"
        else
            ret=0
            dcmLog "sendHttpRequestToServer has not executed since the value of 'checkon_reboot' is $checkon_reboot"
        fi                
        #If sendHttpRequestToServer method fails
        if [ $ret -ne 0 ]
        then
            dcmLog "Processing response failed."
            count=$((count + 1))
            if [ $count -ge $RETRY_COUNT ]; then
                dcmLog "$RETRY_COUNT tries failed. Giving up..."
                rm -rf $FILENAME $CURL_INFO

                if [ -f $PREVIOUS_CRON_FILE ]; then
                    cron=`cat $PREVIOUS_CRON_FILE | grep cron | cut -d ":" -f2`
                    sleep_time=`cat $PREVIOUS_CRON_FILE | grep sleep_time | cut -d ":" -f2`
                fi
                if [ $cron == "" ]; then
                    cron="*/15 * * * *"
                fi
                if [ -z $sleep_time ]; then
                    sleep_time=120
                fi
                sh /lib/rdk/cronjobs_update.sh "update" "dca_utility.sh" "$cron nice -n 19 sh $RDK_PATH/dca_utility.sh $sleep_time 1"

                sh $RDK_PATH/dca_utility.sh 0 1

                if [ "$reboot_flag" == "1" ];then
                    dcmLog "Exiting script."
                    echo 0 > $DCMFLAG
                    exit 0
                fi      
                dcmLog "Executing $RDK_PATH/uploadSTBLogs.sh."
                nice -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 0 1 $upload_protocol $upload_httplink &
                echo 0 > $DCMFLAG
                exit 1
            fi
            dcmLog "count = $count. Sleeping $RETRY_DELAY_DCM seconds ..."
            rm -rf $FILENAME $CURL_INFO
            sleep $RETRY_DELAY_DCM
            if [ "$reboot_flag" == "1" ];then
                dcmLog "Exiting script."
                echo 0 > $DCMFLAG
                exit 0
            fi
        else
            rm -rf $CURL_INFO
            if [ -f "/tmp/DCMSettings.conf" ]; then
                touch /tmp/.dcm_success
                #---------------------------------------------------------
                upload_protocol=`cat /tmp/DCMSettings.conf | grep 'LogUploadSettings:UploadRepository:uploadProtocol' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
                if [ -n "$upload_protocol" ]; then
                    dcmLog "upload_protocol: $upload_protocol"
                else
                    upload_protocol='HTTP'
                    dcmLog "'urn:settings:LogUploadSettings:Protocol' is not found in DCMSettings.conf"
                fi
                #---------------------------------------------------------
                if [ "$upload_protocol" == "HTTP" ]; then
                    if [  -z "$bootstrap_upload_httplink" ]; then
                    httplink=`cat /tmp/DCMSettings.conf | grep 'LogUploadSettings:UploadRepository:URL' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
                    if [ -z "$httplink" ]; then
                        dcmLog "'LogUploadSettings:UploadRepository:URL' is not found in DCMSettings.conf, upload_httplink is '$upload_httplink'"
			httplink=$upload_httplink 
                    else
                        upload_httplink=$httplink
                        dcmLog "upload_httplink is $upload_httplink"
                    fi
                    fi
                    dcmLog "upload_httplink is $upload_httplink"
                fi
                #---------------------------------------------------------
                #Check the value of 'UploadOnReboot' in DCMSettings.conf
                uploadCheck=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:UploadOnReboot' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
                cron=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:UploadSchedule:cron' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`

                if [ "$uploadCheck" == "true" ] && [ "$reboot_flag" == "0" ]; then
                    # Execute /sysint/uploadSTBLogs.sh with arguments $tftp_server and 1
                    dcmLog "The value of 'UploadOnReboot' is 'true', executing script uploadSTBLogs.sh"
                    nice -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 1 $upload_protocol $upload_httplink &
                elif [ "$uploadCheck" == "false" ] && [ "$reboot_flag" == "0" ]; then
                    # Execute /sysint/uploadSTBLogs.sh with arguments $tftp_server and 1
                    dcmLog "The value of 'UploadOnReboot' is 'false', executing script uploadSTBLogs.sh"
                    nice  -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 0 $upload_protocol $upload_httplink &
                else 
                    dcmLog "Nothing to do here for uploadCheck value = $uploadCheck"
                fi

                #If UploadSchedule:cron is not present in DCMSettings.conf, get the value of urn:settings:LogUploadSettings:UploadSchedule:levelthree:cron
                if [ -z "$cron" ] || [ "$cron" == "null" ]; then
                    dcmLog "'UploadSchedule:cron' is not present or null "
                    dcmLog "Uploading logs as DCM response is either null or not present"
                    rm $LOG_PATH/dcm_upload
                    nice  -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 1 1 0 $upload_protocol $upload_httplink &
                    echo 0 > $DCMFLAG
                else
                    cron_update=1 
                    dcmLog "'UploadSchedule:cron' is present setting cron jobs "
                    sh /lib/rdk/cronjobs_update.sh "update" "uploadSTBLogs.sh" "$cron nice -n 19 /bin/busybox sh $RDK_PATH/uploadSTBLogs.sh $tftp_server 0 1 0 $upload_protocol $upload_httplink"
                fi

                #Get the cornjob value
                #cron=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:UploadSchedule:levelone:cron' | cut -d '=' -f2`
                cron=''
                scheduler_Check=`grep '"schedule":' /tmp/DCMSettings.conf`
                if [ -n "$scheduler_Check" ]; then
                    cron=`cat /tmp/DCMSettings.conf | grep -i TelemetryProfile | awk -F '"schedule":' '{print $NF}' | awk -F "," '{print $1}' | sed 's/://g' | sed 's/"//g' | sed -e 's/^[ ]//' | sed -e 's/^[ ]//'`
                fi
                if [ -n "$cron" ]; then
                    cron_update=1 
                    #Get the cronjob time (minutes)
                    sleep_time=`echo "$cron" | awk -F '/' '{print $2}' | cut -d ' ' -f1`
                    if [ -n $sleep_time ]; then
                        sleep_time=`expr $sleep_time - 1` #Subtract 1 miute from it
                        sleep_time=`expr $sleep_time \* 60` #Make it to seconds
                        # Random sleeps should not be too long or greater than 2 mins - this might not be even needed 
                        # with the big data stack we have today but retaining for a safer side .
                        if [ $sleep_time -gt 120 ]; then 
                            sleep_time=120
                        fi
                        sleep_time=$(($RANDOM%$sleep_time)) #Generate a random value out of it
                    else
                        sleep_time=10
                    fi
                    sh /lib/rdk/cronjobs_update.sh "update" "dca_utility.sh" "$cron nice -n 19 sh $RDK_PATH/dca_utility.sh $sleep_time 1"
                    echo "cron:$cron" > $PREVIOUS_CRON_FILE
                    echo "sleep_time:$sleep_time" >> $PREVIOUS_CRON_FILE
                else
                    dcmLog "Failed to read \"schedule\" cronjob value from DCMSettings.conf."
                fi

                cron=''
                cron=`cat /tmp/DCMSettings.conf | grep 'urn:settings:CheckSchedule:cron' | cut -d '=' -f2`
                if [ -n "$cron" ]; then
                    cron_update=1 
                    dcmLog "Configuring cron job for swupdate_utility.sh"
                    sh /lib/rdk/cronjobs_update.sh "update" "swupdate_utility.sh" "$cron /bin/sh $RDK_PATH/swupdate_utility.sh 0 2 >> /opt/logs/swupdate.log 2>&1"
		fi	
                        
                if [ $cron_update -eq 1 ]; then
                    . /lib/rdk/ping-telemetry-monitor.sh setcron
                fi

            else
                dcmLog "/tmp/DCMSettings.conf file not found."
            fi
        fi
    done
    sleep 15
done

