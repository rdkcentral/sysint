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
# this script uses vmstat to print out following information
# vmInfoHeader: swpd,free,buff,cache,si,so
# vmInfoValues: <int>,<int>,<int>,<int>,<int>,<int>
if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi
vmstat > /tmp/.intermediate_calc_vm
echo "VM STATS SINCE BOOT"
values1=`sed '2q;d' /tmp/.intermediate_calc_vm| awk '{print $3","$4","$5","$6","$7","$8}'`
values2=`sed '3q;d' /tmp/.intermediate_calc_vm| awk '{print $3","$4","$5","$6","$7","$8}'`
echo vmInfoHeader: $values1
echo vmInfoValues: $values2
t2ValNotify "vmstats_split" "$values2"
