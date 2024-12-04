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

if [ "$WHITEBOX_ENABLED" == "true" ]; then
    . /etc/wbdevice.conf
else
    wbpath=/opt/www/whitebox/
fi

. /etc/authService.conf

# clear wbdevice.dat and other data cleared in Rset
rm $aspath/deviceid.dat $wbpath/wbdevice.dat /opt/logger.conf /opt/hosts /opt/receiver.conf /opt/proxy.conf /opt/mpeenv.ini /tmp/mnt/diska3/persistent/hostData1

# execute all scripts invoked during a warehouse reset
cd /HrvInitScripts
sh clear_cached_unbound_ocap_apps.sh
sh clear_registered_libraries.sh
sh clear_persistent_dvb_storage.sh
sh clear_security_element_values_passed.sh
sh clear_persistent_generic_feature_params.sh
sh clear_xre_contents.sh
sh clear_persistent_host_memory.sh

sh /rebootNow.sh -s WarehouseReset -o "Rebooting the box after Warehouse Reset..."
