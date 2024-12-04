#!/bin/sh
#
# ============================================================================
# RDK MANAGEMENT, LLC CONFIDENTIAL AND PROPRIETARY
# ============================================================================
# This file (and its contents) are the intellectual property of RDK Management, LLC.
# It may not be used, copied, distributed or otherwise  disclosed in whole or in
# part without the express written permission of RDK Management, LLC.
# ============================================================================
# Copyright (c) 2020 RDK Management, LLC. All rights reserved.
# ============================================================================
#
ps -ef | grep $1 | grep -v grep| grep -v $0 | awk '{print $2}'
