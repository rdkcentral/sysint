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

##################################################################################
# Scope   : RDK Devices
# purpose : dnsmerge.sh is to Merge all DNS entries from various entities like
#              udhcpc, upnp, dibbler to a common resolv.dnsmasq file
# Usage   : Invoked by systemd service and scripts
##################################################################################

resolvFile=/etc/resolv.dnsmasq
udhcpc_resolvfile=/tmp/resolv.dnsmasq.udhcpc
upnp_resolvFile=/tmp/resolv.dnsmasq.upnp
composite_resolvFile=/tmp/bck_resolv.dnsmasq
dup_resolvFile=/tmp/backup.resolv.dnsmasq
LOCK_FILE="/var/lock/dnsmerge.lock"

#Waiting for the lock to release
exec 200>"$LOCK_FILE"
flock -n 200

:>$composite_resolvFile #empty contents of resolvFile

# Shuffle NameServers in resolv.dnsmasq for DNSMasq Strict-Ordering
# Adding this work-around fix intentionally, and the actual fix will be taken from dnsmasq side when available
shuffleNameservers () {

    # Checking if the backup resolv file and the current resolv file are the same
    if [ -f "$dup_resolvFile" ]; then
        cmp -s "$resolvFile" "$dup_resolvFile"
        if [ "$?" -eq 0 ]; then
            echo "Duplicate resolv file and current resolv file are identical. Shuffling is not required and Removing Lock"
            rm -f /var/lock/dnsmerge.lock
            exit 0
        fi
    fi

    # Read nameservers from resolv file into an array
    ips=()
    while read -r ip; do
        ips+=("$ip")
    done < "$resolvFile"

    # IPv4 and IPv6 Address Flags
    v6=1
    v4=1
    top=()
    bottom=()

    # Shuffles and gets alternative V4 and V6 addresses in first 2 lines and
    # the rest of the addresses goes below
    for ip in "${ips[@]}"; do
        if [[ "$ip" == nameserver*:* ]]; then
            if [[ "$v6" == 1 ]]; then
                top+=("$ip")
                v6=0
            else
                bottom+=("$ip")
            fi
        elif [[ "$ip" == nameserver*.* ]]; then
            if [[ "$v4" == 1 ]]; then
                top+=("$ip")
                v4=0
            else
                bottom+=("$ip")
            fi
        else
            search=("$ip")
        fi
    done

    # Shuffle the IPv6 and IPv4 addresses
    full=("${search[@]}" "${top[@]}" "${bottom[@]}")

    # Write the shuffled IPs back to the input file
    printf "%s\n" "${full[@]}" > "$resolvFile"

    # Print the contents of the input file
    echo "Nameservers shuffled in resolv file"
    cat "$resolvFile"

    # Backup the resolv file
    cp "$resolvFile" "$dup_resolvFile"
}

for resolver in `ls /tmp/resolv.dnsmasq.* | grep -v $composite_resolvFile`
do
    /usr/bin/timeout 5 /bin/sync -d $resolver
    if [ $resolver = $udhcpc_resolvfile ]  && [ -s $upnp_resolvFile ]; then
        continue
    fi
    if [ ! -s $composite_resolvFile ]; then
        cp $resolver $composite_resolvFile
    else
        awk 'NR==FNR{a[$0];next} !($0 in a)' $composite_resolvFile  $resolver >> $composite_resolvFile
    fi
done

if [ ! -s $composite_resolvFile ]; then
    cp $udhcpc_resolvfile $composite_resolvFile
fi

#Sorting both original and newly updated content to avoid unnecessary restart of dnsmasq.service
/usr/bin/timeout 5 /bin/sync -d $composite_resolvFile
/usr/bin/timeout 5 /bin/sync -d $resolvFile
awk 'NR==FNR{name[$1]++;next}$1 in name' $composite_resolvFile $resolveFile  >> $composite_resolvFile

if diff $composite_resolvFile $resolvFile >/dev/null ; then
    echo "No Change in DNS Servers"
else
    if [ -s $composite_resolvFile ];then
        cat $composite_resolvFile > $resolvFile
        echo "DNS Servers Updated"
        ipv4=0
        ipv6=0
        DNS_ADDR=""
        while read -r line; do
            ADDR=`echo $line | cut -d " " -f2`
            if [ "$line" != "${line#*[0-9].[0-9]}" ]; then
                ipv4=$((ipv4 +1))
                DNS_ADDR="$DNS_ADDR \n$ADDR;"
            elif [ "$line" != "${line#*:[0-9a-fA-F]}" ]; then
                ipv6=$((ipv6 +1))
                DNS_ADDR="$DNS_ADDR \n$ADDR;"
            else
                echo "Unrecognized IP format '$line'"
            fi
        done<$resolvFile

        # DNSMasq Strict Order RFC Value
        isDNSMasqStrictOrderEnable=$(/usr/bin/tr181Set -d Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.DNSStrictOrder.Enable 2>&1 > /dev/null)

        # Invoke Shufffling Mechanism if Strict-Ordering RFC for DNSMasq is enabled
        if [ $ipv6 -ge 1 -a $ipv4 -ge 1 -a "$isDNSMasqStrictOrderEnable" = "true" ]; then
            echo "RFC_Strict_Order_DNSMasq: $isDNSMasqStrictOrderEnable"
            echo "Shuffling Nameservers for DNSMasq Strict Ordering"
            shuffleNameservers
            echo "Shuffling Completed"
        fi

        if [ "x$ipv4" = "x0" -a -f /lib/rdk/update_namedoptions.sh ]; then
             /bin/sh /lib/rdk/update_namedoptions.sh $DNS_ADDR
        else
            # This is to handle switching between ipv4 and ipv6
            systemctl stop named.service
            systemctl restart dnsmasq.service
        fi
    fi
fi

#Release the lock before leaving
