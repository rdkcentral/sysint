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

#Source Default and Common Variable
. /etc/include.properties
. /etc/device.properties

#Source Default and Common Functions
. $RDK_PATH/utils.sh
. $RDK_PATH/logfiles.sh

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

if [ -f $RDK_PATH/exec_curl_mtls.sh ]; then
        source $RDK_PATH/exec_curl_mtls.sh
fi

if [ "$DEVICE_TYPE" != "mediaclient" ]; then
    . $RDK_PATH/interfaceCalls.sh
    . $RDK_PATH/utils.sh
fi

#Assign Input Arguments
TFTP_SERVER=$1
FLAG=$2
DCM_FLAG=$3
UploadOnReboot=$4
UploadProtocol=$5
UploadHttpLink=$6
TriggerType=$7
RRD_FLAG=$8
RRD_UPLOADLOG_FILE=$9


#Initialze Variables
MAC=`getMacAddressOnly`
HOST_IP=`getIPAddress`
DT=`date "+%m-%d-%y-%I-%M%p"`
LOG_FILE=$MAC"_Logs_$DT.tgz"
DRI_LOG_FILE=$MAC"_DRI_Logs_$DT.tgz"
DRI_LOG_PATH="/opt/logs/drilogs"
VERSION="version.txt"
PREV_LOG_PATH="$LOG_PATH/PreviousLogs"
PREV_LOG_BACKUP_PATH="$LOG_PATH/PreviousLogs_backup/"
DCM_UPLOAD_LIST="$LOG_PATH/dcm_upload"
DCM_LOG_FILE=$LOG_PATH/dcmscript.log
TELEMETRY_PATH="/opt/.telemetry"
timeValuePrefix=""
CURL_INFO=/tmp/logupload_curl_info
TLS=""
CLOUD_URL=""
CURL_TLS_TIMEOUT=30
CURL_TIMEOUT=10
useXpkiMtlsLogupload=false
encryptionEnable=false
CB_NUM_UPLOAD_ATTEMPTS=1
DIRECT_BLOCK_FILENAME="/tmp/.lastdirectfail_upl"
CB_BLOCK_FILENAME="/tmp/.lastcodebigfail_upl"
PREVIOUS_REBOOT_INFO="/opt/secure/reboot/previousreboot.info"
UNSCHEDULEDREBOOT_TR181_NAME='Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.UploadLogsOnUnscheduledReboot.Disable'
TIMESTAMP=`date "+%Y-%m-%d-%H-%M-%S%p"`
RRD_LOG_FILE="$LOG_PATH/remote-debugger.log"
RRD_TR181_NAME="Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.RDKRemoteDebugger.IssueType"
ISSUETYPE=`tr181 ${RRD_TR181_NAME} 2>&1 > /dev/null | sed 's/\./_/g' | tr 'a-z' 'A-Z'`
RRD_LOG_DIR="/tmp/rrd/"
TLS_LOG_FILE="$LOG_PATH/tlsError.log"
IARM_EVENT_BINARY_LOCATION=/usr/bin
upload_flag="true"
prevUploadFlag=0
EnableOCSPStapling="/tmp/.EnableOCSPStapling"
EnableOCSP="/tmp/.EnableOCSPCA"
HTTP_CODE=/tmp/logupload_http_code
# Log upload states
LOG_UPLOAD_SUCCESS=0
LOG_UPLOAD_FAILED=1
LOG_UPLOAD_ABORTED=2

#Common Logging Function
uploadLog() {
    echo "`/bin/timestamp` : $0: $*" >> $DCM_LOG_FILE
}

tlsLog() {
    echo "`/bin/timestamp` : $0: $*" >> $TLS_LOG_FILE
}

# we limit the attempt to 1 when called as a part of logupload before deepsleep
if [ "$TriggerType" != "1" ]; then
    NUM_UPLOAD_ATTEMPTS=3
    uploadLog "Called with $NUM_UPLOAD_ATTEMPTS attempts"
else
    NUM_UPLOAD_ATTEMPTS=1
    uploadLog "Called from Plugin with $NUM_UPLOAD_ATTEMPTS attempt"
fi

