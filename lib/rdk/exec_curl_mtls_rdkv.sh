#!/bin/sh

LOG_FOLDER="/opt"
. /etc/device.properties

UseSEBasedCert=`cat /etc/device.properties | grep UseSEBasedCert  | cut -f2 -d=`
if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

CURL_BIN=/usr/bin/curl
certlist0="/opt/certs/devicecert_2.pk12"
certlist1="/opt/certs/devicecert_1.pk12"
certlist2="/etc/ssl/certs/staticXpkiCrt.pk12"
passlist0="kjvrverlzhlo"
passlist1="kquhqtoczcbx"
passlist2="mamjwwgtfwpa"

getConfigFile_id1="/tmp/.cfgDynamicxpki"
getConfigFile_id2="/tmp/.cfgStaticxpki"

exec_curl_mtls () {
        CURL_ARGS=$1
        curl_log=$2
        TLSRet=1
        for certnum in 0 1 2 ; do
            eval cert="\$certlist$certnum"
            if [ ! -f $cert ] ; then
                if [[ "$cert" == "$certlist0" ]] && [ "$UseSEBasedCert" != "true" ]; then
                     $curl_log "Device operational cert2 not supported for $MODEL_NUM"
                else
                     $curl_log "$cert not found!!!"
                fi
                continue
            else
                eval passcode="\$passlist$certnum"

                if [ -x /usr/bin/rdkssacli ] ; then
                    CURL_CMD="$CURL_BIN --cert-type P12 --cert $cert:$(/usr/bin/rdkssacli "{STOR=GET,SRC=$passcode,DST=/dev/stdout}") $CURL_ARGS"
                elif [ -x /usr/bin/GetConfigFile ] ; then
                    eval ID="\$getConfigFile_id$certnum"
                    GetConfigFile $ID
                    if [ ! -f "$ID" ]; then
                       $curl_log "Getconfig failed for $cert"
                       continue
                    else
                       CURL_CMD="$CURL_BIN --cert-type P12 --cert $cert:$(cat $ID) $CURL_ARGS"
                    fi
                fi
                if [  "$cert" == "$certlist2" ] ; then
                    UPTIME=$(cut -d' ' -f1 /proc/uptime)
                    $curl_log "xPKIStaticCert: /etc/ssl/certs/staticDeviceCert.pk12 uptime $UPTIME seconds.$0"
                    if [ -f /lib/rdk/t2Shared_api.sh ]; then
                        t2ValNotify "SYS_INFO_xPKI_Static_Fallback" "xPKIStaticCert: /etc/ssl/certs/staticDeviceCert.pk12 uptime $UPTIME seconds,$0"
                    fi
                fi
                $curl_log "CURL_CMD: `echo "$CURL_CMD" | sed -e 's#devicecert_1.pk12[^[:space:]]\+#devicecert_1.pk12<hidden key>#g' \
                                       -e 's#devicecert_2.pk12[^[:space:]]\+#devicecert_2.pk12<hidden key>#g' \
                                       -e 's#staticXpkiCrt.pk12[^[:space:]]\+#staticXpkiCrt.pk12<hidden key>#g' \
                                       -e 's#configsethash:[^[:space:]]\+#configsethash:#g' \
                                       -e 's#configsettime:[^[:space:]]\+#configsettime:#g' \
                                       -e 's#AWSAccessKeyId=.*Signature=.*&##g' \
                                       `"

                result=` eval $CURL_CMD > $HTTP_CODE`
                TLSRet=$?
            fi

            if [ -f $ID ]; then
               rm -rf $ID
            fi
            if [ -f $HTTP_CODE ] ; then
                http_code=$(awk '{print $1}' $HTTP_CODE )
                if [ "x$http_code" == "x200" ] && [ "x$TLSRet" == "x0" ] ; then
                    break
                elif [ "x$http_code" == "x304" ] ; then
                    break
                elif [ "x$http_code" == "x404" ] ; then
                    $curl_log "HTTP response code received $http_code"
                    break
                else
                    case $TLSRet in
                    35|51|53|54|58|59|60|64|66|77|80|82|83|90|91)
                        $curl_log "Problem with certificate=$cert with curl ret=$TLSRet http_code=$http_code"
                        t2ValNotify "SYST_ERR_CLIENTCERT_Fail" "mtlsCurl, $cert, $TLSRet, $http_code"
                        continue
                        ;;
                    esac
                    $curl_log "curl connection failed with ret=$TLSRet http_code=$http_code"
                    break
                fi
            fi
        done
echo $TLSRet
}