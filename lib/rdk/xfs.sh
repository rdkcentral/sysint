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


mount | grep sda2 | grep rtdev
if [ $? -ne 0 ]; then
  echo "Its not a realtime XFS partition..."
  opt=`ps | grep opt | cut -d ' ' -f2`
  killall -9 lighttpd
  kill -9 $opt
  umount /dev/sda1
  umount /dev/sda2
  echo "Creating realtime XFS filesystem"
  mkfs.xfs -f -b size=4096 -d agcount=4 -s size=4096 -l size=2m -r extsize=4m,rtdev=/dev/sda1 /dev/sda2
  sleep 10
  sync
  echo "realtime XFS created.. rebooting box now"
  sh /rebootNow.sh -s XFS -o "Rebooting the box after realtime XFS creation..."
else
  fsck.xfs /dev/sda1
  fsck.xfs /dev/sda2
fi
