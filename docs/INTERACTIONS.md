# Sysint — Component Interactions

[← Sysint](../README.md) · [Design & Architecture](DESIGN.md) · [Configuration](CONFIGURATION.md)

## Interaction Matrix

| Target Component / Layer           | Interaction Purpose                                                                                                                                                                                                                                   | Key APIs / Topics                                                                                                 |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| **OS Services**                    |                                                                                                                                                                                                                                                       |                                                                                                                   |
| `NetworkManager`                   | Receives IP add/del events and pre-down notifications via dispatcher scripts registered in `/etc/NetworkManager/dispatcher.d/`                                                                                                                        | `NM_Dispatcher.sh`, `NM_preDown.sh`                                                                               |
| `systemd-timesyncd` / `chronyd`    | Path unit watches the time-sync sentinel file to trigger NTP event dispatch; the active daemon (one or the other, never both) is selected via the `ChronyEnable` RFC flag, and `getPartnerProperty.sh` supplies its NTP server and polling parameters | `ntp-event.path` watches `/tmp/clock-event` (or `/run/systemd/timesync/synchronized`); `Device.Time.ChronyEnable` |
| `parodus.service`                  | Restarts parodus once ordered after `wpeframework.service`, triggered by the `authservice_parodus_restart` sentinel — an ordering constraint only; Thunder is not started and its active state is not checked                                         | `restart-parodus.path`, `systemctl restart parodus.service`                                                       |
| `logrotate`                        | Periodic log file rotation using Sysint-installed configuration                                                                                                                                                                                       | `logrotate.service` invokes `/usr/sbin/logrotate -s ... /etc/logrotatedata.conf`                                  |
| `dnsmasq` / Dobby container bridge | Supplies DNS resolution on the `dobby0` container interface used by Dobby-hosted applications                                                                                                                                                         | `etc/dnsmasq-dobby.conf` (`interface=dobby0`)                                                                     |
| **RDK Middleware Components**      |                                                                                                                                                                                                                                                       |                                                                                                                   |
| `WPEFramework` (Thunder)           | `restart-parodus.service` is ordered `After=wpeframework.service` — it does not start, stop, or verify that Thunder is active; `factory-reset.sh`/`warehouse-reset.sh` contain no direct Thunder stop/restart calls                                   | `After=wpeframework.service` in `restart-parodus.service`                                                         |
| Dobby container runtime            | Stopped during factory/warehouse reset teardown; provided DNS resolution via `dnsmasq-dobby.conf`                                                                                                                                                     | `systemctl stop Dobby` in `factory-reset.sh`/`warehouse-reset.sh`                                                 |
| DCM Agent (`/usr/bin/logupload`)   | Performs the actual log-upload transfer; Sysint only triggers it and supplies `dcm.properties`/`DCMSettings.conf` context                                                                                                                             | `LOG_UPLOAD_BIN_PATH=/usr/bin/logupload` in `Start_MaintenanceTasks.sh`                                           |
| Reboot-management binary           | External component that owns reboot classification, cyclic-reboot guarding, and reboot metadata; invoked (never implemented) by Sysint's reset scripts                                                                                                | `/rebootNow.sh` invoked from `factory-reset.sh`, `warehouse-reset.sh`, `utils.sh:rebootFunc()`                    |
| `rdkvfwupgrader`                   | Performs firmware download/flash on behalf of maintenance tasks and state-red recovery                                                                                                                                                                | `SWUPDATE_BIN=$COMMON_BIN_LOCATION/rdkvfwupgrader` in `Start_MaintenanceTasks.sh`; `stateRedRecovery.sh`          |
| `syslog-ng`                        | Routes per-service journal output into dedicated log files under `/opt/logs/` using build-time generated filter/destination rules                                                                                                                     | `SYSLOG-NG_*` Yocto recipe variables; `systemd_units/after_syslog-ng.conf`                                        |
| **System Event Bus**               |                                                                                                                                                                                                                                                       |                                                                                                                   |
| Event bus signal sender            | Dispatches `NTPReceivedEvent` to the platform-wide event bus on NTP synchronization                                                                                                                                                                   | `IARM_event_sender NTPReceivedEvent 1` in `ntp-event.service`                                                     |
| Event bus signal sender            | Dispatches an error event only when an RFC, firmware update, or log upload task fails; no event is sent for progress or successful completion                                                                                                         | `IARM_event_sender` calls in `Start_MaintenanceTasks.sh`                                                          |
| **D-Bus**                          |                                                                                                                                                                                                                                                       |                                                                                                                   |
| `org.Systime`                      | Broadcasts `TimeSet` signal when system time is set to last-known-good or build time                                                                                                                                                                  | `dbus-send --system … org.Systime.TimeSet`                                                                        |
| `org.NtpSync`                      | Broadcasts `TimeSet` signal on NTP sync completion or 180-second expiry                                                                                                                                                                               | `dbus-send --system … org.NtpSync.TimeSet`                                                                        |
| **RFC / Configuration Store**      |                                                                                                                                                                                                                                                       |                                                                                                                   |
| `tr181Set` / `tr181` utility       | Reads RFC-controlled feature flags at script invocation time                                                                                                                                                                                          | `Device.DeviceInfo.X_RDKCENTRAL-COM_RFC.Feature.*` parameters                                                     |
| **Cloud Services**                 |                                                                                                                                                                                                                                                       |                                                                                                                   |
| Crash upload server                | Transfers core dumps and mini-dumps via the `uploadDumps.sh` helper after network is available                                                                                                                                                        | `coredump-upload.service`, `minidump-upload.service`                                                              |
| DCM / log upload server            | Receives uploaded logs from the `/usr/bin/logupload` DCM Agent binary                                                                                                                                                                                 | `etc/dcm.properties` (`DCM_LOG_SERVER`, `DCM_LOG_SERVER_URL`, `DCM_SCP_SERVER`)                                   |
| XConf / firmware update server     | Supplies firmware update availability and download location, consumed by `xconfImageCheck.sh` and `rdkvfwupgrader`                                                                                                                                    | `swupdate_utility.sh`, `xconfImageCheck.sh`                                                                       |
| **Telemetry 2.0**                  |                                                                                                                                                                                                                                                       |                                                                                                                   |
| `t2Shared_api.sh`                  | Emits telemetry markers for CPU, memory, and network statistics                                                                                                                                                                                       | `t2ValNotify "cpuinfo_split"`, `t2ValNotify "FREE_MEM_split"`, `t2ValNotify "ConnectionStats"`                    |

