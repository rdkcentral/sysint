# Sysint — Configuration

[← Sysint](../README.md) · [Design & Architecture](DESIGN.md) · [Component Interactions](INTERACTIONS.md)

## Key Configuration Files

| Configuration File                    | Purpose                                                                                                                                                                        | Override Mechanism                                                     |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `/etc/device.properties`              | Device-specific properties: interface names (`ESTB_INTERFACE`, `WIFI_INTERFACE`, `ETHERNET_INTERFACE`), feature flags (`WIFI_SUPPORT`, `HDD_ENABLED`, `DEVICE_TYPE`), hostname | Replaced per-device variant at build time                              |
| `/etc/common.properties`              | Build-level constants: `BUILD_TYPE`, `LOG_PATH`, `CRASH_SVR` addresses, `UTILITY_PATH`, `RW_PATH`                                                                              | Replaced per-build configuration                                       |
| `/etc/include.properties`             | Filesystem path constants: `LOG_PATH`, `PERSISTENT_PATH`, `RAMDISK_PATH`, `UTILITY_PATH`, `RDK_PATH`, `DUMP_EXTN`                                                              | Replaced per-platform at build time                                    |
| `/etc/config.properties`              | Crash and log server upload settings: server addresses, ports, credentials paths                                                                                               | Replaced per-deployment environment                                    |
| `/etc/env_setup.sh`                   | Shell environment aliases (`reboot`, `ps`, `date -u`, `journalctl --utc`) applied to every Sysint shell session                                                                | Sourced by all scripts; replicated per platform                        |
| `/etc/diskMon.conf`                   | Directory paths and maximum sizes (MB) monitored by `diskMon.sh`                                                                                                               | Edited in-image or replaced by a platform layer                        |
| `/etc/rfcdefaults/sysint-generic.ini` | Default RFC parameter values for Sysint features: mTLS upload flags, secure dump, standby reboot interval                                                                      | Overridden at runtime by RFC server push                               |
| `/etc/dcm.properties`                 | DCM Agent log-upload endpoints consumed by the `/usr/bin/logupload` binary                                                                                                     | Overridden per-deployment via `/opt/dcm.properties` on non-prod builds |
| `/etc/telemetry2_0.properties`        | Path to the Telemetry 2.0 binary and its log files, used by every script that calls `t2ValNotify`/`t2CountNotify`                                                              | Replaced per-platform at build time                                    |
| `/etc/dnsmasq-dobby.conf`             | Binds `dnsmasq` to the Dobby container bridge interface (`dobby0`)                                                                                                             | Replaced per-platform at build time                                    |
| `/etc/10-unmanaged-devices`           | NetworkManager keyfile excluding virtual/container interfaces (`dobby*`, `veth*`, `wl0.2`, ...) from management                                                                | Edited in-image or replaced by a platform layer                        |
| `/etc/rfcdefaults/serial_config.ini`  | Default serial-console (UART) parameters and the RDK service-store path                                                                                                        | Overridden at runtime by RFC server push                               |

## Configuration File Variable Reference

