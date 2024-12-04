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


CopyCertFile() {
   srcDir=$1;
   destDir=$2;
   File=$3;
   if [ -f $srcDir/$File ]; then
       if [ -f $destDir/$File ]; then
           cmp -s $destDir/$File $srcDir/$File
           if [ $? -ne 0 ]; then
               cp -f $srcDir/$File $destDir/
               echo "WARNING: $destDir/$File is different from $srcDir/$File, but now made same";
           fi
       else
           cp -f $srcDir/$File $destDir/
           echo "WARNING: $destDir/$File is missing, but copied now";
       fi
   else
       echo "ERROR: $srcDir/$File file is missing in image.";
   fi
}


# install playready certificates
mkdir -p /opt/drm/playready
CopyCertFile /usr/share/playready /opt/drm/playready bgroupcert.dat
CopyCertFile /usr/share/playready /opt/drm/playready devcerttemplate.dat
CopyCertFile /usr/share/playready /opt/drm/playready zgpriv.crypt
CopyCertFile /usr/share/playready /opt/drm/playready zgpriv.dat