## Events Published

| Event Name                 | Topic / Signal    | Trigger Condition                                                                                                                                                                                                                                                                      | Subscriber Components                                    |
| -------------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| `NTPReceivedEvent`         | System event bus  | Time-sync daemon writes `/tmp/clock-event` (path unit fires)                                                                                                                                                                                                                           | Time-dependent middleware services                       |
| `org.Systime.TimeSet`      | D-Bus system bus  | `system-time-set.target` activated                                                                                                                                                                                                                                                     | Services listening on D-Bus for system time availability |
| `org.NtpSync.TimeSet`      | D-Bus system bus  | `ntp-time-sync.target` activated                                                                                                                                                                                                                                                       | Services listening on D-Bus for NTP synchronization      |
| `INTERNET_FULLY_CONNECTED` | RDK log milestone | `notify-network-ready.service` touches the sentinel unconditionally once `dbus.service` is active, or `network-up.timer` fires 120s after boot — neither path verifies actual internet connectivity, so this milestone name is aspirational rather than a confirmed-connectivity check | Log analysis, boot milestone tracking                    |
| `RDK_STARTED`              | RDK log milestone | `log-rdk-start.service` runs before `multi-user.target`                                                                                                                                                                                                                                | Boot milestone tracking                                  |
| Maintenance failure events | System event bus  | `Start_MaintenanceTasks.sh` detects a task failure (RFC, firmware update, or log upload) — no event is sent on success or during in-progress phases                                                                                                                                    | Maintenance Manager plugin                               |

## IPC Flow Patterns

**NTP Event Notification Flow:**

The `NTPReceivedEvent` branch uses filesystem path monitoring without polling. Separately, `ntp-time-sync.path` activates `ntp-time-sync.target`, which starts the D-Bus event service. `ntp-time-sync.timer` also activates that target after 180 seconds without requiring a sentinel change, so `org.NtpSync.TimeSet` does not guarantee successful NTP synchronization. The diagram below shows only the path-triggered flows, with the intermediate target omitted.

```mermaid
sequenceDiagram
    participant TimeSyncd as systemd-timesyncd
    participant NTPPath as ntp-event.path (systemd)
    participant NTPSvc as ntp-event.service
    participant EvtBus as System Event Bus
    participant NTPTimeSyncPath as ntp-time-sync.path (systemd)
    participant NTPTimeSyncSvc as ntp-time-sync-event.service
    participant DBus as D-Bus

    TimeSyncd->>TimeSyncd: NTP synchronization complete
    TimeSyncd->>NTPPath: Write /tmp/clock-event
    NTPPath->>NTPSvc: PathChanged — activate
    NTPSvc->>NTPSvc: touch /tmp/stt_received
    NTPSvc->>NTPSvc: rdkLogMileStone CONNECT_TO_NTP_SERVER
    NTPSvc->>EvtBus: IARM_event_sender NTPReceivedEvent 1

    Note over NTPTimeSyncPath: Watches /tmp/systimemgr/ntp
    NTPTimeSyncPath->>NTPTimeSyncSvc: PathChanged — activate
    NTPTimeSyncSvc->>DBus: dbus-send org.NtpSync.TimeSet
```

**Network-Up Target Activation Flow:**

`network-up.target` marks that network bring-up is assumed complete; it is not a verified-connectivity signal. `NM_Dispatcher.sh` only refreshes the local IP/gateway cache on interface events and has no relationship to `notify-network-ready.service` or `network-up.timer` — the two activation paths below are independent of it and of each other.

```mermaid
sequenceDiagram
    participant DBusSvc as dbus.service
    participant NotifyNet as notify-network-ready.service
    participant NetUpTimer as network-up.timer
    participant NetUpPath as network-up.path (systemd)
    participant NetUpTgt as network-up.target

    DBusSvc-->>NotifyNet: After=dbus.service satisfied
    NotifyNet->>NotifyNet: touch /tmp/connectivity_check_done (unconditional, no connectivity check)
    NotifyNet->>NotifyNet: logMilestone.sh INTERNET_FULLY_CONNECTED
    NetUpPath->>NetUpTgt: PathChanged /tmp/connectivity_check_done — activate network-up.target

    Note over NetUpTimer,NetUpTgt: Independent path — runs regardless of NotifyNet
    NetUpTimer->>NetUpTgt: OnBootSec=120s — activate network-up.target unconditionally
    NetUpTgt-->>NetUpTgt: Dependent services unblocked (network bring-up assumed, not connectivity-verified)
```
