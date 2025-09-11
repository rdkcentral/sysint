# RDK Log Management System - High Level Design

## Document Information

- **Version:** 1.0
- **Status:** Current Architecture Analysis
- **Purpose:** Visual representation of existing log backup and upload system
- **Scope:** Documents current (as-is) architecture without proposing changes

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture Components](#2-architecture-components)
3. [Data Flow Architecture](#3-data-flow-architecture)
4. [Component Interactions](#4-component-interactions)
5. [Upload Path Decision Logic](#5-upload-path-decision-logic)
6. [State Management](#6-state-management)
7. [Security Architecture](#7-security-architecture)
8. [Deployment View](#8-deployment-view)

## 1. System Overview

The RDK Log Management System provides comprehensive log backup, rotation, and upload capabilities across diverse embedded devices with varying storage and connectivity constraints.

```mermaid
graph TB
    subgraph "External Triggers"
        A[System Boot]
        B[Maintenance Scheduler]
        C[Remote Management SNMP/TR69]
        D[Remote Debugger]
        E[Field Engineer USB]
    end
    
    subgraph "Core System"
        F[Log Backup Engine]
        G[Upload Orchestrator]
        H[Configuration Manager]
    end
    
    subgraph "Storage Layer"
        I[Active Logs /opt/logs]
        J[Previous Logs Backup]
        K[Staging Area DCM_LOG_PATH]
    end
    
    subgraph "Network Layer"
        L[Direct HTTPS]
        M[Codebig Proxy]
        N[USB Export]
    end
    
    A --> F
    B --> G
    C --> G
    D --> G
    E --> N
    
    F --> I
    F --> J
    G --> K
    G --> L
    G --> M
    
    H --> F
    H --> G
```

## 2. Architecture Components

### 2.1 Component Overview

```mermaid
graph LR
    subgraph "Script Components"
        A[backup_logs.sh]
        B[uploadSTBLogs.sh]
        C[UploadLogsNow.sh]
        D[uploadRRDLogs.sh]
        E[usbLogUpload.sh]
    end
    
    subgraph "Shared Libraries"
        F[logfiles.sh]
        G[utils.sh]
        H[interfaceCalls.sh]
    end
    
    subgraph "Configuration"
        I[include.properties]
        J[device.properties]
        K[dcm.properties]
        L[TR181 Parameters]
    end
    
    A --> F
    B --> F
    B --> G
    B --> H
    C --> F
    C --> G
    D --> B
    E --> G
    
    F --> I
    G --> J
    H --> K
    B --> L
```

### 2.2 Component Responsibilities

| Component | Primary Responsibility | Key Functions |
|-----------|----------------------|---------------|
| `backup_logs.sh` | Log rotation and preservation | Boot-time backup, tiered rotation, version metadata |
| `uploadSTBLogs.sh` | Main upload engine | Staging, compression, protocol negotiation, retry logic |
| `UploadLogsNow.sh` | Immediate upload | Lightweight on-demand upload via SNMP/TR69 |
| `uploadRRDLogs.sh` | Debug artifact upload | Remote debugger bundle creation and delegation |
| `usbLogUpload.sh` | Manual extraction | USB-based offline log extraction |
| `logfiles.sh` | Log definitions | Variable definitions for log file patterns |
| `utils.sh` | Common utilities | MAC address, IP, timestamp functions |

## 3. Data Flow Architecture

### 3.1 Log Lifecycle Flow

```mermaid
flowchart TD
    A[Application Logs Generated] --> B[Active Log Directory /opt/logs]
    
    B --> C{Boot/Rotation Event}
    C -->|HDD Disabled| D[Multi-tier Rotation bak1-bak2-bak3]
    C -->|HDD Enabled| E[Timestamped Directory Creation]
    
    D --> F[PreviousLogs Structure]
    E --> F
    
    F --> G{Upload Trigger}
    G -->|Scheduled| H[Main Upload Engine]
    G -->|On-Demand| I[Immediate Upload]
    G -->|Debug| J[RRD Upload]
    G -->|Manual| K[USB Export]
    
    H --> L[Staging Area DCM_LOG_PATH]
    I --> L
    J --> L
    K --> M[USB Mount Point]
    
    L --> N[Timestamp Prefixing]
    N --> O[Archive Creation tar-gz]
    
    O --> P{Upload Path Decision}
    P -->|Direct Available| Q[Direct HTTPS Upload]
    P -->|Blocked/Fallback| R[Codebig Proxy Upload]
    
    Q --> S[Cloud Storage]
    R --> S
    M --> T[USB Device]
    
    S --> U[Status Update Complete/Failed]
    T --> V[Status Update Complete]
    
    U --> W[Cleanup Staging]
    V --> X[Syslog-ng Reload]
```

### 3.2 Configuration Flow

```mermaid
flowchart LR
    A[include.properties] --> D[Runtime Configuration]
    B[device.properties] --> D
    C[dcm.properties] --> D
    
    D --> E{TR181 Available?}
    E -->|Yes| F[TR181 Parameter Query]
    E -->|No| G[Static Properties]
    
    F --> H[Dynamic Configuration]
    G --> H
    
    H --> I[Script Execution Context]
    
    subgraph "Override Priority"
        F
        G
        A
        B
        C
    end
```

## 4. Component Interactions

### 4.1 Boot Sequence Interaction

```mermaid
sequenceDiagram
    participant S as systemd
    participant B as backup_logs.sh
    participant FS as FileSystem
    participant C as Configuration
    
    S->>B: Activate previous-log-backup.service
    B->>C: Load properties
    B->>FS: Check LOG_PATH
    
    alt HDD_ENABLED = false
        B->>FS: Multi-tier rotation
        Note over B,FS: bak1-bak2-bak3 cascade
    else HDD_ENABLED = true
        B->>FS: Create timestamped directory
        Note over B,FS: logbackup-timestamp format
    end
    
    B->>FS: Touch last_reboot marker
    B->>FS: Copy version files
    B->>S: systemd-notify --ready
```

### 4.2 Upload Engine Interaction

```mermaid
sequenceDiagram
    participant T as Trigger
    participant U as uploadSTBLogs.sh
    participant L as Lock Manager
    participant S as Staging
    participant N as Network
    participant ST as Status
    
    T->>U: Invoke upload
    U->>L: Acquire flock
    
    alt Lock Available
        L-->>U: Lock acquired
        U->>S: Copy logs to staging
        U->>S: Apply timestamp prefixes
        U->>S: Create compressed archive
        
        alt Direct Path
            U->>N: Direct HTTPS upload
        else Codebig Path
            U->>N: Signed URL upload
        end
        
        alt Success
            N-->>U: HTTP 200
            U->>ST: Status = Complete
            U->>S: Clean staging
        else Failure
            N-->>U: Error code
            U->>ST: Status = Failed
        end
        
        U->>L: Release lock
    else Lock Held
        L-->>U: Lock unavailable
        U->>U: Exit early
    end
```

## 5. Upload Path Decision Logic

### 5.1 Path Selection Decision Tree

```mermaid
flowchart TD
    A[Upload Request] --> B{Lock Available?}
    B -->|No| C[Exit Early - Log Contention]
    B -->|Yes| D[Acquire Lock]
    
    D --> E{Upload Type?}
    E -->|Scheduled| F[Full Upload Engine]
    E -->|On-Demand| G[Immediate Upload]
    E -->|Debug| H[RRD Delegate to Main]
    E -->|USB| I[USB Export]
    
    F --> J{Direct Path Available?}
    G --> K[Simple HTTP Upload]
    H --> F
    I --> L[Move to USB]
    
    J -->|Yes| M[Direct HTTPS]
    J -->|Blocked| N[Codebig Proxy]
    
    M --> O{Upload Success?}
    N --> O
    K --> P{On-Demand Success?}
    
    O -->|Yes| Q[Update Status Complete]
    O -->|No| R[Retry Logic]
    P -->|Yes| S[Status Complete]
    P -->|No| T[Status Failed]
    
    R --> U{Retries Exhausted?}
    U -->|No| V[Sleep and Retry]
    U -->|Yes| W[Status Failed]
    
    V --> O
    Q --> X[Clean Staging]
    W --> X
    S --> Y[Clean Staging]
    T --> Y
    L --> Z[Reload syslog-ng]
```

### 5.2 Protocol Selection Matrix

```mermaid
graph TD
    A[Upload Request] --> B{Network Assessment}
    
    B --> C{Direct Block File Exists?}
    C -->|Yes| D[Force Codebig Path]
    C -->|No| E{Codebig Available?}
    
    E -->|Yes| F{Policy Preference?}
    E -->|No| G[Direct Only]
    
    F -->|Direct| H[Try Direct First]
    F -->|Codebig| I[Try Codebig First]
    
    H --> J{Direct Success?}
    J -->|Yes| K[Complete Direct]
    J -->|No| L[Fallback Codebig]
    
    I --> M{Codebig Success?}
    M -->|Yes| N[Complete Codebig]
    M -->|No| O[Fallback Direct]
    
    G --> P[Direct Upload]
    D --> Q[Codebig Upload]
    L --> Q
    O --> P
```

## 6. State Management

### 6.1 Upload Status State Machine

```mermaid
stateDiagram-v2
    [*] --> Idle
    
    Idle --> Triggered : Upload Request
    Triggered --> InProgress : Lock Acquired
    Triggered --> Blocked : Lock Unavailable
    
    InProgress --> Staging : Begin Staging
    Staging --> Compressing : Files Copied
    Compressing --> Uploading : Archive Created
    
    Uploading --> Complete : HTTP 200
    Uploading --> Retrying : HTTP Error + Retries < Max
    Uploading --> Failed : HTTP Error + Retries Exhausted
    
    Retrying --> Uploading : After Sleep
    
    Complete --> Cleanup : Success Path
    Failed --> Cleanup : Failure Path
    Blocked --> Idle : Lock Contention
    
    Cleanup --> Idle : Ready for Next
```

### 6.2 Log Backup State Flow

```mermaid
stateDiagram-v2
    [*] --> BootStart
    
    BootStart --> CheckingHDD : System Boot
    CheckingHDD --> NonHDDPath : HDD_ENABLED = false
    CheckingHDD --> HDDPath : HDD_ENABLED = true
    
    NonHDDPath --> CheckingTiers : Multi-tier Mode
    CheckingTiers --> FirstRun : No Previous Logs
    CheckingTiers --> RotateTiers : Previous Logs Exist
    
    FirstRun --> MoveLogs : Initial Backup
    RotateTiers --> CascadeBackups : bak1-bak2-bak3
    
    HDDPath --> CheckingTimestamp : Timestamp Mode
    CheckingTimestamp --> FirstRunHDD : No Previous
    CheckingTimestamp --> CreateTimestamped : Previous Exists
    
    FirstRunHDD --> MoveLogsHDD : Initial HDD Backup
    CreateTimestamped --> MoveToTimestamp : Create Directory
    
    MoveLogs --> Cleanup : Non-HDD Complete
    CascadeBackups --> Cleanup : Rotation Complete
    MoveLogsHDD --> VersionCopy : HDD Complete
    MoveToTimestamp --> VersionCopy : Timestamp Complete
    
    Cleanup --> VersionCopy : Copy Metadata
    VersionCopy --> NotifyReady : systemd-notify
    NotifyReady --> [*] : Boot Backup Complete
```

## 7. Security Architecture

### 7.1 Security Layer Integration

```mermaid
graph TB
    subgraph "Security Components"
        A[TLS Configuration]
        B[MTLS Certificate Validation]
        C[OCSP Stapling]
        D[Codebig OAuth Signing]
    end
    
    subgraph "Security Markers"
        E[EnableOCSPStapling]
        F[EnableOCSPCA]
        G[MTLS Capability Detection]
        H[Certificate Store]
    end
    
    subgraph "Upload Security Flow"
        I[Security Assessment]
        J[Curl Parameter Assembly]
        K[Connection Establishment]
        L[Upload Execution]
    end
    
    A --> I
    B --> I
    C --> I
    D --> I
    
    E --> A
    F --> A
    G --> B
    H --> B
    
    I --> J
    J --> K
    K --> L
```

### 7.2 Security Decision Flow

```mermaid
flowchart TD
    A[Upload Initiation] --> B{TLS Available?}
    B -->|Yes| C[Add --tlsv1.2]
    B -->|No| D[Plain HTTP]
    
    C --> E{OCSP Markers Present?}
    E -->|Yes| F[Add --cert-status]
    E -->|No| G[Standard TLS]
    
    F --> H{MTLS Capable?}
    G --> H
    
    H -->|Yes| I[Mutual Authentication Path]
    H -->|No| J[Server Authentication Only]
    
    I --> K{Codebig Required?}
    J --> K
    D --> K
    
    K -->|Yes| L[OAuth Signed URL]
    K -->|No| M[Direct Endpoint]
    
    L --> N[Authorized Upload]
    M --> O[Standard Upload]
    
    N --> P[Security Validation]
    O --> P
    P --> Q[Upload Complete]
```

## 8. Deployment View

### 8.1 System Deployment Architecture

```mermaid
graph TB
    subgraph "RDK Device"
        subgraph "systemd Services"
            A[previous-log-backup.service]
            B[logrotate.timer]
        end
        
        subgraph "Log Management Scripts"
            C[backup_logs.sh]
            D[uploadSTBLogs.sh]
            E[UploadLogsNow.sh]
            F[uploadRRDLogs.sh]
            G[usbLogUpload.sh]
        end
        
        subgraph "Shared Libraries"
            H[logfiles.sh]
            I[utils.sh]
            J[interfaceCalls.sh]
        end
        
        subgraph "File System"
            K[opt-logs]
            L[opt-logs-PreviousLogs]
            M[tmp-log-upload-lock]
            N[opt-loguploadstatus-txt]
        end
        
        subgraph "Configuration"
            O[include.properties]
            P[device.properties]
            Q[dcm.properties]
        end
    end
    
    subgraph "Network Infrastructure"
        subgraph "Direct Upload"
            R[SSR Endpoint]
            S[S3 Storage]
        end
        
        subgraph "Proxy Upload"
            T[Codebig Proxy]
            U[OAuth Service]
        end
    end
    
    subgraph "External Storage"
        V[USB Device]
    end
    
    subgraph "Management Systems"
        W[SNMP Manager]
        X[TR-069 ACS]
        Y[Remote Debugger]
    end
    
    %% Dependencies
    A --> C
    C --> H
    D --> H
    D --> I
    E --> H
    F --> D
    G --> I
    
    C --> K
    D --> L
    D --> M
    D --> N
    
    H --> O
    I --> P
    J --> Q
    
    D --> R
    D --> T
    G --> V
    W --> E
    X --> E
    Y --> F
```

### 8.2 Runtime Environment Dependencies

```mermaid
graph LR
    subgraph "System Dependencies"
        A[POSIX Shell /bin/sh]
        B[Core Utilities tar, gzip, mv, cp]
        C[Network Tools curl]
        D[System Tools systemd-notify]
        E[File Tools find, awk, grep]
    end
    
    subgraph "Optional Dependencies"
        F[tr181 Binary]
        G[IARM_event_sender]
        H[syslog-ng]
        I[MTLS Certificate Store]
    end
    
    subgraph "Runtime Environment"
        J[Environment Variables]
        K[Configuration Files]
        L[Lock Files]
        M[Status Files]
    end
    
    A --> J
    B --> J
    C --> J
    D --> J
    E --> J
    
    F --> K
    G --> L
    H --> M
    I --> K
```

## 9. Key Architectural Characteristics

### 9.1 Current Architecture Strengths

- **Modularity**: Clear separation between backup and upload functions
- **Flexibility**: Multiple upload paths (direct, proxy, USB, debug)
- **Reliability**: Lock-based concurrency control for main engine
- **Portability**: POSIX shell compatibility across embedded platforms
- **Configurability**: Multi-layer configuration with runtime overrides

### 9.2 Current Architecture Constraints

- **Monolithic Upload Engine**: Single large script handling multiple responsibilities
- **Limited Concurrency Protection**: Not all paths use locking mechanism
- **Static Retry Logic**: Fixed retry counts without adaptive backoff
- **Manual Status Correlation**: Multiple log files for troubleshooting
- **Resource Intensive**: Full archive recreation for each upload

### 9.3 Integration Points

- **systemd Integration**: Service orchestration and readiness signaling
- **Network Stack**: Direct HTTPS and proxy-based upload protocols
- **Configuration Management**: TR181/RFC parameter integration
- **Security Infrastructure**: Optional MTLS and OCSP validation
- **Storage Management**: Multi-tier backup with device-specific logic

## Document Summary

This High Level Design document provides a comprehensive visual representation of the current RDK Log Management System architecture using Mermaid diagrams. It captures the existing implementation without suggesting modifications, serving as a reference for understanding the system's structure, data flows, and component interactions.