#Check for input Arguments
if [ ! -z "$TriggerType" ]; then
    if [ $# -ne 9 ];then
        uploadLog "USAGE: $0 <TFTP Server IP> <Flag (STB delay or not)> <SCP_SERVER> <UploadOnReboot> <UploadProtocol>  <UploadHttpLink> <TriggerType> <RRD_FLAG> <RRD_UPLOADLOG_FILE>"
    fi
elif [ $# -ne 8 ];then
    uploadLog "USAGE: $0 <TFTP Server IP> <Flag (STB delay or not)> <SCP_SERVER> <UploadOnReboot> <UploadProtocol> <UploadHttpLink> <RRD_FLAG> <RRD_UPLOADLOG_FILE>"
fi

#Replace Initialized Variables
if [ -f /etc/os-release ]; then
    TLS="--tlsv1.2"
fi

if [ ! -f /etc/os-release ]; then
    IARM_EVENT_BINARY_LOCATION=/usr/local/bin
fi

if [ -f /etc/os-release ]; then
    encryptionEnable=`tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.EncryptCloudUpload.Enable 2>&1 > /dev/null`
fi

eventSender()
{
    if [ -f $IARM_EVENT_BINARY_LOCATION/IARM_event_sender ];then
        $IARM_EVENT_BINARY_LOCATION/IARM_event_sender $1 $2
    fi
}

#PID Cleanup function
pidCleanup()
{
    # PID file cleanup
    exit_code=$?
    if [ $exit_code != 1 ]; then
        if [ -f /tmp/.log-upload.pid ]; then
            rm -rf /tmp/.log-upload.pid
        fi
    fi
}

trap pidCleanup EXIT

# exit if an instance is already running
if [ ! -f /tmp/.log-upload.pid ]; then
    # store the PID
    echo $$ > /tmp/.log-upload.pid
else
    pid=`cat /tmp/.log-upload.pid`
    if [ -d /proc/$pid -a -f /proc/$pid/cmdline ];then
	processName=`cat /proc/$pid/cmdline`
        uploadLog "proc entry process name: $processName and running process name `basename $0`"
        if echo "$processName" | grep -q `basename $0`; then
            uploadLog "Another instance of this app $0 is already running..!"
	    uploadLog "Exiting without starting the $0..!"
            if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
                MAINT_LOGUPLOAD_INPROGRESS=16
                eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_INPROGRESS
            fi
            exit 1
        fi
    fi
    echo $$ > /tmp/.log-upload.pid
fi

#get telemetry opt out status
getOptOutStatus()
{
    optoutStatus=0
    currentVal="false"
    #check if feature is enabled through rfc
    rfcStatus=$(tr181Set Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.TelemetryOptOut.Enable 2>&1 > /dev/null)
    #check the current option
    if [ -f /opt/tmtryoptout ]; then
        currentVal=$(cat /opt/tmtryoptout)
    fi
    if [ "x$rfcStatus" == "xtrue" ]; then
        if [ "x$currentVal" == "xtrue" ]; then
            optoutStatus=1
        fi
    fi
    return $optoutStatus
}

#MTLS Upload Check
checkXpkiMtlsBasedLogUpload()
{
   useXpkiMtlsLogupload=$(check_MtlsBasedLogUpload)
   uploadLog "xpki based mtls support = $useXpkiMtlsLogupload"
}


#Direct and Codebig Communication Functions
IsDirectBlocked()
{
    directret=0
    if [ -f $DIRECT_BLOCK_FILENAME ]; then
        modtime=$(($(date +%s) - $(date +%s -r $DIRECT_BLOCK_FILENAME)))
        remtime=$((($DIRECT_BLOCK_TIME/3600) - ($modtime/3600)))
        if [ "$modtime" -le "$DIRECT_BLOCK_TIME" ]; then
            uploadLog "Last direct failed blocking is still valid for $remtime hrs, preventing direct"
            directret=1
        else
            uploadLog "Last direct failed blocking has expired, removing $DIRECT_BLOCK_FILENAME, allowing direct"
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
            uploadLog "Last Codebig failed blocking is still valid for $cbremtime mins, preventing Codebig"
            codebigret=1
        else
            uploadLog "Last Codebig failed blocking has expired, removing $CB_BLOCK_FILENAME, allowing Codebig"
            rm -f $CB_BLOCK_FILENAME
        fi
    fi
    return $codebigret
}

#Check Flashed Version
getFWVersion()
{
    verStr=`cat /version.txt | grep ^imagename: | cut -d ":" -f 2`
    echo $verStr
}

#Modify the files with timestamp prefix
modifyFileWithTimestamp()
{
    srcLogPath=$1
    ret=`ls $srcLogPath/*.txt`
    if [ ! $ret ]; then
        ret=`ls $srcLogPath/*.log`
        if [ ! $ret ]; then
            uploadLog "Log directory empty, skipping log upload"
            if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
                MAINT_LOGUPLOAD_COMPLETE=4
                eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_COMPLETE
            fi
            exit 0
        fi
    fi

    DT=`date "+%m-%d-%y-%I-%M%p-"`
    FILES=*.*
    FILES1=".*-[0-9][0-9]AM-.*"
    FILES2=".*-[0-9][0-9]PM-.*"

    for f in $FILES
    do
        test1=0
        test2=0
        test3=0
        test4=0

        test1=`expr match $f $FILES1`
        test2=`expr match $f $FILES2`
        test3=`expr match $f $rebootLog`
        test4=`expr match $f $ablReasonLog`

        if [ $test1 -gt 0 -o $test2 -gt 0 -o $test3 -gt 0 -o $test4 -gt 0 ];  then
            uploadLog "Processing file...$f"
        else
            mv $f $DT$f
        fi
    done
    timeValuePrefix="$DT"
}

#Convert filenames to original form without timestamp
modifyTimestampPrefixWithOriginalName()
{
    srcLogPath=$1
    ret=`ls $srcLogPath/*.txt`
    if [ ! $ret ]; then
        ret=`ls $srcLogPath/*.log`
        if [ ! $ret ]; then
            uploadLog "Log directory empty, skipping log upload"
            if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
                MAINT_LOGUPLOAD_COMPLETE=4
                eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_COMPLETE
            fi
            exit 0
        fi
    fi
    FILES=*.*
    cd $srcLogPath
    len=`echo ${#timeValuePrefix}`
    len=`expr $len + 1`
    for f in $FILES
    do
        originalName=`echo $f| cut -c$len-`
        mv $f $originalName
    done
    cd -
}

#Function to copy all file
copyAllFiles ()
{
    EXCLUDE="dcm PreviousLogs_backup PreviousLogs"
    cd $LOG_PATH
    for fileName in *
    do
        COPY_BOOLEAN=true
        for excl in $EXCLUDE
        do
            if [ $excl == $fileName ]; then
              COPY_BOOLEAN=false
            fi
        done
        if $COPY_BOOLEAN; then
           cp -R $fileName $DCM_LOG_PATH
        fi
    done
}

#Function to copy opt folder logs
copyOptLogsFiles ()
{
    cd $LOG_PATH
    cp  * $DCM_LOG_PATH >> $LOG_PATH/dcmscript.log  2>&1
}

#Log TLS Return value for curl requests
logTLSError ()
{
    TLSRet=$1
    server=$2
    fqdn=$3
    case $TLSRet in
        35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
            tlsLog "CERTERR, STBLogUL, $TLSRet, $fqdn"
            t2ValNotify "certerr_split" "STBLogUL, $TLSRet, $fqdn"
            ;;
    esac
}

#TLS Function for Codebig communication
sendTLSSSRCodebigRequest()
{
    POST_URL=$1
    URLENCODE_STRING=""
    if [ "$S3_MD5SUM" != "" ]; then
        URLENCODE_STRING="--data-urlencode \"md5=$S3_MD5SUM\""
    fi

    uploadLog "Attempting $TLS connection to Codebig SSR server"
    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        CURL_CMD="curl $TLS -w '%{http_code} %{remote_ip} %{remote_port}\n' -d \"filename=$2\" $URLENCODE_STRING -o \"$FILENAME\" -H '$authorizationHeader'  \"$POST_URL\" --cert-status --connect-timeout $CURL_TLS_TIMEOUT -m 10"
    else
        CURL_CMD="curl $TLS -w '%{http_code} %{remote_ip} %{remote_port}\n' -d \"filename=$2\" $URLENCODE_STRING -o \"$FILENAME\" -H '$authorizationHeader'  \"$POST_URL\" --connect-timeout $CURL_TLS_TIMEOUT -m 10"
    fi
    uploadLog "CURL_CMD: $CURL_CMD"
    eval $CURL_CMD > $CURL_INFO
    TLSRet=$?
    FQDN=`echo "$POST_URL"|awk -F/ '{print $3}'`
    http_code=$(awk '{print $1}' $CURL_INFO)
    server_ip=$(awk '{print $2}' $CURL_INFO)
    port_num=$(awk '{print $3}' $CURL_INFO)
    uploadLog "Curl Connected to $FQDN ($server_ip) port $port_num"
    uploadLog "Curl return code: $TLSRet, http code: $http_code"

    if [ "$TLSRet" != 0 ]; then
        t2CountNotify "LUCurlErr_split"
    fi
    logTLSError $TLSRet "Codebig SSR" $FQDN
}

#TLS Function for Direct communication
sendTLSSSRRequest()
{
    TLSRet=1
    URLENCODE_STRING=""
    uploadLog "RFC_EncryptCloudUpload_Enable:$encryptionEnable"
    if [ "$S3_MD5SUM" != "" ]; then
        URLENCODE_STRING="--data-urlencode \"md5=$S3_MD5SUM\""
    fi

    uploadLog "Attempting $TLS connection to SSR server"
    checkXpkiMtlsBasedLogUpload

    uploadLog "Log Upload requires Mutual Authentication"
    if [ "$useXpkiMtlsLogupload" == "true" ]; then
          msg_tls_source="mTLS certificate from xPKI"
          uploadLog "Connect with $msg_tls_source"
          t2CountNotify "SYST_INFO_mtls_xpki"
          CURL_CMD="-w '%{http_code} %{remote_ip} %{remote_port}\n' -d \"filename=$1\" $URLENCODE_STRING -o \"$FILENAME\" \"$CLOUD_URL\" --connect-timeout $CURL_TLS_TIMEOUT -m 10"
    fi
    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        CURL_CMD="$CURL_CMD --cert-status"
    fi
    if [ "$useXpkiMtlsLogupload" == "true" ]; then
          TLSRet=` exec_curl_mtls "$CURL_CMD" "uploadLog"`
          cat $HTTP_CODE > $CURL_INFO
    fi
    FQDN=`echo "$CLOUD_URL" |awk -F/ '{print $3}'`
    http_code=$(awk '{print $1}' $CURL_INFO)
    server_ip=$(awk '{print $2}' $CURL_INFO)
    port_num=$(awk '{print $3}' $CURL_INFO)
    uploadLog "Curl Connected to $FQDN ($server_ip) port $port_num"
    uploadLog "Connect with $msg_tls_source Curl return code: $TLSRet, http code: $http_code"

    if [ "$TLSRet" == 28 ]; then
        t2CountNotify "SYST_ERR_Curl28"
    fi
    logTLSError $TLSRet "SSR" $FQDN
}

#Check if Codebig is allowed
checkCodebigAccess()
{
    local request_type=1
    local retval=0
    eval "GetServiceUrl $request_type temp > /dev/null 2>&1"
    local checkExitcode=$?
    uploadLog "Exit code for codebigcheck $checkExitcode"
    if [ $checkExitcode -eq 255 ]; then
        retval=1
    fi
    return $retval
}

#Create Codebig URL
DoCodebigSSR()
{
    SIGN_CMD="GetServiceUrl 1 \"$UploadHttpParams?filename=$1$uploadfile_md5\""
    eval $SIGN_CMD > /tmp/.signedRequest
    CB_CLOUD_URL=`cat /tmp/.signedRequest`
    rm -f /tmp/.signedRequest

    authorizationHeader=`echo $CB_CLOUD_URL | sed -e "s|&|\", |g" -e "s|=|=\"|g" -e "s|.*filename|filename|g"`
    authorizationHeader="Authorization: OAuth realm=\"\", $authorizationHeader\""
    POST_URL=`echo $CB_CLOUD_URL | sed -e "s|?.*||g"`

    sendTLSSSRCodebigRequest $POST_URL $1
}

#Function to INterrupt upload when maintainence error
if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
    interrupt_logupload_onabort()
    {
        uploadLog "LogUpload is interrupted due to the maintenance abort"

        #kill the sleep PID
        if [ -v sleep_pid ]; then
            kill "$sleep_pid"
        fi

        trap - SIGABRT

        exit
    }
fi

# Perform STB Logs upload using HTTP method
HttpLogUpload()
{
    result=1
    FILENAME='/tmp/httpresult.txt'
    CLOUD_URL=`/usr/bin/tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.LogUploadEndpoint.URL 2>&1 > /dev/null`
    if [ -z $CLOUD_URL ]; then
        CLOUD_URL=`echo $UploadHttpLink | sed "s/http:/https:/g"`
        uploadLog "CLOUD_URL from tr181 is empty. Get from DCMSettings: $CLOUD_URL"
    fi    
    domainName=`echo $CLOUD_URL | awk -F/ '{print $3}'`
    UploadHttpParams=`echo $CLOUD_URL | sed -e "s|.*$domainName||g"`
    http_code="000"
    retries=0
    cbretries=0

    S3_MD5SUM=""
    uploadLog "RFC_EncryptCloudUpload_Enable:$encryptionEnable"
    if [ "$encryptionEnable" == "true" ]; then
        S3_MD5SUM="$(openssl md5 -binary < $1 | openssl enc -base64)"
        uploadfile_md5="&md5=$S3_MD5SUM"
    fi

    if [ $UseCodebig -eq 1 ]; then
        uploadLog "HttpLogUpload: Codebig is enabled UseCodebig=$UseCodebig"
        uploadLog "check if codebig is supported in the device"
        checkCodebigAccess
        codebigapplicable=$?
        if [ "$DEVICE_TYPE" = "mediaclient" -a $codebigapplicable -eq 0 ]; then
            # Use Codebig connection connection on XI platforms
            IsCodeBigBlocked
            skipcodebig=$?
            if [ $skipcodebig -eq 0 ]; then
                while [ "$cbretries" -le $CB_NUM_UPLOAD_ATTEMPTS ]
                do
                    uploadLog "HttpLogUpload: Attempting Codebig log upload"
                    DoCodebigSSR $1
                    http_code=$(awk '{print $1}' $CURL_INFO)
                    if [ "$http_code" = "200" ]; then      # anything other than success causes retries
                        uploadLog "HttpLogUpload: Codebig log upload Success: ret=$ret httpcode=$http_code"
                        IsDirectBlocked
                        skipDirect=$?
                        if [ $skipDirect -eq 0 ]; then
                            UseCodebig=0
                        fi
                        break
                    elif [ "$http_code" = "404" ]; then
                        uploadLog "HttpLogUpload: Received 404 response for Codebig log upload, Retry logic not needed"
                        break
                    fi
                    uploadLog "HttpLogUpload: Codebig log upload return: retry=$cbretries, httpcode=$http_code"
                    cbretries=`expr $cbretries + 1`
                    sleep 10
                done
            fi

            if [ "$http_code" = "000" ];then
                IsDirectBlocked
                skipdirect=$?
                if [ $skipdirect -eq 0 ]; then
                    UseCodebig=0
                    uploadLog "HttpLogUpload: Codebig log upload failed: httpcode=$http_code, attempting direct"
                    sendTLSSSRRequest $1
                    ret=$TLSRet
                    http_code=$(awk '{print $1}' $CURL_INFO)
                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        uploadLog "HttpLogUpload: Direct log attempt failover failed return=$ret, httpcode=$http_code"
                    else
                        uploadLog "HttpLogUpload: Direct log attempt failover received return=$ret, httpcode=$http_code"
                    fi
                fi
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    uploadLog "HttpLogUpload: Codebig block released"
                fi
            elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                uploadLog "HttpLogUpload: Codebig log upload failed with httpcode=$http_code"
            fi
        else
            uploadLog "HttpLogUpload: Codebig log upload is not supported"
        fi
    else
        uploadLog "HttpLogUpload: Codebig is disabled UseCodebig=$UseCodebig"
        IsDirectBlocked
        skipdirect=$?
        if [ $skipdirect -eq 0 ]; then
            while [ "$retries" -lt $NUM_UPLOAD_ATTEMPTS ]
            do
                uploadLog "HttpLogUpload: Attempting direct log upload"
		t2CountNotify "SYST_INFO_LUattempt"
                sendTLSSSRRequest $1
                ret=$TLSRet
                http_code=$(awk '{print $1}' $CURL_INFO)
                if [ "$http_code" = "200" ];then       # anything other than success causes retries
                    uploadLog "HttpLogUpload: Direct log upload Success: httpcode=$http_code"
                    t2CountNotify "SYST_INFO_lu_success"
                    break
                elif [ "$http_code" = "404" ]; then
                    uploadLog "HttpLogUpload: Received 404 response for Direct log upload, Retry logic not needed"
                    break
                fi
                retries=`expr $retries + 1`
                 uploadLog "HttpLogUpload: Direct log upload attempt return: retry=$retries, httpcode=$http_code"
                sleep 60
            done
        fi

        if [ "$http_code" = "000" ]; then
            uploadLog "check if codebig is supported in the device"
            checkCodebigAccess
            codebigapplicable=$?
            if [ "$DEVICE_TYPE" = "mediaclient" -a $codebigapplicable -eq 0 ]; then      # only fallback if server doesn't respond
                IsCodeBigBlocked
                skipcodebig=$?
                if [ $skipcodebig -eq 0 ]; then
                    while [ "$cbretries" -le $CB_NUM_UPLOAD_ATTEMPTS ]
                    do
                        uploadLog "HttpLogUpload: Direct log upload failed: httpcode=$http_code, attempting Codebig"
                        DoCodebigSSR $1
			http_code=$(awk '{print $1}' $CURL_INFO)
                        if [ "$http_code" = "200" ]; then
                            uploadLog "HttpLogUpload: CodeBig log upload Success: httpcode=$http_code "
                            UseCodebig=1
                            if [ ! -f $DIRECT_BLOCK_FILENAME ]; then
                                uploadLog "HttpLogUpload: Use CodeBig and Blocking Direct attempts for 24hrs"
                                touch $DIRECT_BLOCK_FILENAME
                            fi
                            break
                        elif [ "$http_code" = "404" ]; then
                            uploadLog "HttpLogUpload: Received 404 response for Codebig log upload, Retry logic not needed"
                            break
                        fi
                        uploadLog "HttpLogUpload: Codebig failover attempt return retry=$cbretries, httpcode=$http_code"
                        cbretries=`expr $cbretries + 1`
                        sleep 10
                    done

                    if [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
                        uploadLog "HttpLogUpload: Codebig log upload Failed: httpcode=$http_code"
                        UseCodebig=0
                        if [ ! -f $CB_BLOCK_FILENAME ]; then
                            uploadLog "HttpLogUpload: Switch Direct and Blocking Codebig for 30mins,"
                            touch $CB_BLOCK_FILENAME
                        fi
                    fi
                fi
            else
                uploadLog "HttpLogUpload: Codebig log upload is not supported"
            fi
        elif [ "$http_code" != "200" ] && [ "$http_code" != "404" ]; then
            uploadLog "HttpLogUpload: Direct log upload failed: httpcode=$http_code"
        fi
    fi

    if [ "$http_code" = "200" ];then
        uploadLog "S3 upload query success. Got new S3 url to upload log"
        #Get the url from FILENAME
        if [ "$encryptionEnable" == "true" ]; then
            NewUrl=$(cat $FILENAME)
        else
            NewUrl=\"$(awk -F\" '{print $1}' $FILENAME)\"
        fi

        NewUrl=`echo $NewUrl | sed "s/http:/https:/g"`
        uploadLog "Attempting $TLS connection for Uploading Logs to S3 Amazon server"
        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
            CURL_CMD="curl $TLS -w '%{http_code} %{remote_ip} %{remote_port}\n' -T \"$1\" -o \"$FILENAME\" $NewUrl --cert-status --connect-timeout 60 -m 120 -v"
        else
            CURL_CMD="curl $TLS -w '%{http_code} %{remote_ip} %{remote_port}\n' -T \"$1\" -o \"$FILENAME\" $NewUrl --connect-timeout 60 -m 120 -v"
        fi
        
        #Modified the NewUrl value to remove the signature parameter & its value from loggging in to a decmscript.log file
        RemSignature=`echo $NewUrl | sed "s/AWSAccessKeyId=.*Signature=.*&//g;s/.*https/https/g"`
        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
            LogCurlCmd="curl $TLS -w '%{http_code} %{remote_ip} %{remote_port}\n' -T \"$1\" -o \"$FILENAME\" \"$RemSignature\" --cert-status --connect-timeout 60 -m 120 -v"
        else
            LogCurlCmd="curl $TLS -w '%{http_code} %{remote_ip} %{remote_port}\n' -T \"$1\" -o \"$FILENAME\" \"$RemSignature\" --connect-timeout 60 -m 120 -v"
        fi
        uploadLog "CURL_CMD: $LogCurlCmd"
        #RDK-20447 --End

        eval $CURL_CMD > $CURL_INFO
        ret=$?
	FQDN=`echo "$NewUrl"|awk -F/ '{print $3}'`
        logTLSError $ret "S3" $FQDN
        http_code=$(awk '{print $1}' $CURL_INFO)
        server_ip=$(awk '{print $2}' $CURL_INFO)
        port_num=$(awk '{print $3}' $CURL_INFO)
        uploadLog "Curl Connected to $FQDN ($server_ip) port $port_num"
        uploadLog "Curl return code: $ret, http code: $http_code"

        if [ "$ret" != 0 ]; then
            t2CountNotify "LUCurlErr_split"
        fi
        rm $FILENAME

	if [ "$ret" = "0" ] && [ "$http_code" = 200 ]; then
             t2CountNotify "TEST_lu_success"
        fi

        if [ "$http_code" = "200" ];then
            result=0
        else
            if [ "$DEVICE_TYPE" == "mediaclient" ]; then
                if [ "$encryptionEnable" == "true" ]; then
                    PROXY_BUCKET=`echo $PROXY_BUCKET | sed "s|unenc||g"`
                fi
                uploadLog "Trying logupload through Proxy server"
                S3_Bucket=`echo $CURL_CMD | sed "s|.*https://||g" | cut -d "/" -f1`
                CURL_CMD=`echo $CURL_CMD | sed "s|$S3_Bucket|$PROXY_BUCKET|g" | sed 's|?.*"|"|g'`
                LogCurlCmd=`echo $LogCurlCmd | sed "s|$S3_Bucket|$PROXY_BUCKET|g" | sed 's|?.*"|"|g'`
                uploadLog "CURL_CMD: $LogCurlCmd"

                eval $CURL_CMD > $CURL_INFO
                ret=$?
                http_code=$(awk '{print $1}' $CURL_INFO)
                server_ip=$(awk '{print $2}' $CURL_INFO)
                port_num=$(awk '{print $3}' $CURL_INFO)
                uploadLog "Curl Connected to $FQDN ($server_ip) port $port_num"
                uploadLog "Curl return code: $ret, http code: $http_code"
                rm $FILENAME

                if [ "$ret" != 0 ]; then
                    t2CountNotify "LUCurlErr_split"
                fi
                if [ "$ret" = "0" ] && [ "$http_code" = 200 ]; then
                      t2CountNotify "TEST_lu_success"
                fi

            fi
            if [ "$http_code" = "200" ];then
                uploadLog "LogUpload is successful"
                result=0
            else
                uploadLog "Failed Uploading Logs through - HTTP"
		t2CountNotify "SYST_ERR_LogUpload_Failed"
            fi
        fi
    else
        uploadLog "S3 upload query Failed"
    fi
   echo $result

}

# Retain only the last packet capture
clearOlderPacketCaptures()
{
    #Remove *.pcap files from /opt/logs
    pcapCount=`ls $LOG_PATH/*.pcap* | wc -l`
    ## Retain last packet capture
    if [ $pcapCount -gt 0 ]; then
        lastEasPcapCapture="$LOG_PATH/eas.pcap"
        lastMocaPcapCapture="$LOG_PATH/moca.pcap"
        ## Back up last packet capture
        if [ -f $lastEasPcapCapture ]; then
            mv $lastEasPcapCapture $lastEasPcapCapture.bkp
        fi
        if [ -f $lastMocaPcapCapture ]; then
            mv $lastMocaPcapCapture $lastMocaPcapCapture.bkp
        fi
        rm -f $LOG_PATH/*.pcap
        if [ -f $lastEasPcapCapture.bkp ]; then
            mv $lastEasPcapCapture.bkp $lastEasPcapCapture
        fi
        if [ -f $lastMocaPcapCapture.bkp ]; then
            mv $lastMocaPcapCapture.bkp $lastMocaPcapCapture
        fi
    fi

    rm -f $LOG_PATH/eas.pcap.*
}

#Perform Telemetry Logs Upload
uploadDCMLogs()
{
    cd $DCM_LOG_PATH

    if [ "$upload_flag" == "true" ]; then
        uploadLog "Uploading Logs through DCM cron job"
        modifyFileWithTimestamp $DCM_LOG_PATH >> $LOG_PATH/dcmscript.log  2>&1
        # Include latest moca-capture in uploaded logs for mediaclient device
        if [ "$DEVICE_TYPE" == "mediaclient" ]; then
            pcapCount=`ls $LOG_PATH/*-moca.pcap | wc -l`
            if [ $pcapCount -gt 0 ]; then
                lastPcapCapture=`ls -lst $LOG_PATH/*.pcap | head -n 1`
                lastPcapCapture=`echo ${lastPcapCapture##* }`
                cp $lastPcapCapture .
            fi
        fi
        tar -zcvf $LOG_FILE * >> $LOG_PATH/dcmscript.log  2>&1
        sleep 60
        uploadLog "Uploading logs $LOG_FILE  onto $TFTP_SERVER"

        retval=1

        if [ "$UploadProtocol" == "HTTP" ]; then
            retval=$(HttpLogUpload $LOG_FILE)
            if [ $retval -eq 0 ]; then
                maintenance_error_flag=0
                uploadLog "Done Uploading Logs through HTTP"
            else
                maintenance_error_flag=1
            fi
        else
            uploadLog "UploadProtocol is not HTTP"
        fi
        clearOlderPacketCaptures
    fi

    if [ -d $DCM_LOG_PATH ]; then
        rm -rf $DCM_LOG_PATH/
    fi
}

#Function to Upload the logs when logondemand is true
uploadLogOnDemand()
{
    uploadLog=$1
    ret=`ls $LOG_PATH/*.txt`
    if [ ! $ret ]; then
        ret=`ls $LOG_PATH/*.log`
        if [ ! $ret ]; then
            uploadLog "Log directory empty, skipping log upload"
            if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
                MAINT_LOGUPLOAD_COMPLETE=4
                eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_COMPLETE
            fi
            exit 0
        fi
    fi

    TMP_PATH="/tmp/log_on_demand"
    mkdir -p $TMP_PATH
    cp $LOG_PATH/*.txt* $TMP_PATH
    cp $LOG_PATH/*.log* $TMP_PATH
    sleep 1
    ls $TMP_PATH >> /opt/logs/dcmscript.log
    TIMESTAMP=`date "+%m-%d-%y-%I-%M%p-logbackup"`
    PERM_LOG_PATH="$LOG_PATH/$TIMESTAMP"
    #RDKTV-9938: Moved the logbackup folder creation before move operation
    echo $PERM_LOG_PATH >> $TELEMETRY_PATH/lastlog_path
    cd $TMP_PATH
    if [ -f $LOG_FILE ]; then
        rm $LOG_FILE
    fi

    if [ "$uploadLog" == "true" ]; then
        uploadLog "Uploading Logs with ondemand log upload triggers from service manager"
        uploadLog "Logs will not be flushed or backed up to folder with timestamp"
        tar -zcvf $LOG_FILE * >> $LOG_PATH/dcmscript.log  2>&1
        sleep 2
        if [ "$UploadProtocol" == "HTTP" ];then
            # Call loguploader function and get return status
            retval=$(HttpLogUpload $LOG_FILE)
            if [ $retval -ne 0 ];then
                uploadLog "HTTP log upload failed"
                echo "Upload failed"
                t2CountNotify "SYST_ERR_LogUpload_Failed"
                maintenance_error_flag=1
            else
                maintenance_error_flag=0
                echo "Upload is successful"
            fi
        fi
    else
        uploadLog "Log uploads are disabled. Not Uploading Logs with DCM"
    fi
    cd $TMP_PATH
    if [ -f $TMP_PATH/$LOG_FILE ]; then
        rm -rf $TMP_PATH/$LOG_FILE
    fi
    
    uploadLog "Deleting from Temp Logs  Folder $TMP_PATH"
    if [ -d $TMP_PATH ]; then
        rm -rf $TMP_PATH
    fi
}

#Function to Upload Logs when Flag is true
uploadLogOnReboot()
{
    uploadLog=$1
    ret=`ls $PREV_LOG_PATH/*.txt`
    if [ ! $ret ]; then
        ret=`ls $PREV_LOG_PATH/*.log`
        if [ ! $ret ]; then
            uploadLog "Log directory empty, skipping log upload"
            if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
                MAINT_LOGUPLOAD_COMPLETE=4
                eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_COMPLETE
            fi
            exit 0
        fi
    fi
    uploadLog "Sleeping for seven minutes"
    if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
        #run sleep in a background job
        sleep 330 &
        # store and remember the sleep's PID
        sleep_pid="$!"
        # wait here for the sleep to complete
        wait
    else
        sleep 330
    fi
    uploadLog "Done sleeping"
    # Special processing - Permanently backup logs on box delete the logs older than
    # 3 days to take care of old filename
    stat=`find /opt/logs -name "*-*-*-*-*M-" -mtime +3 -exec rm -rf {} \;`
    # for the new filenames with suffix logbackup
    stat=`find /opt/logs -name "*-*-*-*-*M-logbackup" -mtime +3 -exec rm -rf {} \;`
    TIMESTAMP=`date "+%m-%d-%y-%I-%M%p-logbackup"`
    PERM_LOG_PATH="$LOG_PATH/$TIMESTAMP"
    #RDKTV-9938: Moved the logbackup folder creation before move operation
    echo $PERM_LOG_PATH >> $TELEMETRY_PATH/lastlog_path
    cd $PREV_LOG_PATH
    rm $LOG_FILE
    modifyFileWithTimestamp $PREV_LOG_PATH >> $LOG_PATH/dcmscript.log  2>&1

    reboot_reason=`cat $PREVIOUS_REBOOT_INFO | grep -i "Scheduled Reboot"`
    DISABLE_UPLOAD_LOGS_UNSHEDULED_REBOOT=`/usr/bin/tr181 -g $UNSCHEDULEDREBOOT_TR181_NAME 2>&1 > /dev/null`
    uploadLog "reboot_reason: $reboot_reason , uploadLog:$uploadLog and UploadLogsOnUnscheduledReboot.Disable RFC: $DISABLE_UPLOAD_LOGS_UNSHEDULED_REBOOT"
    if [ "$uploadLog" == "true" ] || [ -z "$reboot_reason" -a "$DISABLE_UPLOAD_LOGS_UNSHEDULED_REBOOT" == "false" ]; then
        uploadLog "Uploading Logs with DCM"
        if [ "$DEVICE_TYPE" == "mediaclient" ]; then
           pcapCount=`ls $LOG_PATH/*-moca.pcap | wc -l`
           if [ $pcapCount -gt 0 ]; then
               lastPcapCapture=`ls -lst $LOG_PATH/*.pcap | head -n 1`
               lastPcapCapture=`echo ${lastPcapCapture##* }`
               cp $lastPcapCapture .
           fi
        fi
        tar -zcvf $LOG_FILE * >> $LOG_PATH/dcmscript.log  2>&1
        sleep 60
        if [ "$UploadProtocol" == "HTTP" ];then
            retval=$(HttpLogUpload $LOG_FILE)
            if [ $retval -ne 0 ];then
                uploadLog "HTTP log upload failed"
                maintenance_error_flag=1
                t2CountNotify "SYST_ERR_LogUpload_Failed"
            else
                maintenance_error_flag=0
            fi
        fi
        if [ -d "$DRI_LOG_PATH" ]; then
            uploadLog "Uploading DRI logs through HTTP to S3 Server:$DRI_LOG_FILE"
            tar -zcvf $DRI_LOG_FILE $DRI_LOG_PATH/* >> $LOG_PATH/dcmscript.log  2>&1
            sleep 60
            driretval=$(HttpLogUpload $DRI_LOG_FILE)
            if [ $driretval -ne 0 ];then
                uploadLog "Uploading DRI Logs through HTTP Failed!!"
                t2CountNotify "SYST_INFO_PDRILogUpload"
            else
                uploadLog "Uploading DRI Logs through HTTP Success..."
                t2CountNotify "SYST_INFO_PDRILogUpload"
                rm -rf $DRI_LOG_PATH
            fi
        fi
        clearOlderPacketCaptures
    else
        uploadLog "Not Uploading Logs with DCM"
    fi
    cd $PREV_LOG_PATH
    sleep 5
    if [ -f $PREV_LOG_PATH/$LOG_FILE ]; then
        rm -rf $PREV_LOG_PATH/$LOG_FILE
    fi
    modifyTimestampPrefixWithOriginalName $PREV_LOG_PATH
    mkdir -p $PERM_LOG_PATH
    mv $PREV_LOG_PATH/* $PERM_LOG_PATH
    if [ -d $PREV_LOG_BACKUP_PATH ]; then
        rm -rf  $PREV_LOG_BACKUP_PATH
    fi
    mkdir -p $PREV_LOG_BACKUP_PATH
    uploadLog "Deleting from Previous Logs  Folder "
    if [ -d $PREV_LOG_PATH ]; then
        rm -rf $PREV_LOG_PATH/*
    fi
}

#############################################################
#                    MAIN FUNCTION                          #
#############################################################
UseCodebig=0
uploadLog "Check Codebig flag,,,"
IsDirectBlocked
UseCodebig=$?

if [ "$RRD_FLAG" -eq 1 ]; then
    DCM_LOG_FILE=$RRD_LOG_FILE
    uploadLog "Uploading RRD Debug Logs $RRD_UPLOADLOG_FILE to S3 SERVER"
    retval=1
    if [ "$UploadProtocol" == "HTTP" ];then
        retval=$(HttpLogUpload $RRD_UPLOADLOG_FILE)
        if [ $retval -eq 0 ];then
            uploadLog "Uploading Logs through HTTP Success..."
            exit 0
        else
            uploadLog "Uploading Logs through HTTP Failed!!!"
            exit 127
        fi
    else
        uploadLog "UploadProtocol is not HTTP"
        exit 127
    fi
else
    uploadLog "Build Type: $BUILD_TYPE Log file: $LOG_FILE UploadProtocol: $UploadProtocol UploadHttpLink: $UploadHttpLink"
    #Read Upload_Flag information
    if [ -f "/tmp/DCMSettings.conf" ]; then
        upload_flag=`cat /tmp/DCMSettings.conf | grep 'urn:settings:LogUploadSettings:upload' | cut -d '=' -f2 | sed 's/^"//' | sed 's/"$//'`
        uploadLog "upload_flag = $upload_flag"
    fi

    #Check for PreviousLogs Folder
    if [ ! -d $PREV_LOG_PATH ]; then
        uploadLog "The Previous Logs folder is missing"
        MAINT_LOGUPLOAD_ERROR=5
        eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
        exit 0
    fi

    #Check and Create Telemetry Path Folder
    if [ ! -d "$TELEMETRY_PATH" ]; then
        uploadLog "Telemetry Folder does not exist . Creating now"
        mkdir -p "$TELEMETRY_PATH"
    fi
    if [ ! -d $DCM_LOG_PATH ]; then
        uploadLog "DCM log Folder does not exist . Creating now"
        mkdir -p "$DCM_LOG_PATH"
    fi

    if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
        trap 'interrupt_logupload_onabort' SIGABRT
    fi

    #Check and delete old Telemetry path
    if [ -d $DCM_LOG_PATH ]; then
        rm -rf $DCM_LOG_PATH/
    fi

    #Remove *.tgz files from /opt/logs
    stat=`find $LOG_PATH -name "*.tgz" -exec rm -rf {} \;`
    clearOlderPacketCaptures

    #Remove files which have timestamp in it filename
    for item in `ls $LOG_PATH/*-*-*-*-*M-* | grep "[0-9]*-[0-9]*-[0-9]*-[0-9]*-M*" | grep -v "logbackup" | grep -v "moca.pcap"`;do
        if [ -f "$item" ]; then
            uploadLog "Removing $item"
            rm -rf $item
        fi
    done

    #privcaymodes check
    if [ "$DEVICE_TYPE" = "mediaclient" ]; then
        privacyMode=$(getPrivacyControlMode uploadLog)
        if [ "$privacyMode" = "DO_NOT_SHARE" ]; then
            uploadLog "Privacy Mode is $privacyMode. Logupload is disabled"
            #Empty the log files.
            for f in $LOG_PATH/*; do  >$f; done
            MAINT_LOGUPLOAD_COMPLETE=4
            eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_COMPLETE
            exit 0
        fi
    fi
    getOptOutStatus
    opt_out=$?
    if [ $opt_out -eq 1 ]; then
        uploadLog "Logupload is disabled as TelemetryOptOut is set"
        MAINT_LOGUPLOAD_COMPLETE=4
        eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_COMPLETE
        exit 0
    fi
    if [ $DCM_FLAG -eq 0 ] ; then
        uploadLog "Uploading Without DCM"
        uploadLogOnReboot true
    else
        if [ $FLAG -eq 1 ] ; then
            if [ $UploadOnReboot -eq 1 ]; then
                uploadLog "UploadOnReboot set to true"
                if [ $TriggerType -eq 5 ]; then
                    uploadLog "TriggerType set to logonDemand"
                    uploadLogOnDemand true
                else
                    uploadLogOnReboot true
                fi
            else
                uploadLog "UploadOnReboot set to false"
                maintenance_error_flag=1
                if [ $TriggerType -eq 5 ]; then
                    uploadLog "TriggerType set to logonDemand"
                    uploadLogOnDemand false
                else
                    uploadLogOnReboot false
                fi
                echo $PERM_LOG_PATH >> $DCM_UPLOAD_LIST
            fi
        else
            if [ $UploadOnReboot -eq 0 ]; then
                mkdir -p $DCM_LOG_PATH
                fileUploadCount=`cat "$DCM_UPLOAD_LIST" | wc -l`
                if [ $fileUploadCount -gt 0 ]; then
                    while read line
                    do
                        echo $line
                        cp -R $line $DCM_LOG_PATH
                        done < $DCM_UPLOAD_LIST
                        copyOptLogsFiles
                        cat /dev/null > $DCM_UPLOAD_LIST
                        uploadDCMLogs
                else
                    copyOptLogsFiles
                    uploadDCMLogs
                fi
            else
                touch $DCM_INDEX
                copyAllFiles
                uploadDCMLogs
            fi
        fi
    fi

    if [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
        trap - SIGABRT
    fi

    if [ "$maintenance_error_flag" -eq 1 ]; then
        eventSender "LogUploadEvent" $LOG_UPLOAD_FAILED
    else
        eventSender "LogUploadEvent" $LOG_UPLOAD_SUCCESS
    fi

    if [ "$DEVICE_TYPE" != "broadband" ] && [ "x$ENABLE_MAINTENANCE" == "xtrue" ]; then
        if [ "$maintenance_error_flag" -eq 1 ]; then
            MAINT_LOGUPLOAD_ERROR=5
            eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_ERROR
        else
            MAINT_LOGUPLOAD_COMPLETE=4
            eventSender "MaintenanceMGR" $MAINT_LOGUPLOAD_COMPLETE
        fi
    fi
fi

exit 0
