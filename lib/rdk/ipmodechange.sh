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
#Condition to check for arguments are 7 and not 0.
if [ $# -eq 0 ] || [ $# -ne 7 ];then
    echo "No. of arguments supplied are not satisfied, Exiting..!!!"
    echo "Arguments accepted are [ family | interface | destinationip | gatewayip | preferred_src | metric | add/delete]"
    exit;
fi

(/bin/busybox kill -STOP $$; /bin/busybox kill -CONT $$)
echo "Input Arguments : $* "
LOGFILE="/opt/logs/netsrvmgr.log"
opern="$7"
mode="$1"
gtwip="$4"

lmode="none"
# Mode = 2 for ipv4, mode = 10 for ipv6
if [ "x$mode" = "x2" ]; then
	lmode="ipv4"
fi
if [ "x$mode" = "x10" ]; then
	lmode="ipv6"
fi
if [ "$opern" = "add" ]; then
    #Check and create the route flag
    echo "`/bin/timestamp` Adding Route Flag" >> /opt/logs/netsrvmgr.log
    if [ "x$lmode" = "xipv4" ];
    then
	   touch /tmp/ipv4_route
	   if [ ! -f /tmp/ipv6_mode ] && [ ! -f /tmp/ipv4_mode ];
	   then
               if [ -f /tmp/ipv4_global ]; then
		   echo "`/bin/timestamp` Publishing ipmode change to ipv4" >> $LOGFILE
		   /usr/bin/IARM_event_sender IpmodeEvent 1 ipv4
		   touch /tmp/ipv4_mode
               fi
	   fi
   elif [ "x$lmode" = "xipv6" ]; then
	   touch /tmp/ipv6_route
           if [ -f /tmp/ipv6_global ]; then
               echo "`/bin/timestamp` Publishing ipmode change to ipv6" >> $LOGFILE
               /usr/bin/IARM_event_sender IpmodeEvent 1 ipv6
               touch /tmp/ipv6_mode
           fi
   fi
elif [ "$opern" = "delete" ]; then
    #Remove flag and IP for delete operation
    echo "`/bin/timestamp` Deleting Route Flag" >> $LOGFILE
    if [ "x$lmode" = "xipv6" ];
    then
	   rm -f  /tmp/ipv6_route
           if [ ! -f /tmp/ipv6_global ]; then
               rm -f  /tmp/ipv6_mode
               if [ -f /tmp/ipv4_route ]; then
		   echo "`/bin/timestamp` Publishing ipmode change to ipv4" >> $LOGFILE
		   /usr/bin/IARM_event_sender IpmodeEvent 1 ipv4
		   touch /tmp/ipv4_mode
               fi
	   fi
   elif [ "x$lmode" = "xipv4" ]; then
           if [ ! -f /tmp/ipv4_global ]; then
               rm -f /tmp/ipv4_mode
           fi
	   rm -f  /tmp/ipv4_route
   fi
else
    echo "Received operation:$opern is Invalid..!!"
fi
