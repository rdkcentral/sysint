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
if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi
iostat -c 1 2 > /tmp/.intermediate_calc
sed -i '/^$/d' /tmp/.intermediate_calc
echo "INSTANTANEOUS CPU INFORMATIONS"
values1=`sed '4q;d' /tmp/.intermediate_calc| tr -s " " | cut -c10-| tr ' ' ','`
values2=`sed '5q;d' /tmp/.intermediate_calc| tr -s " " | cut -c2-| tr ' ' ','`
echo cpuInfoHeader: $values1
echo cpuInfoValues: $values2
t2ValNotify "cpuinfo_split" "$values2"
free | awk '/Mem/{printf("USED_MEM:%d\nFREE_MEM:%d\n"),$3,$4}'
mem=`free | awk '/Mem/{printf $4}'`
t2ValNotify "FREE_MEM_split" "$mem"
