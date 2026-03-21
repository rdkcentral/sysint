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
. /usr/bin/stunnelCertUtil.sh
. /lib/rdk/utils.sh

if [ -f /lib/rdk/t2Shared_api.sh ]; then
        source /lib/rdk/t2Shared_api.sh
fi

export TERM=xterm
export HOME=/home/root

# log format
DT_TIME=$(/bin/timestamp)
LOG_FILE="$LOG_PATH/stunnel.log"

echo_t()
{
    echo "$DT_TIME $@" >> $LOG_FILE
}

usage()
{
  echo_t "STUNNEL USAGE:  startSTunnel.sh <localport> <jumpfqdn> <jumpserverip> <jumpserverport> <reverseSSHArgs>"
}

if [ $# -lt 5 ]; then
   usage
   exit 1
fi

if [ $DEVICE_TYPE == "broadband" ]; then
    DEVICE_CERT_PATH=/nvram/certs
elif [ $DEVICE_TYPE == "mediaclient" -o $DEVICE_TYPE == "hybrid" ]; then
    DEVICE_CERT_PATH=/opt/certs
else
    echo_t "STUNNEL: $DEVICE_CERT_PATH, not expected"
    DEVICE_CERT_PATH=/tmp/certs
fi

#collect the arguments
#    1) CPE's available port starting from 3000
#    2) FQDN of jump server
#    3) Jump server's IP
#    4) Port number of stunnel's server instance at jump server
LOCAL_PORT=$1
JUMP_FQDN=$2
JUMP_SERVER=$3
JUMP_PORT=$4
REVERSESSHARGS=$5
SHORTSARGS=$6
NONSHORTSARGS=$7

echo_t "SHORTSARGS :$SHORTSARGS"
echo_t "NONSHORTSARGS :$NONSHORTSARGS"

t2ValNotify "SSH_INFO_SOURCE_IP" "$JUMP_SERVER"

isShortsenabled=`tr181 Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.SHORTS.Enable 2>&1 > /dev/null`
echo_t "isShortsenabled = $isShortsenabled "
if [ "$isShortsenabled" == "false" ];then
    /bin/sh /lib/rdk/startTunnel.sh start ${REVERSESSHARGS}${NONSHORTSARGS}
    exit 0
fi

STUNNEL_PID_FILE=/tmp/stunnel_$LOCAL_PORT.pid
REVSSH_PID_FILE=/var/tmp/rssh.pid
STUNNEL_CONF_FILE=/tmp/stunnel_$LOCAL_PORT.conf

echo  "pid = $STUNNEL_PID_FILE"           > $STUNNEL_CONF_FILE
echo  "output=$LOG_FILE"                 >> $STUNNEL_CONF_FILE
echo  "debug = 7"                        >> $STUNNEL_CONF_FILE
echo  "[ssh]"                            >> $STUNNEL_CONF_FILE
echo  "client = yes"                     >> $STUNNEL_CONF_FILE

# Use localhost to listen on both IPv4 and IPv6
echo "accept = localhost:$LOCAL_PORT"    >> $STUNNEL_CONF_FILE
echo "connect = $JUMP_SERVER:$JUMP_PORT" >> $STUNNEL_CONF_FILE

extract_stunnel_client_cert

if [ ! -f $CERT_PATH -o ! -f $CA_FILE ]; then
    echo_t "STUNNEL: Required cert/CA file not found. Exiting..."
    t2CountNotify "SHORTS_STUNNEL_CERT_FAILURE"
    exit 1
fi

# Specify cert, CA file and verification method
DEV_SAN=$DEFAULT_DEV_SAN
PROD_SAN=$DEFAULT_PROD_SAN
echo "cert        = $CERT_PATH"          >> $STUNNEL_CONF_FILE
echo "CAfile      = $CA_FILE"            >> $STUNNEL_CONF_FILE
echo "verifyChain = yes"                 >> $STUNNEL_CONF_FILE
echo "checkHost   = $JUMP_FQDN"          >> $STUNNEL_CONF_FILE

DEVICETYPE=`tr181 -g Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Identity.DeviceType 2>&1`
echo_t "STUNNEL: Device type is $DEVICETYPE"
if [ ! -z "$DEVICETYPE" ]; then
    if [ "$DEVICETYPE" == "TEST" ] || [ "$DEVICETYPE" == "test" ]; then
        echo_t "STUNNEL: Device type is TEST"
        t2CountNotify "SHORTS_DEVICE_TYPE_TEST"
        echo "checkHost   = $DEV_SAN"          >> $STUNNEL_CONF_FILE
    else
        echo_t "STUNNEL: Device type is PROD"
        t2CountNotify "SHORTS_DEVICE_TYPE_PROD"
        echo "checkHost   = $PROD_SAN"         >> $STUNNEL_CONF_FILE
    fi
else
    echo_t "STUNNEL: Device type is Unknown"
    t2CountNotify "SHORTS_DEVICE_TYPE_UNKNOWN"
fi

#Function to find available fd at this point in time
get_next_fd() {
    local fd=3  # Start checking from FD 3 (since 0, 1, 2 are standard in/out/err)
    local max_fd=20  # Maximum FD to check

    # Try to redirect to /dev/null and check if the FD is free
    while [ $fd -le $max_fd ]; do
        if ! { true >&$fd; } 2>/dev/null; then
            echo "$fd" # Output the available FD (goes to standard output)
            return 0 # Set exit status to success
        fi
        fd=$((fd + 1))
    done

    # Log failure if no free FD is found
    echo "Error: No available file descriptor found up to FD $max_fd" >&2
    return 1 # Set exit status to failure
}

# Get the next available file descriptor and export if it's valid
FD_NUMBER=$(get_next_fd)
if [ $? -eq 0 ]; then
    export FD_NUMBER

    # Create a named pipe
    PIPE=$(mktemp -u)
    if ! mkfifo "$PIPE" 2>/dev/null; then
        echo_t "STUNNEL: ERROR - Failed to create named pipe"
    fi

    # Open the pipe using the available FD, with error handling
    if ! eval "exec $FD_NUMBER<>$PIPE" 2>/dev/null; then
        echo_t "STUNNEL: ERROR - Failed to open pipe with file descriptor"
    fi

    # Removing the pipe after opening
    rm "$PIPE"

    # Writing passcode to open file descriptor
    echo "$(eval "$PASSCODE")" >&$FD_NUMBER &
else
    echo "Error: No available file descriptor to use." >&2
fi

# NetworkManager compatibility
if [ -f /usr/sbin/NetworkManager ]; then
    if [ -f /tmp/estb_ipv4 ]; then
        #IpAddr=$(/sbin/ip -4 route get 1 | awk -F 'src ' '{print $2}' | awk '{print $1;}')
        IPTABLE_CMD="/usr/sbin/iptables -w "

    elif [ -f /tmp/estb_ipv6 ]; then
        #IpAddr=$(/sbin/ip -6 route get 1 | awk -F 'src ' '{print $2}' | awk '{print $1;}')
        IPTABLE_CMD="/usr/sbin/ip6tables -w "
    fi

    #$IPTABLE_CMD -I INPUT -s $IpAddr -p tcp --dport 22 -j ACCEPT
    $IPTABLE_CMD -I INPUT -p tcp -m tcp --dport 22 -m mac --mac-source `getEstbMacAddress` -j ACCEPT
    #$IPTABLE_CMD -I OUTPUT -o lo -p tcp -s $IpAddr -d $IpAddr -j ACCEPT
    $IPTABLE_CMD -I INPUT -i lo -j ACCEPT #accept traffic for localhost (whitebox)
fi

/usr/bin/stunnel $STUNNEL_CONF_FILE
if [ $? -ne 0 ]; then
    echo_t "STUNNEL: ERROR - Failed to start stunnel process."
    exit 1
fi

# cleanup sensitive files early
rm -f $STUNNEL_CONF_FILE
rm -f $D_FILE


REVSSHPID1=$(cat $REVSSH_PID_FILE)
STUNNELPID=$(cat $STUNNEL_PID_FILE)

count=0
while [ -z "$STUNNELPID" ]; do
    if [ $count -lt 2 ]; then
        sleep 1
        echo_t "STUNNEL: stunnel PID file is not available, Retrying..."
        STUNNELPID=$(cat $STUNNEL_PID_FILE 2>/dev/null)
        count=$((count + 1))
    else
        rm -f $STUNNEL_PID_FILE
        rm -f $CA_FILE
        if [ "x$CRED_INDEX" == "x0" ]; then
            touch /tmp/.$SE_DEVICE_CERT
        fi
        echo_t "STUNNEL: stunnel-client failed to establish. Exiting..."
        t2CountNotify "SHORTS_STUNNEL_CLIENT_FAILURE"
        exit
    fi
done

#Starting startTunnel
/bin/sh /lib/rdk/startTunnel.sh start ${REVERSESSHARGS}${SHORTSARGS}

REVSSHPID2=$(cat $REVSSH_PID_FILE)

#Terminate stunnel if revssh fails.
if [ -z "$REVSSHPID2" ] || [ "$REVSSHPID1" == "$REVSSHPID2" ]; then
    kill -9 $STUNNELPID
    rm -f $STUNNEL_PID_FILE
    if [ "x$CRED_INDEX" == "x0" ]; then
        touch /tmp/.$SE_DEVICE_CERT
    fi
    echo_t "STUNNEL: Reverse SSH failed to connect. Exiting..."
    t2CountNotify "SHORTS_SSH_CLIENT_FAILURE"
    exit
fi

echo_t "STUNNEL: Reverse SSH pid = $REVSSHPID2, Stunnel pid = $STUNNELPID"
t2CountNotify "SHORTS_CONN_SUCCESS"
#watch for termination of ssh-client to terminate stunnel
while test -d "/proc/$REVSSHPID2"; do
     sleep 5
done

# NetworkManager compatibility
if [ -f /usr/sbin/NetworkManager ]; then
    $IPTABLE_CMD -D INPUT -p tcp -m tcp --dport 22 -m mac --mac-source `getEstbMacAddress` -j ACCEPT
    $IPTABLE_CMD -D INPUT -i lo -j ACCEPT
fi

echo_t "STUNNEL: Reverse SSH session ended. Exiting..."
kill -9 $STUNNELPID
rm -f $STUNNEL_PID_FILE

