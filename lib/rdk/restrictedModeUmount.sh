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

umount -f /opt/restricted/bin
umount -f /opt/restricted/sysint
umount -l /opt/restricted/tmp
umount -f /opt/restricted/opt/logs
sleep 1
umount -f /opt/restricted/opt/.adobe
umount -f /opt/restricted/opt/.macromedia
umount -f /opt/restricted/opt/xupnp/
umount -f /opt/restricted/opt/QT
sleep 1
umount -f /opt/restricted$CORE_PATH
umount -f /opt/restricted$CORE_BACK_PATH
umount -f /opt/restricted$MINIDUMPS_PATH
umount -f /opt/restricted/opt
umount -f /opt/restricted/lib/rdk
umount -f /opt/restricted/lib
sleep 1
umount -f /opt/restricted/mnt/nfs/bin
umount -f /opt/restricted/mnt/nfs/env
umount -l /opt/restricted/proc
umount -l /opt/restricted/sys
umount -l /opt/restricted/dev/shm
umount -l /opt/restricted/dev
sleep 1
umount -f /opt/restricted/sbin                         
umount -f /opt/restricted/var/logs                     
umount -f /opt/restricted/usr/local/lib                
umount -f /opt/restricted/usr/local/Qt                     
umount -f /opt/restricted/usr/local/bin   
sleep 1                       
umount -f /opt/restricted/usr/lib                          
umount -f /opt/restricted/usr/bin
umount -f /opt/restricted/usr
umount -f /opt/restricted/.ssh
umount -f /opt/restricted/etc/.ssh
umount -f /opt/restricted/etc                              
sleep 1
