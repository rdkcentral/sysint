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

if [ -f /lib/rdk/getSecureDumpStatus.sh ]; then
     . /lib/rdk/getSecureDumpStatus.sh
fi

if [ ! -d $CORE_PATH ]; then 
    echo "Creating $CORE_PATH folder" 
    mkdir -p $CORE_PATH 
fi
echo "Found $CORE_PATH directory to process minidumps"

if [ ! -d $MINIDUMPS_PATH ]; then 
    echo "Creating $CORE_PATH folder" 
    mkdir -p $MINIDUMPS_PATH 
fi
echo "Found $CORE_PATH directory to process coredumps" 
