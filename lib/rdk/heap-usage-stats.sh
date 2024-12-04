#!/bin/bash
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
echo "Core:"
echo -e "heap\t offset\t\t size\t\t kB\t used\t name"
heap=0
for heap_type in /sys/kernel/debug/ion/heaps/*; do
  name=$(basename $heap_type)
  memory_data=$(grep 'base=\|Usage\|pages :' ${heap_type})
  while IFS= read -r line
  do
    if [[ $line == *base=* ]]
    then
      offset=`echo $line | cut -d" " -f2 | cut -c6-`
      size=`echo $line | cut -d" " -f3 | cut -c6-`
      sizek=${size%%(*}
      sizek=$(expr ${sizek} / 1024)
      flags=`echo $line | cut -d" " -f4 | cut -c11-`
      used="N/A"
      ((heap=heap+1))
    elif [[ $line == *Usage* ]]
    then
      used=${line##*Usage :}
      used=${used//[[:space:]]}
      printf "$heap\t$offset\t$size\t$sizek\t$used\t$name\n"
    elif [[ $line == *\ \ Free\ pages* ]]
    then
      printf "$heap\t$offset\t$size\t$sizek\t$used\t$name\n"
    fi
  done <<< "$memory_data"
done
if [ -e "/sys/class/thermal/thermal_zone0/temp" ]; then
	temp=`cat /sys/class/thermal/thermal_zone0/temp`
	temp=$((10#${temp}/1000))
	echo "Temperature: $temp degrees Celsius"
fi
class_regulator=/sys/class/regulator
get_supply()
{
	for p in `ls $class_regulator`; do
	[[ `cat $class_regulator/$p/name` == $1 ]] && echo $class_regulator/$p
	done
}
if [ -e "$(get_supply cpudvs)/microvolts" ]; then
	volt=`cat $(get_supply cpudvs)/microvolts`
	volt=$((10#${volt}/1000))
	echo "Voltage: $volt mV"
fi
