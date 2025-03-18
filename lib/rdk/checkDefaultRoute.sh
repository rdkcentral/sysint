#!/bin/sh
##########################################################################
# If not stated otherwise in this file or this component's Licenses.txt
# file the following copyright and licenses apply:
#
# Copyright 2018 RDK Management
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
##########################################################################

# Message Format: family interface destinationip gatewayip preferred_src metric add/delete
. /etc/common.properties
FILE=/tmp/.GatewayIP_dfltroute

#Condition to check for arguments are 7 and not 0.
if [ $# -eq 0 ] || [ $# -ne 7 ];then
    echo "No. of arguments supplied are not satisfied, Exiting..!!!"
    echo "Arguments accepted are [ family | interface | destinationip | gatewayip | preferred_src | metric | add/delete]"
    exit;
fi

echo "Input Arguments : $* "
opern="$7"
mode="$1"
gtwip="$4"

if [ "$opern" = "add" ]; then
    #Check and create the route flag
    route -n
    ip -6 route
    echo "Route is available"
    if [ ! -f /tmp/route_available ];then
        echo "Creating the Route Flag /tmp/route_available"
        touch /tmp/route_available
        if [ "x${INIT_SYSTEM}" = "xs6" ] ; then
            s6-ftrig-notify /tmp/.pathfifo path-route-available
        fi
    fi

    #Add Default route IP to the /tmp/.GatewayIP_dfltroute file
    if ! grep -q "$gtwip" $FILE; then
        if [ "$mode" = "2" ]; then
            echo "IPV4 $gtwip" >> $FILE
        elif [ "$mode" = "10" ]; then
            echo "IPV6 $gtwip" >> $FILE
        else
            echo "Invalid Mode"
            exit;
        fi
    fi

elif [ "$opern" = "delete" ]; then
    #Remove flag and IP for delete operation
    echo "Deleting Route Flag"
    sed -i "/$gtwip/d" $FILE
    [ -s $FILE ] || rm -rf /tmp/route_available
else
    echo "Received operation:$opern is Invalid..!!"
fi
