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
. /etc/dcm.properties

. $RDK_PATH/utils.sh

HTTP_CODE="/tmp/xconf_curl_httpcode"

getTelemetryEndpoint() {
    DEFAULT_DCA_UPLOAD_URL="$DCA_UPLOAD_URL"
    TelemetryEndpointURL=""
    TelemetryEndpoint=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.TelemetryEndpoint.Enable 2>&1 > /dev/null`
    if [ "x$TelemetryEndpoint" = "xtrue" ]; then
        TelemetryEndpointURL=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.TelemetryEndpoint.URL 2>&1 > /dev/null`
        if [ ! -z "$TelemetryEndpointURL" ]; then
            DCA_UPLOAD_URL="https://$TelemetryEndpointURL"
            echo "`/bin/timestamp` hddfail:dca upload url from RFC is $TelemetryEndpointURL" >> /tmp/disk_cleanup.log
            echo "`/bin/timestamp` hddfail:dca upload url from RFC is $TelemetryEndpointURL"
        fi
    else
        if [ -f "$TELEMETRY_PROFILE_DEFAULT_PATH" ]; then
            TelemetryEndpointURL=`grep '"uploadRepository:URL":"' $TELEMETRY_PROFILE_DEFAULT_PATH | awk -F 'uploadRepository:URL":' '{print $NF}' | awk -F '",' '{print $1}' | sed 's/"//g' | sed 's/}//g'`
        fi

        if [ ! -z "$TelemetryEndpointURL" ]; then
            DCA_UPLOAD_URL=`echo "$TelemetryEndpointURL" | sed "s/http:/https:/g"`
            echo "`/bin/timestamp` hddfail:dca upload url from dcmresponse is $TelemetryEndpointURL" >> /tmp/disk_cleanup.log
            echo "`/bin/timestamp` hddfail:dca upload url from dcmresponse is $TelemetryEndpointURL"
        fi
    fi
    if [ -z "$TelemetryEndpointURL" ]; then
        DCA_UPLOAD_URL="$DEFAULT_DCA_UPLOAD_URL"
    fi
}

# Function to get current image version
getFWVersion()
{
   verStr=`cat /version.txt | grep ^imagename:$FW_VERSION_TAG1`
   if [ $? -eq 0 ]
   then
       echo $verStr | cut -d ":" -f 2
   else
       cat /version.txt | grep ^imagename:$FW_VERSION_TAG2 | cut -d ":" -f 2
   fi
}

loop=1
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
                   echo "`/bin/timestamp` hddfail:waiting for IPv6 IP" >> /tmp/disk_cleanup.log
                   echo "`/bin/timestamp` hddfail:waiting for IPv6 IP"
               elif [ "Y$estbIp" == "Y$DEFAULT_IP" ] && [ -f /tmp/estb_ipv4 ]; then
                   echo "`/bin/timestamp` hddfail:waiting for IPv6 IP" >> /tmp/disk_cleanup.log
                   echo "`/bin/timestamp` hddfail:waiting for IPv6 IP"
                   sleep 10
               else
                   loop=0
               fi
          else
               if [ "Y$estbIp" == "Y$DEFAULT_IP" ]; then
                   echo "`/bin/timestamp` hddfail:waiting for IPv4 IP" >> /tmp/disk_cleanup.log
                   echo "`/bin/timestamp` hddfail:waiting for IPv4 IP"
                   sleep 10
               else
                   loop=0
               fi
          fi
    fi
done

estbMac=`getEstbMacAddress`
estbIp=`getIPAddress`
firmwareVersion=$(getFWVersion)
cur_time=`date "+%Y-%m-%d %H:%M:%S"`

JSONSTR="{\"searchResult\":[{\"HDDFailure\":\"HDD failed to mount or repair\"},{\"mac\":\"$estbMac\"},{\"StbIp\":\"$estbIp\"},{\"Version\":\"$firmwareVersion\"},{\"Time\":\"$cur_time\"}]}"
CURL_CMD="curl --tlsv1.2 -w '%{http_code}\n' -H \"Accept: application/json\" -H \"Content-type: application/json\" -X POST -d '$JSONSTR' -o \"/opt/.telemetry/dca_httpresult.txt\" \"$DCA_UPLOAD_URL\" --connect-timeout 30 -m 30"
echo "`/bin/timestamp` hddfail:CURL_CMD:$CURL_CMD"
echo "`/bin/timestamp` hddfail:CURL_CMD:$CURL_CMD" >> /tmp/disk_cleanup.log
eval $CURL_CMD > $HTTP_CODE
ret=$?
http_code=$(awk -F\" '{print $1}' $HTTP_CODE)
echo "`/bin/timestamp` hddfail:Curl return:$ret, http_code:$http_code"
echo "`/bin/timestamp` hddfail:Curl return:$ret, http_code:$http_code" >> /tmp/disk_cleanup.log

