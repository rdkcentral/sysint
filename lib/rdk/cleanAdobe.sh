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



# This script cleans up the following when there is a change in STB image version
# or if the provisioned materials under /opt/drm have changed.
# 1) /opt/persistent/adobe/*
# 2) /opt/netflix/nrd/systemData_v1.secure

. /etc/include.properties
logMessage()
{
    message="$1"
    echo "$0 `date -u +%Y/%m/%d-%H:%M`]: $message" >> $LOG_PATH/cleanAdobe.log
}

# Returns 0 when md5 sum matched
checkMd5Sum()
{
    sum_path=$1
    if [ ! -e "${sum_path}" ] ; then
        logMessage "md5 sum file '${sum_path}' does not exist."
        return 1
    fi
    if [ ! -s "${sum_path}" ] ; then
        logMessage "md5 sum file '${sum_path}' is empty."
        return 1
    fi ;
    while read persisted_sum target_file ; do
        curr_sum=$(md5sum ${target_file} | awk '{print $1}')
        if [ "${persisted_sum}" != "${curr_sum}" ] ; then
            logMessage "md5 sum of '${target_file}' does not match."
            return 2
        fi
    done < ${sum_path}
    return 0
}
cleanup()
{
    logMessage "execution is starting"
    
    ADOBE_PATH=/opt/persistent/adobe
    
    # first check if image version has changed
    VERSION_FILE="/version.txt"
    IMAGE_FILE="/opt/oldImageName.txt"
    if [ -f $VERSION_FILE ]; then
        IMAGE_NAME=`grep -i imagename $VERSION_FILE |cut -d : -f2` 
        if [ -z $IMAGE_NAME ]; then
            logMessage "Image Name doesnot exist in  /version.txt file"
            return
        fi
    else
        logMessage "Version File doesnot exist"
        return
    fi
    
    doCleanup=0
    
    if [ ! -f $IMAGE_FILE ]; then
        logMessage "oldImageName File doesnot exist. Doing cleanup"
        doCleanup=1
    else
        logMessage "oldImageName File exist"
        OLD_IMAGE_NAME=`cat $IMAGE_FILE`
        if [ "$IMAGE_NAME" != "$OLD_IMAGE_NAME" ] ; then
            logMessage "Image changed. Doing cleanup"
            doCleanup=1
        else    
            logMessage "Image name matches"
        fi
    fi
    
    DRM_CERT_SUM_PATH=/opt/.drmcertsum
    DRM_CERT_PATH="/opt/drm/*.bin /opt/drm/*.cert /opt/drm/*.key"
    
    # If image version is same check if /opt/drm contents have changed
    if [ ${doCleanup} == 0 ] ; then
        logMessage "DRM_CERT_PATH='$DRM_CERT_PATH' "
        if ! checkMd5Sum "${DRM_CERT_SUM_PATH}"; then
            logMessage "/opt/drm contents changed. Doing cleanup"
            doCleanup=1
        fi
    fi
    
    if [ ${doCleanup} == 1 ] ; then
        # Can't just remove entire adobe dir, since it fails with "Device or resource busy"
        failed=0
        for entry in `ls -a ${ADOBE_PATH}` ; do
            if [ "${entry}" != "." ] && [ "${entry}" != ".." ] ; then
                rm -fr ${ADOBE_PATH}/${entry}
                if [ $? -ne 0 ] ; then
                    logMessage "Failed to remove ${ADOBE_PATH}/${entry}"
                    failed=1
                fi
            fi
        done
        
        # The FKPS /opt/drm/0311000003110002.key is used to wrap Netflix key data that is stored
        # encrypted at /opt/netflix/nrd/systemData_v1.secure. So any change in /opt/drm would
        # require cleanup of this file.
        rm -rf "/opt/netflix/nrd/systemData_v1.secure"
        if [ $? -ne 0 ] ; then
            logMessage "Failed to remove Netflix key data file /opt/netflix/nrd/systemData_v1.secure"
            failed=1
        else
            logMessage "Netflix key data file /opt/netflix/nrd/systemData_v1.secure deleted"
        fi
        
        if [ ${failed} == 0 ] ; then
            logMessage "Cleanup successful."
            echo $IMAGE_NAME > $IMAGE_FILE
            md5sum ${DRM_CERT_PATH} > ${DRM_CERT_SUM_PATH}
            if [ $? -ne 0 ] ; then
                logMessage "Failed to get new md5sum of '${DRM_CERT_PATH}'."
            fi
        fi
    else
        logMessage "Skipping cleanup."
    fi
    logMessage "execution is complete"
}
cleanup
