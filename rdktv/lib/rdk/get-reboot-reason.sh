#!/bin/sh
##
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:
#
# Copyright 2020 RDK Management
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:##www.apache.org#licenses#LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##

# Define logfiles and flags
KERNEL_RESET_REASON_VARIABLE=/sys/devices/platform/aml_pm/reset_reason

  RST_Reason=`cat $KERNEL_RESET_REASON_VARIABLE`
  case $RST_Reason in
  0)
  echo PreviousRebootReason:  power_on_reset!
  ;;
  1)
  echo PreviousRebootReason:  software_master_reset!
  ;;
  2)
  echo PreviousRebootReason:  factory_reset!
  ;;
  3)
  echo PreviousRebootReason:  update!
  ;;
  4)
  echo PreviousRebootReason:  fastboot!
  ;;
  5)
  echo PreviousRebootReason:  suspend_off!
  ;;
  6)
  echo PreviousRebootReason:  hibernate!
  ;;
  7)
  echo PreviousRebootReason:  bootloader!
  ;;
  8)
  echo PreviousRebootReason:  shutdown_reboot!
  ;;
  9)
  echo PreviousRebootReason:  rpmbp!
  ;;
  10)
  echo PreviousRebootReason:  quiescent reboot!
  ;;
  11)
  echo PreviousRebootReason:  crash_dumpg!
  ;;
  12)
  echo PreviousRebootReason:  kernel_panic!
  ;;
  13)
  echo PreviousRebootReason:  watchdog_timer_reset!
  ;;
  14)
  echo PreviousRebootReason:  quiescent recovery!
  ;;
  *)
  echo PreviousRebootReason:  unknown!
  ;;
  esac