- **`/etc/device.properties`** — Per-device identity and capability flags: `DEVICE_TYPE`, `HOSTNAME`, `BLUETOOTH_ENABLED`, `HDD_ENABLED`, `WIFI_SUPPORT`, `RDK_EMULATOR`, `LABSIGNED_ENABLED`; interface names `ESTB_INTERFACE`, `ETHERNET_INTERFACE`, `WIFI_INTERFACE`, `MOCA_INTERFACE`, `UDHCP_INTERFACE`, `WAN_INTERFACE`, `HTTPD_INTERFACE`; default network addressing `DEFAULT_IP`, `DEFAULT_ESTB_IP`, `DEFAULT_ECM_IP`, `GATEWAY_IP`, `NETWORK_ID`; `DCM_LOG_PATH`; Dropbear identity `POTOMAC_USER`, `POTOMAC_IDENTITY_FILE`; crash-portal reachability `CRASH_PORTAL_PATH`, `CRASH_PORTAL_SERVER`, `CRASH_PORTAL_USER`; `SCHEDULE_REBOOT_INTERVAL` (used by the external reboot-management binary, not Sysint).
- **`/etc/common.properties`** — Build-wide constants: `BUILD_TYPE` (`dev`/`prod`, gates whether `/opt/*.properties` overrides are honored), `LOG_PATH`, `UTILITY_PATH`, `RW_PATH`, `DUMP_EXTN`, `BUILD_VERSION`, `INTERFACE`/`UDHCP_IF`/`DEFAULT_IP` defaults, `PROXY_FILE`, `DEFAULT_PROXY_PORT`, `POTOMAC_SVR`, `REBOOT_INTERVAL`, `PERF_TEST`, `IP_ONLY`.
- **`/etc/include.properties`** — Filesystem path constants sourced by nearly every script: `LOG_PATH`, `PERSISTENT_PATH` (`/opt`), `RAMDISK_PATH` (`/tmp`), `TEMP_LOG_PATH`, `UTILITY_PATH`/`RDK_PATH` (`/lib/rdk`), `DUMPFILE_EXTN`/`DUMP_EXTN`, `CRON_SPOOL`, `CRON_FIFO_FILE`, `DIRECT_BLOCK_TIME`, `CB_BLOCK_TIME`.
- **`/etc/config.properties`** — Crash/coredump upload transport settings: `PORTAL_URL`, `POTOMAC_USER`, `POTOMAC_IDENTITY_FILE`, `CRASH_PORTAL_PATH`, `CRASH_SERVER_COREDUMP_PORT`, `CRASH_SERVER_MINIDUMP_PORT`, `POTOMAC_SVR`.
- **`/etc/dcm.properties`** — DCM Agent endpoints: `LOG_SERVER`, `DCM_LOG_SERVER`, `DCM_LOG_SERVER_URL`, `DCM_SCP_SERVER`, `HTTP_UPLOAD_LINK`, `DCA_UPLOAD_URL`; sourced by `Start_MaintenanceTasks.sh` and `reportFailuresToSplunk.sh`.
- **`/etc/env_setup.sh`** — Shell aliases applied where sourced: `reboot`, `ps`, `tftp`, `top`, `date -u`, and a conditional `journalctl --utc` alias.
- **`/etc/diskMon.conf`** — A `path size_in_MB` list (e.g. `/opt/logs/ 500`, `/opt/corefiles/ 1000`, `/opt/minidumps/ 500`) consumed line-by-line by `diskMon.sh`.
- **`/etc/telemetry2_0.properties`** — `T2_0_BIN`, `T2_0_APP`, `T2_0_LOGFILE`, `DCM_LOG_FILE`.
- **`/etc/dnsmasq-dobby.conf`** — Single `interface=dobby0` directive binding `dnsmasq` to the Dobby container network.
- **`/etc/10-unmanaged-devices`** — NetworkManager `[keyfile]` section listing interface-name globs NetworkManager must not manage.
- **`/etc/rfcdefaults/sysint-generic.ini`** — Default values for the mTLS, secure-dump, and standby-reboot RFC parameters listed in Key Configuration Parameters below, applied before the device's first successful RFC sync.
- **`/etc/rfcdefaults/serial_config.ini`** — Default `[SerialConfig]` values: `port`, `baudrate`, `charactersize`, `flowcontrol`, `parity`, `stopbits`, and `rdkservicestorepath`.

## Key Configuration Parameters

