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
. $RDK_PATH/logfiles.sh


if [ "$DEVICE_TYPE" != "mediaclient" ]; then
     . $RDK_PATH/interfaceCalls.sh
fi
if [ -f /lib/rdk/exec_curl_mtls.sh ]
then
   source /lib/rdk/exec_curl_mtls.sh
fi

MAC=`getMacAddressOnly`
dt=`date "+%m-%d-%y-%I-%M%p"`
LOG_FILE=$MAC"_Logs_$dt.tgz"

 echo "Triggered $(date)"   > /opt/loguploadstatus.txt
 
modifyFileWithTimestamp()
{
    srcLogPath=$1
    ret=`ls $srcLogPath/*.txt | wc -l`
    if [ ! $ret ]; then
         ret=`ls $srcLogPath/*.log | wc -l`
         if [ ! $ret ]; then
              if [ ! -f /etc/os-release ];then pidCleanup;fi
              exit 1
         fi
    fi

    dt=`date "+%m-%d-%y-%I-%M%p-"`
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
            echo "`/bin/timestamp` Processing file...$f"  >> $LOG_PATH/dcmscript.log
        else
            mv $f $dt$f
        fi
    done
    #cp /version.txt ./$dt$VERSION
}


HttpLogUpload()
{
    result=1
    FILENAME='/tmp/httpresult.txt'
    HTTP_CODE=/tmp/loguploadnow_curl_httpcode

    SSR_URL=$(tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.LogUpload.SsrUrl  2>&1)
    if [ -z $SSR_URL ]; then
        CLOUD_SSR_URL="$SSR_DEFAULT"
    else
        CLOUD_SSR_URL="$SSR_URL"
    fi
    CLOUD_URL='${CLOUD_SSR_URL}/cgi-bin/rdkb_snmp.cgi'
    EnableOCSPStapling="/tmp/.EnableOCSPStapling"
    EnableOCSP="/tmp/.EnableOCSPCA"

    if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
        CURL_CMD="-w '%{http_code}\n' -d \"filename=$1\" -o \"$FILENAME\" \"$CLOUD_URL\" --cert-status --connect-timeout 10 -m 10"
    else
        CURL_CMD="-w '%{http_code}\n' -d \"filename=$1\" -o \"$FILENAME\" \"$CLOUD_URL\" --connect-timeout 10 -m 10"
    fi
    echo "`/bin/timestamp` URL_CMD: $CURL_CMD" >> $LOG_PATH/dcmscript.log
    
    retries=0
    while [ "$retries" -lt 3 ]
    do        
        ret= ` exec_curl_mtls "$CURL_CMD" "echo"`
        http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
        if [ $http_code -eq 200 ];then
            break
        fi
        retries=`expr $retries + 1`
        echo "`/bin/timestamp` Retrying SNMP based HTTP log upload - $retries" >> $LOG_PATH/dcmscript.log
        sleep 1
    done
    
    if [ $http_code -eq 200 ];then
        echo "`/bin/timestamp` S3 upload query success. Got new S3 url to upload log" >> $LOG_PATH/dcmscript.log
        #Get the url from FILENAME
        NewUrl=$(awk -F\" '{print $1}' $FILENAME)
        if [ -f $EnableOCSPStapling ] || [ -f $EnableOCSP ]; then
            CURL_CMD="-w '%{http_code}\n' -T \"$1\" -o \"$FILENAME\" \"$NewUrl\" --cert-status --connect-timeout 60 -m 120 -v"
        else
            CURL_CMD="-w '%{http_code}\n' -T \"$1\" -o \"$FILENAME\" \"$NewUrl\" --connect-timeout 60 -m 120 -v"
        fi
        echo "`/bin/timestamp` URL_CMD: $CURL_CMD" >> $LOG_PATH/dcmscript.log

        ret=` exec_curl_mtls "$CURL_CMD" "echo"`
        http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
        if [ $http_code -eq 200 ];then
            result=0
			echo "`/bin/timestamp` Uploaded Logs through - SNMP/TR69" >> $LOG_PATH/dcmscript.log
            echo "Complete $(date)"   > /opt/loguploadstatus.txt

        else
            echo "`/bin/timestamp` Failed Uploading Logs through - SNMP/TR69" >> $LOG_PATH/dcmscript.log
			echo "Failed $(date)" > /opt/loguploadstatus.txt

        fi
    else
        echo "`/bin/timestamp` S3 upload query Failed" >> $LOG_PATH/dcmscript.log
        echo "Failed $(date)" > /opt/loguploadstatus.txt

    fi


    echo $result
}

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

mkdir -p $DCM_LOG_PATH

copyAllFiles

cd $DCM_LOG_PATH

 
echo "`/bin/timestamp` Uploading Logs through SNMP/TR69 Upload" >> $LOG_PATH/dcmscript.log
modifyFileWithTimestamp $DCM_LOG_PATH >> $LOG_PATH/dcmscript.log  2>&1
tar -zcvf $LOG_FILE * >> $LOG_PATH/dcmscript.log  2>&1
	   
 retval=1
echo "In progress $(date)" > /opt/loguploadstatus.txt
 retval=$(HttpLogUpload $LOG_FILE) 
 
if [ -d $DCM_LOG_PATH ]; then
    rm -rf $DCM_LOG_PATH/
fi
 
