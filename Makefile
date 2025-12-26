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


WRKDIR		=	.
STAGING_DIR	=	staging_dir

SYS_CONF_DIR	=	/etc
SYS_USR_DIR     =       /usr
BASE_LIB_DIR	=	/lib
BASE_BIN_DIR    =       /bin

IPK_DIR		=	ipk
IPK_NAME	=	sysint.ipk

install:
	install -d $(STAGING_DIR)$(BASE_LIB_DIR)/rdk
	install -m 0755 $(WRKDIR)/lib/rdk/* $(STAGING_DIR)$(BASE_LIB_DIR)/rdk

	install -d $(STAGING_DIR)$(BASE_LIB_DIR)/systemd/system
	install -m 0755 $(WRKDIR)/systemd_units/*.service $(STAGING_DIR)$(BASE_LIB_DIR)/systemd/system
	install -m 0755 $(WRKDIR)/systemd_units/*.timer $(STAGING_DIR)$(BASE_LIB_DIR)/systemd/system

	install -d $(STAGING_DIR)$(SYS_CONF_DIR)
	install -m 0644 $(WRKDIR)/etc/*.properties $(STAGING_DIR)$(SYS_CONF_DIR)
	install -m 0644 $(WRKDIR)/etc/*.conf $(STAGING_DIR)$(SYS_CONF_DIR)

        install -d $(STAGING_DIR)$(SYS_CONF_DIR)/NetworkManager/dispatcher.d/pre-up.d
	install -m 0755 $(WRKDIR)/lib/rdk/NM_preUp.sh $(STAGING_DIR)$(SYS_CONF_DIR)/NetworkManager/dispatcher.d/pre-up.d/NM_preUp.sh

	install -d $(STAGING_DIR)$(SYS_USR_DIR)/bin
	install -m 0755 $(WRKDIR)/systemd_units/update_hosts.sh $(STAGING_DIR)$(SYS_USR_DIR)/bin/

	install -m 0755 $(WRKDIR)/etc/init.d/dump-backup-service $(STAGING_DIR)$(SYS_CONF_DIR)

	install -d $(STAGING_DIR)$(BASE_BIN_DIR)/
	cp $(WRKDIR)/lib/rdk/timestamp $(STAGING_DIR)$(BASE_BIN_DIR)/.
	
	if [ -d $(WRKDIR)/device/devspec/etc ]; then \
		install -m 0644 $(WRKDIR)/device/devspec/etc/*.properties $(STAGING_DIR)$(SYS_CONF_DIR) ;\
	fi

	if [ -d $(WRKDIR)/device/devspec/lib/rdk ]; then \
		install -m 0755 $(WRKDIR)/device/devspec/lib/rdk/* $(STAGING_DIR)$(BASE_LIB_DIR)/rdk ;\
	fi

	if [ -d $(WRKDIR)/device/lib/rdk/install ]; then \
		rm -rf $(WRKDIR)/device/lib/rdk/install ;\
	fi
	if [ -d $(WRKDIR)/device/lib/rdk ]; then \
		install -m 0755 $(WRKDIR)/device/lib/rdk/* $(STAGING_DIR)$(BASE_LIB_DIR)/rdk ;\
	fi

	if [ -f $(WRKDIR)/device/etc/videoPrefs.json ]; then \
		install -m 0755 $(WRKDIR)/device/etc/videoPrefs.json $(STAGING_DIR)$(SYS_CONF_DIR) ;\
	fi
	if [ -f $(WRKDIR)/device/etc/socks.conf ]; then \
		install -m 0755 $(WRKDIR)/device/etc/socks.conf $(STAGING_DIR)$(SYS_CONF_DIR) ;\
	fi
	if [ -f $(WRKDIR)/device/etc/env_setup.sh ]; then \
		install -m 0755 $(WRKDIR)/device/etc/env_setup.sh $(STAGING_DIR)$(SYS_CONF_DIR) ;\
	fi
	if [ -f $(WRKDIR)/device/etc/device.properties.wifi ]; then \
		install -m 0755 $(WRKDIR)/device/etc/device.properties.wifi $(STAGING_DIR)$(SYS_CONF_DIR) ;\
	fi
	install -m 0755 $(WRKDIR)/device/etc/*.properties $(STAGING_DIR)$(SYS_CONF_DIR)

	rm -rf $(STAGING_DIR)$(BASE_LIB_DIR)/rdk/bankSwitchStatusLogger.sh
	rm -rf $(STAGING_DIR)$(BASE_LIB_DIR)/rdk/lighttpd_utility.sh
	rm -rf $(STAGING_DIR)$(BASE_LIB_DIR)/rdk/uploadDumps.sh

	ln -sf /lib/rdk/rebootSTB.sh $(STAGING_DIR)
	ln -sf /lib/rdk/rebootNow.sh $(STAGING_DIR)

package_ipk: install
	tar -czvf $(IPK_DIR)/data.tar.gz -C $(STAGING_DIR) . 
	tar -czvf $(IPK_DIR)/control.tar.gz -C $(IPK_DIR) control postinst prerm 
	cd $(IPK_DIR) && ar cr $(IPK_NAME) debian-binary control.tar.gz data.tar.gz && cd -
