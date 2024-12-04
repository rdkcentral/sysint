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

# Get the values of APP_UID and APP_GID environment variables
netflix_app_uid="${NETFLIX_APP_UID}"
netflix_app_gid="${NETFLIX_APP_GID}"

# Check if the variables are set
if [ -n "$netflix_app_uid" ] && [ -n "$netflix_app_gid" ]; then
    echo "NETFLIX_APP_UID: $netflix_app_uid"
    echo "NETFLIX_APP_GID: $netflix_app_gid"

    # Specify the target directory
    target_directory="/opt/drm/playready/"

    # Check if the target directory exists
    if [ -d "$target_directory" ]; then
        # Change ownership and group
        chown -R "$netflix_app_uid:$netflix_app_gid" "$target_directory"
        echo "Ownership and group changed successfully for $target_directory."
    else
        echo "Error: The specified directory does not exist."
    fi
else
    echo "Error: APP_UID or APP_GID environment variables not set."
fi

