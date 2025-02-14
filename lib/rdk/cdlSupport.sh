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
. /etc/device.properties



LOG_FILE="/opt/logs/swupdate.log"
#Use log framework to print timestamp and source script name
swupdateLog()
{
    echo "`/bin/timestamp` : $0: $*" >> $LOG_FILE
}

getPkgMetadata()
{
    JSONQUERY="/usr/bin/jsonquery"
    data=$($JSONQUERY -f $1 -p $2)
    if [ $? -eq 0 ]; then
        echo "$data"
    else
        log "getPkgMetadata() failed to fetch $2"
        echo ""
    fi
}




### getInstalledBundleList
### Returns the list of bundles installed and its corresponding version
###
### Arguments:
### No arguments
###
### Return value:
### Type - string
### Format - "ABun:AVer,BBun:Bver"
getInstalledBundleList()
{
    BUNDLE_METADATA_NVM_PATH="/media/apps/etc/certs"
    BUNDLE_METADATA_RFS_PATH="/etc/certs"

    PKG_METADATA_NAME="name"
    PKG_METADATA_VER="version"


    metadata_nvm_ls=""
    metadata_rfs_ls=""

    if [ -d "$BUNDLE_METADATA_NVM_PATH" ]; then
        swupdateLog "Fetching bundle metadata from $BUNDLE_METADATA_NVM_PATH"
        metadata_nvm_ls="$(find $BUNDLE_METADATA_NVM_PATH -name "*_package.json" -type f | tr '\n' ' ' | xargs)"
    else
        swupdateLog "$BUNDLE_METADATA_NVM_PATH does not exist"
    fi

    if [ -d "$BUNDLE_METADATA_RFS_PATH" ]; then
        swupdateLog "Fetching bundle metadata from $BUNDLE_METADATA_RFS_PATH"
        metadata_rfs_ls="$(find $BUNDLE_METADATA_RFS_PATH -name "*_package.json" -type f | tr '\n' ' ' | xargs)"
    else
        swupdateLog "$BUNDLE_METADATA_RFS_PATH does not exist"
    fi

    if [ -z "$metadata_rfs_ls" -a -z "$metadata_nvm_ls" ]; then
        swupdateLog "No metadata found in CPE"
        metadata_ls=""
    elif [ -z "$metadata_rfs_ls" ]; then
        swupdateLog "Metadata found only in $BUNDLE_METADATA_NVM_PATH"
        metadata_ls="$metadata_nvm_ls"
    elif [ -z "$metadata_nvm_ls" ]; then
        swupdateLog "Metadata found only in $BUNDLE_METADATA_RFS_PATH"
        metadata_ls="$metadata_rfs_ls"
    else
        swupdateLog "Metadata found in both $BUNDLE_METADATA_NVM_PATH & $BUNDLE_METADATA_RFS_PATH"
        swupdateLog "Preparing final matadata list"
        # Metadata present in sdcard takes precendence over rootfs. Hence add rootfs metadata to final list
        # only when it is missing in sdcard
        metadata_ls="$metadata_nvm_ls"
        for metadata in $metadata_rfs_ls; do
            echo "$metadata_nvm_ls" | grep -q "$(basename $metadata)"
            if [ $? -eq 0 ]; then
                swupdateLog "$(basename $metadata) already present in /media/apps"
            else
                swupdateLog "$(basename $metadata) not present in /media/apps. Adding it to list"
                metadata_ls="$metadata_ls $metadata"
            fi
        done
    fi

    list=""
    if [ -n "$metadata_ls" ]; then
        swupdateLog "List of bundle metadata found in CPE: $metadata_ls"
        for file in $metadata_ls; do
            bundle_name=$(getPkgMetadata $file $PKG_METADATA_NAME)
            bundle_version=$(getPkgMetadata $file $PKG_METADATA_VER)
            if [ -n "$bundle_name" -o -n "$bundle_version" ]; then
                list="$list $bundle_name:$bundle_version"
            else
                swupdateLog "Missing package name or version in $file"
            fi
        done
    fi

    if [ -n "$list" ]; then
        # Remove leading and trailing spaces if any
        bundle_list=$(echo $list | xargs | tr ' ' ',')
        swupdateLog "Installed bundle list: $bundle_list"
    else
        swupdateLog "Installed bundle list empty"
        bundle_list=""
    fi

    echo -n "$bundle_list"
}


