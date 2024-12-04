#!/bin/busybox sh
##########################################################################
# If not stated otherwise in this file or this component's LICENSE
# file the following copyright and licenses apply:
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
##########################################################################
temp_rdnssd_resolve_cache=/tmp/.resolv.dnsmasq.rdnssd.cache
rdnssd_resolve_file=/tmp/resolv.dnsmasq.rdnssd
temp_rdnssd_resolve_cache_sort=/tmp/.resolv.dnsmasq.rdnssd.cache_sort
rdnssd_resolve_file_sort=/tmp/resolv.dnsmasq.rdnssd_sort

if [ ! -f $rdnssd_resolve_file ]; then
    ##Nothing to do exit
    exit 0
fi

if [ -f "$temp_rdnssd_resolve_cache" ]; then
    #sort the cache file and newly updated dnsmasq.rdnssd files and then compare it to avoid the unnecessary dnsmasq restarts.
    sort $temp_rdnssd_resolve_cache -o $temp_rdnssd_resolve_cache_sort
    sort $rdnssd_resolve_file -o $rdnssd_resolve_file_sort
    if cmp -s "$temp_rdnssd_resolve_cache_sort" "$rdnssd_resolve_file_sort"; then
        #Nothing to do exit 
        exit 0
    fi
fi

#rdnssd resolve file is updated.
#update the cache file with current rdnssd resolve file
cp $rdnssd_resolve_file $temp_rdnssd_resolve_cache
#clear the sorted tmp files
rm -f $temp_rdnssd_resolve_cache_sort
rm -f $rdnssd_resolve_file_sort
#Trigger the dnsmerge
/bin/sh /lib/rdk/dnsmerge.sh