| Parameter                                                                        | Type | Default                   | Description                                                                                                                                       |
| -------------------------------------------------------------------------------- | ---- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MEMSWAP.Enable`                  | bool | `false`                   | Enables ZRAM compressed swap initialization on boot.                                                                                              |
| `Device.Time.ChronyEnable`                                                       | bool | —                         | Selects `chronyd` as the active time-sync daemon instead of `systemd-timesyncd`; the two are mutually exclusive. Read by `getPartnerProperty.sh`. |
| `Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.SecDump.Enable`                  | bool | `true`                    | Enables secure (encrypted) crash dump collection path.                                                                                            |
| `Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.StandbyReboot.Enable`            | bool | `true`                    | Enables automatic reboot from standby after the configured interval.                                                                              |
| `Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.StandbyReboot.StandbyAutoReboot` | int  | `86400`                   | Standby auto-reboot interval in seconds (default 24 hours).                                                                                       |
| `Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MTLS.mTlsDCMUpload.Enable`       | bool | `true`                    | Enforces mutual TLS for DCM log upload.                                                                                                           |
| `Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.MTLS.mTlsCrashdumpUpload.Enable` | bool | `true`                    | Enforces mutual TLS for crash dump upload.                                                                                                        |
| `Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.CRL.Enable`                      | bool | —                         | Enables OCSP stapling; controls creation of `/tmp/.EnableOCSPStapling`.                                                                           |
| `Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.CRL.DirectOCSP`                  | bool | —                         | Enables direct OCSP CA validation; controls creation of `/tmp/.EnableOCSPCA`.                                                                     |
| `Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.USB_AutoMount.Enable`            | bool | —                         | Controls whether the `usb-storage` kernel module is loaded at boot.                                                                               |
| `DEFAULT_THRESHOLD_SIZE`                                                         | int  | `80` (flash) / `90` (HDD) | Persistent storage fill percentage at which disk cleanup is triggered.                                                                            |
| `ZRAM_MEM_MAX_PERCENTAGE`                                                        | int  | `50`                      | Maximum percentage of total RAM allocated to ZRAM swap devices, read from `device.properties`.                                                    |

## Build-Time Configurations

The following flags are evaluated in the Yocto recipe's `do_install()` and control which files and properties are deployed into the image. They are derived from `DISTRO_FEATURES` and `bb.utils.contains` conditional evaluations in `sysint_git.bb`.

| Flag                     | `DISTRO_FEATURES` Condition                                      | Effect                                                                                                                             |
| ------------------------ | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `BIND_ENABLED`           | `bind`                                                           | Appends `BIND_ENABLED=true` to `device-middleware.properties`                                                                      |
| `MMC_TYPE = EMMC`        | `storage_emmc`                                                   | Appends `SD_CARD_TYPE=EMMC`; retains `emmc_format.sh` in the image                                                                 |
| `FORCE_MTLS`             | `mtls_only`                                                      | Appends `FORCE_MTLS=true` to `device-middleware.properties`                                                                        |
| `ENABLE_MAINTENANCE`     | `enable_maintenance_manager`                                     | Appends `ENABLE_MAINTENANCE=true`; activates software opt-out if also set                                                          |
| `ENABLE_SOFTWARE_OPTOUT` | `enable_software_optout` (requires `enable_maintenance_manager`) | Appends `ENABLE_SOFTWARE_OPTOUT=true`                                                                                              |
| `ENABLE_SYSLOGNG`        | `syslog-ng`                                                      | Activates `syslog-ng-config-gen` class; configures per-service log destinations and rate limits defined by `SYSLOG-NG_*` variables |
| `DUNFELL_BUILD`          | `dunfell`                                                        | Replaces the `ntp-event.path` watched path from `/tmp/clock-event` to `/run/systemd/timesync/synchronized`                         |
| `STG_TYPE = SDCARD`      | `storage_sdc`                                                    | Activates rdkstb-specific `disk-check.service` and `usbmodule-whitelist.service`                                                   |

## Runtime Configuration

RFC parameters can be updated remotely via the RFC server. After a parameter push, the feature takes effect at the next activation of the relevant Sysint script — timer-driven services apply the change on the next timer interval, while one-shot boot services apply it on the next reboot. To refresh access lists at runtime, update `$RFC_RAM_PATH/.RFC_SSHWhiteList.list` or `$RFC_RAM_PATH/.RFC_SNMPWhiteList.list` and invoke `/lib/rdk/iptables_init SSH_Refresh` or `/lib/rdk/iptables_init SNMP_Refresh`, respectively. The separate `Refresh` argument updates interface-dependent rules, not these whitelists.

## Configuration Persistence

Device properties (`/etc/device.properties`, `/etc/include.properties`, `/etc/common.properties`) are baked into the image and remain constant across reboots. For scripts sourcing `utils.sh`, non-production builds load `$PERSISTENT_PATH/rfc.properties` (`/opt/rfc.properties` with the shipped paths) when it exists, otherwise falling back to `/etc/rfc.properties`; production builds always load `/etc/rfc.properties`. The device details cache at `/tmp/.deviceDetails.cache` is managed by Sysint scripts directly and is refreshed each boot cycle in `/tmp`. Reboot metadata under `/opt/secure/reboot/` persists across reboots but is owned and written by the externally supplied `rebootNow` binary, not by Sysint. Log files under `/opt/logs/` are retained across reboots and managed by `logrotate`.
