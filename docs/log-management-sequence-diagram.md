# RDK Log Management System - Sequence Diagram

## Script Invocation Flow from systemd Services

```mermaid
sequenceDiagram
    participant SystemD as systemd
    participant BackupSvc as backup-service
    participant BackupScript as backup_logs.sh
    participant UploadScript as uploadSTBLogs.sh
    participant NowScript as UploadLogsNow.sh
    participant Config as Configuration
    participant FileSystem as Storage
    participant Network as Cloud

    Note over SystemD: System Boot Process
    SystemD->>BackupSvc: Activate previous-log-backup.service
    BackupSvc->>BackupScript: Execute backup_logs.sh
    
    Note over BackupScript: STAGE 1: Log Backup and Rotation
    BackupScript->>Config: Load configuration
    BackupScript->>FileSystem: Check LOG_PATH
    BackupScript->>FileSystem: Create PreviousLogs directories
    
    alt HDD_ENABLED = false
        BackupScript->>FileSystem: Rotate logs (bak1-bak2-bak3)
    else HDD_ENABLED = true
        BackupScript->>FileSystem: Create timestamped backup dir
    end
    
    BackupScript->>SystemD: Notify ready

    Note over SystemD: STAGE 2: Upload Triggers
    
    alt Scheduled Upload
        SystemD->>UploadScript: Execute uploadSTBLogs.sh
        Note over UploadScript: Maintenance window trigger
    else On-Demand Upload  
        SystemD->>NowScript: Execute UploadLogsNow.sh
        Note over NowScript: SNMP/TR69 triggered
    end

    Note over UploadScript: STAGE 3: Main Upload Engine
    UploadScript->>FileSystem: Acquire lock
    UploadScript->>Config: Load all configuration sources
    UploadScript->>FileSystem: Copy logs to staging area
    UploadScript->>FileSystem: Create compressed archive
    
    alt Direct Upload Available
        UploadScript->>Network: Direct HTTPS upload
    else Codebig Required
        UploadScript->>Network: Upload via Codebig proxy
    end
    
    alt Upload Successful
        UploadScript->>FileSystem: Update status - Complete
        UploadScript->>FileSystem: Cleanup temp files
    else Upload Failed
        UploadScript->>FileSystem: Update status - Failed
        UploadScript->>FileSystem: Log error details
    end
    
    UploadScript->>FileSystem: Release lock
    
    Note over SystemD: STAGE 4: Status and Cleanup
    UploadScript->>SystemD: Send IARM events
    UploadScript->>FileSystem: Update status file
    UploadScript->>FileSystem: Clean staging area
```

## Key Integration Points

### 1. **Systemd Service Dependencies**

```text
previous-log-backup.service:
- Before: multi-user.target  
- After: nvram.service local-fs.target
- Type: notify (sends ready signal)

logrotate.timer:
- Periodic: OnStartupSec=120s, OnUnitActiveSec=1min
- Triggers: logrotate.service
```

### 2. **Script Interaction Matrix**

| Script | Calls | Called By | Shared Resources |
|--------|-------|-----------|------------------|
| backup_logs.sh | logfiles.sh, utils.sh | systemd service | LOG_PATH, PreviousLogs |
| uploadSTBLogs.sh | logfiles.sh, utils.sh, exec_curl_mtls.sh | All upload triggers | DCM_LOG_PATH, curl, flock |
| UploadLogsNow.sh | logfiles.sh, utils.sh | Direct SNMP/TR69 | DCM_LOG_PATH |
| uploadRRDLogs.sh | uploadSTBLogs.sh | Remote debugger | RRD_LOG_DIR |
| usbLogUpload.sh | utils.sh | USB detection | USB mount points |

### 3. **File System Flow**

```text
Application Logs -> /opt/logs/ -> backup_logs.sh -> PreviousLogs/
                                                     |
                                                     v
PreviousLogs/ -> Upload Scripts -> DCM_LOG_PATH -> tar.gz -> Network/USB
                                                     |
                                                     v
                                                Cleanup & Status
```

### 4. **Configuration Cascade**

```text
/etc/include.properties (base)
         |
         v
/etc/device.properties (device-specific)  
         |
         v
/etc/dcm.properties (DCM settings)
         |
         v
/tmp/DCMSettings.conf (runtime)
         |
         v
TR181 Parameters (RFC overrides)
```

## High-Level Operation Blocks

### **STAGE 1: System Initialization & Backup**

- **Trigger**: systemd boot process
- **Operations**: Log rotation, directory setup, file movement
- **Output**: Organized log structure for upload

### **STAGE 2: Periodic Maintenance**

- **Trigger**: Timer-based (logrotate.timer)
- **Operations**: Active log file rotation, cleanup
- **Output**: Maintained log file sizes

### **STAGE 3: Upload Triggers (Multiple Paths)**

- **A-Scheduled**: Maintenance windows, boot-time uploads
- **B-Immediate**: SNMP/TR69 triggered immediate uploads  
- **C-USB**: Manual USB-based log extraction
- **D-Debug**: Remote debugger issue-specific uploads

### **STAGE 4: Unified Upload Engine**

- **Operations**: Compression, network upload, retry logic, MTLS
- **Protocols**: Direct HTTPS, Codebig proxy, USB storage
- **Output**: Successful upload or logged failure

### **STAGE 5: Status & Cleanup**

- **Operations**: Status updates, file cleanup, system notifications
- **Output**: Clean system state, upload status tracking
