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


snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
setSNMPEnv()
{
     #Set env for SNMP client queries..."
     export MIBS=ALL
     export MIBDIRS=/mnt/nfs/bin/target-snmp/share/snmp/mibs:/usr/share/snmp/mibs
     export PATH=$PATH:/mnt/nfs/bin/target-snmp/bin:
     export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/mnt/nfs/bin/target-snmp/lib:/mnt/nfs/usr/lib
}  

## get Model No of the box
getModel()
{
    model=`sh $RDK_PATH/getDeviceDetails.sh read model`
    echo $model
}  

getFirmwareVersion()
{
    setSNMPEnv
    ret=`snmpget -OQ -v 2c -c $1 $2 sysDescr.0 | cut -d "=" -f2 | cut -d ":" -f5 | cut -d " " -f2 | cut -d ";" -f1`
     if [[ $? -eq 0 ]] ; then
         echo $ret
     else
         echo ""
     fi
}

getECMMac()
{
    setSNMPEnv
    snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
    ret=`snmpwalk -OQ -v 2c -c "$snmpCommunityVal" 192.168.100.1 -m IF-MIB IF-MIB::ifPhysAddress.2 | cut -d "=" -f2`
     if [[ $? -eq 0 ]] ; then
         echo $ret
     else
         echo ""
     fi
}