### getInstalledRdmManifestVersion
### Returns the rdm manifest version which is currently running in the box
###
getInstalledRdmManifestVersion()
{
    DEFAULT_RDM_MANIFEST="/etc/rdm/rdm-manifest.json"
    DEFAULT_MANIFEST_VERSION=$(grep "manifest_version" ${DEFAULT_RDM_MANIFEST} | awk '{print $2}' | tr -d '"')
    PERSISTENT_MANIFEST_PATH="/media/apps/rdm/manifests"
    installedMfstVersion=$DEFAULT_MANIFEST_VERSION

    if [ -d "$PERSISTENT_MANIFEST_PATH" ]; then
        swupdateLog "Fetching rdm manifests from $PERSISTENT_MANIFEST_PATH"
        persistent_manifest_list=$(find $PERSISTENT_MANIFEST_PATH -name "*.json" -type f | tr '\n' ' ' | xargs)
    else
        swupdateLog "$PERSISTENT_MANIFEST_PATH does not exist"
    fi

    if [ -n "$persistent_manifest_list" ]; then
        swupdateLog "List of rdm manifests found in CPE: $persistent_manifest_list"

        rfs_MfstBranch="${DEFAULT_MANIFEST_VERSION%-v*}"
        rfs_MfstVersion="${DEFAULT_MANIFEST_VERSION#*-v}"

        mfst_version=""
        for manifests in $persistent_manifest_list; do
            echo "$manifests" | grep -q "$rfs_MfstBranch"
            if [ $? -eq 0 ]; then
                pruned_mfst="${manifests%.*}"  # Remove extension from manifest
                matchedMfst_version="${pruned_mfst#*-v}"
                mfst_version="$matchedMfst_version $mfst_version"
            fi
        done

        if [ -n "$mfst_version" ]; then
            versionlist=$(echo "$mfst_version" | xargs)
            latestVersion=$(getLatestVersion $versionlist)
        else
            swupdateLog "No manifests matched with the firmware currently running in the box"
        fi

        if [ -n "$latestVersion" ]; then
            installedMfstVersion="$rfs_MfstBranch-v$latestVersion"
        fi
    fi

    swupdateLog "Installed RDM Manifest Version in CPE: $installedMfstVersion"

    echo -n $installedMfstVersion
}


### getModel use to get model number. This is use to support rdkvfwupgrader
### Returns the model number
###
getModel()
{
   model=""
   modelFile="/opt/persistent/.model"
   if [ "$DEVICE_TYPE" != "mediaclient" ]; then
      snmpCommunityVal=`head -n 1 /tmp/snmpd.conf | awk '{print $4}'`
      model=`snmpget -Os -v 2c -c "$snmpCommunityVal" 192.168.100.1 sysDescr.0 | cut -d ":" -f7 | cut -d " " -f2 | sed 's/[>"]//g'`
      model=`echo $model | sed  "s/ //g"`
      [ $? -ne 0 ] && model=""
      [ "$logEnabled" == "true" ] && echo "getDeviceDetails:`uptime | cut -f1 -d ','`, Got model : $model"
      [[ "$model" != "$MODEL_NUM"* ]] && model=""
      [ "$model" == "$MODEL_NUM" ] && model=""

      if [ "$model" != "" ]; then
          if [ -f $modelFile ] && [ "$model" != "`cat $modelFile`" ] || [ ! -f $modelFile ]; then
              echo "$model" > $modelFile
          fi
      elif [ -f $modelFile ]; then
           model=`cat $modelFile`
      fi
      swupdateLog "cdlSupport.sh : Device type is: $DEVICE_TYPE and modelnum: $model"
      ## Below logic if after all above operation model is empty use device.property model num
      if [ "$model" == "" ]; then
          swupdateLog "cdlSupport.sh : Unable to get model number using snmpget. So use device.property:$MODEL_NUM"
          echo -n $MODEL_NUM
      else
	  echo -n $model
      fi
   else
      swupdateLog "cdlSupport.sh : Device type is: $DEVICE_TYPE and modelnum: $MODEL_NUM"
      echo -n $MODEL_NUM
   fi
}

# main app here
if [ "x$1" = "xgetInstalledRdmManifestVersion" ]; then
    getInstalledRdmManifestVersion
elif [ "x$1" = "xgetInstalledBundleList" ]; then
    getInstalledBundleList
elif [ "x$1" = "xgetModel" ]; then
    getModel
else
    echo "ERROR: unknown $1"
fi


