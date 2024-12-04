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

. /etc/include.properties

# Stack initialization for the box depending on the build type
hardwareInit()
{
      platform_config_app set_int platform.software.drivers.smd.sven_log_level_override 1
      # Commented out for XONE-7265 (mdvr performance issue)
      #csven hot enable all 
     
      # Back up the database
      if [ ! -f $PERSISTENT_PATH/PersistStorage.db ] ; then
          cp /etc/PersistStorage.db $PERSISTENT_PATH/
      fi

      #Copying the contents of dmesg
      $RDK_PATH/kernel_printk.sh &
}

hardwareResetCheck()
{
   if [ -f $PERSISTENT_PATH/.hrv_init.log ] ; then
        rm -rf $PERSISTENT_PATH/.hrv_init.log
        /hrvinit 30 1
   fi
 
   if [ -f $PERSISTENT_PATH/.hrv_cinit.log ] ; then
        rm -rf $PERSISTENT_PATH/.hrv_cinit.log
        /hrvcoldinit3.31 120 1
   fi
 
   /Reset > $TEMP_LOG_PATH/Reset.txt &
}

hdcp_Init()
{
  #XONE-1176
  if [ ! -f $PERSISTENT_PATH/.hdcp_srmerase_done ] ; then
      /usr/dtsbin/hdcp srmerase  < /yes.txt
      touch $PERSISTENT_PATH/.hdcp_srmerase_done
  fi
}
