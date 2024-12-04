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

usage()
{
  echo "USAGE:   startTunnel.sh {start|stop} {args}"
}

if [ $# -lt 1 ]; then
   usage
   exit 1
fi

oper=$1
shift

case $oper in 
           h)
             usage
             exit 1
             ;;
           start)
             if [ ! -f /usr/bin/GetConfigFile ];then
                 echo "Error: GetConfigFile Not Found"
                 exit 127
             fi
             GetConfigFile /tmp/nvgeajacl.ipe
             /usr/bin/ssh -i /tmp/nvgeajacl.ipe $*
             rm /tmp/nvgeajacl.ipe
             exit 1
             ;;
           stop)
             cat /var/tmp/rssh.pid |xargs kill -9
             rm /var/tmp/rssh.pid
             exit 1
             ;;
           *)
             usage
             exit 1
esac
