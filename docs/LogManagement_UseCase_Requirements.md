# RDK Log Management – Use Case Requirements (As-Is)

## 1. Document Overview
This document captures the current (as-is) functional use cases of the Log Backup & Upload subsystem implemented by existing shell scripts. It formalizes observed behaviors without recommending changes.

## 2. Scope
In scope: log collection preservation, rotation, archiving, upload (direct/Codebig/on-demand/debug/USB), status signaling, security toggles, and trigger pathways. Out of scope: future enhancements, refactoring strategy, analytics enrichment.

## 3. Actors
| Actor ID | Actor Name | Description |
|----------|------------|-------------|
| A1 | Device OS / systemd | Initiates services at boot (backup + scheduled flows). |
| A2 | Maintenance Orchestrator | Higher-level maintenance or scheduling component triggering periodic uploads. |
| A3 | Remote Management System (SNMP / TR-069) | Issues on-demand immediate upload trigger. |
| A4 | Remote Debugger Subsystem | Generates diagnostic bundles requiring upload. |
| A5 | Field Engineer / Technician | Manually extracts logs via USB. |
| A6 | Cloud SSR / Codebig Endpoint | Provides signed URLs or accepts direct uploads. |
| A7 | Network Environment | May impede connectivity, triggering retry / fallback. |
| A8 | Security Infrastructure (MTLS / OCSP) | Optional validation services influencing curl parameters. |

## 4. System Components (Referenced)
| Component | Role |
|-----------|------|
| `backup_logs.sh` | Boot-time and rotational log preservation. |
| `uploadSTBLogs.sh` | Primary staging + upload execution engine. |
| `UploadLogsNow.sh` | Lightweight immediate (on-demand) uploader. |
| `uploadRRDLogs.sh` | Remote debugger artifact packaging and delegation. |
| `usbLogUpload.sh` | Manual offline archive to removable media. |
| `logfiles.sh` | Log file variable definitions. |
| `utils.sh` | Common helper functions (MAC, IP, timestamp). |

## 5. Global Preconditions / Environmental Assumptions
- Filesystem paths (e.g., `/opt/logs`) are writable and mounted.
- Required helper binaries present where invoked (e.g., `curl`, `tr181`, `tar`, `systemd-notify`).
- Network stack initialized before upload attempts (except asynchronous retries not implemented).
- Clock may or may not be synchronized; timestamps are still produced.
- For MTLS/OCSP mode, marker files exist under `/tmp/` when enabled.

## 6. Use Case Catalogue
| UC ID | Name | Primary Actor | Goal |
|-------|------|---------------|------|
| UC-01 | Boot Log Backup (Non-HDD) | Device OS | Preserve prior session logs with tiered rotation. |
| UC-02 | Boot Log Backup (HDD) | Device OS | Archive previous logs into timestamped directory. |
| UC-03 | Scheduled Log Upload | Maintenance Orchestrator | Periodically ship aggregated logs upstream. |
| UC-04 | Immediate On-Demand Upload | Remote Management System | Fetch current logs promptly (diagnostics). |
| UC-05 | Remote Debugger Upload | Remote Debugger Subsystem | Upload debug bundle tied to issue type. |
| UC-06 | USB Manual Extraction | Field Engineer | Extract current logs to removable media. |
| UC-07 | Direct HTTPS Upload | Upload Engine | Deliver archive via direct SSR endpoint. |
| UC-08 | Codebig Proxy Upload | Upload Engine | Use signed URL when direct blocked/unavailable. |
| UC-09 | Upload Retry Handling | Upload Engine | Attempt bounded retries during transient failures. |
| UC-10 | Upload Status Signaling | Upload Engine | Expose lifecycle state (Triggered → Complete/Failed). |
| UC-11 | Concurrency Prevention | Upload Engine | Prevent multiple simultaneous upload operations. |
| UC-12 | RRD Issue-Specific Naming | Remote Debugger Subsystem | Encode issue type in artifact filename. |
| UC-13 | Timestamp Prefixing | Upload Engine | Disambiguate file names and retain ordering. |
| UC-14 | TLS / MTLS Conditional Enable | Security Infrastructure | Apply security flags dynamically. |
| UC-15 | OCSP Stapling Conditional | Security Infrastructure | Append `--cert-status` when enabled. |
| UC-16 | Log Directory Exclusion | Upload Engine | Avoid recursive inclusion of internal folders. |
| UC-17 | Version Metadata Preservation | Backup Script | Include version identifiers in preserved logs. |
| UC-18 | Disk Threshold Check | Backup Script | Trigger disk threshold script pre-backup. |
| UC-19 | Remote Debugger Throttling | Remote Debugger Subsystem | Avoid upload conflict via attempt loop. |
| UC-20 | Syslog-ng Reinitialization (USB) | Field Engineer | Reopen log file handles post-move. |

---
## 7. Detailed Use Cases
### UC-01 Boot Log Backup (Non-HDD)
| Item | Description |
|------|-------------|
| Primary Actor | Device OS / systemd (`previous-log-backup.service`) |
| Goal | Retain logs from prior boot(s) using limited rolling slots. |
| Preconditions | `LOG_PATH` exists (or created); non-HDD mode detected (`HDD_ENABLED=false`). |
| Triggers | System boot sequence after local file systems ready. |
| Main Flow | 1. Remove stale `last_reboot` marker if present. 2. If first rotation slot empty, move all qualifying logs to `PreviousLogs/`. 3. Else cascade rotations (current→bak3, bak2→bak3, bak1→bak2, base→bak1). 4. Touch `last_reboot`. 5. Clear active directory. |
| Postconditions | Up to four tiers (`messages.txt`, `bak1_`, `bak2_`, `bak3_`) preserved. Active directory ready for new logs. |
| Alternate | Rotation failure logs error but process continues; missing logs tolerated. |
| Exceptions | Move interruption may result in partial tier set (no rollback). |

### UC-02 Boot Log Backup (HDD)
| Item | Description |
|------|-------------|
| Primary Actor | Device OS |
| Goal | Persist each reboot’s logs in a uniquely timestamped folder. |
| Preconditions | `HDD_ENABLED=true`. |
| Trigger | System boot. |
| Main Flow | 1. If first run (no base system log in `PreviousLogs`), move logs there. 2. Else create `logbackup-<timestamp>` directory. 3. Move active logs into that directory. 4. Touch `last_reboot`. |
| Postconditions | Historical directories accumulate chronologically. |
| Exceptions | Insufficient disk space may cause incomplete move. |

### UC-03 Scheduled Log Upload
| Item | Description |
|------|-------------|
| Primary Actor | Maintenance Orchestrator |
| Goal | Send compressed log bundle during maintenance window. |
| Preconditions | Network available; not blocked by existing upload lock. |
| Trigger | Scheduled maintenance invocation of `uploadSTBLogs.sh`. |
| Main Flow | 1. Acquire flock. 2. Gather eligible files (exclude `dcm`, `PreviousLogs*`). 3. Timestamp prefix. 4. Create tarball. 5. Determine route (direct or Codebig). 6. Perform upload with retries. 7. Update status. 8. Cleanup staging. |
| Postconditions | Archive transmitted or failure recorded. |
| Exceptions | Lock contention → immediate exit. Network failure → failure path after retries. |

### UC-04 Immediate On-Demand Upload
| Item | Description |
|------|-------------|
| Primary Actor | Remote Management System (SNMP/TR-069) |
| Goal | Quickly retrieve current logs outside scheduled cycle. |
| Preconditions | `UploadLogsNow.sh` accessible; target endpoint resolvable. |
| Trigger | Remote command / parameter set event. |
| Main Flow | 1. Copy current logs to staging. 2. Timestamp prefix (if needed). 3. Tar compress. 4. Query SSR URL → S3 upload path. 5. Upload with retry loop (fixed count). 6. Write status file. 7. Remove staging directory. |
| Postconditions | Latest logs available remotely. |
| Limitations | Limited protocol flexibility (no Codebig fallback). |

### UC-05 Remote Debugger Upload
| Item | Description |
|------|-------------|
| Primary Actor | Remote Debugger Subsystem |
| Goal | Upload issue-type tagged diagnostic archive. |
| Preconditions | Debug output directory populated; `uploadRRDLogs.sh` arguments valid. |
| Trigger | Remote debugger request generation. |
| Main Flow | 1. Normalize issue type (upper-case). 2. Pack directory into RRD tarball. 3. Attempt to delegate to `uploadSTBLogs.sh` (RRD mode). 4. Retry waiting if another upload in progress (poll loop). 5. Remove artifact on success. |
| Postconditions | RRD artifact delivered / failure logged. |
| Alternate | Live log mode moves pre-collected `RRD_LIVE_LOGS.tar.gz` first. |

### UC-06 USB Manual Extraction
| Item | Description |
|------|-------------|
| Primary Actor | Field Engineer |
| Goal | Export device logs offline to removable storage. |
| Preconditions | Device model supports feature; USB mounted; writable destination path. |
| Trigger | Manual invocation of `usbLogUpload.sh <mount>`. |
| Main Flow | 1. Verify device type. 2. Ensure mount path. 3. Create temp workspace. 4. Move active logs. 5. Create archive in `<mount>/Log/`. 6. Reload syslog-ng (SIGHUP). 7. Remove workspace. 8. Sync filesystem. |
| Postconditions | Archive present on USB. Active logging continues. |
| Exceptions | Missing mount or write error → exit with code (2/3/4). |

### UC-07 Direct HTTPS Upload
| Item | Description |
|------|-------------|
| Primary Actor | Upload Engine |
| Goal | Deliver log archive directly to SSR endpoint. |
| Preconditions | Not blocked by direct-failure marker; SSR URL retrieved (TR-181 or properties). |
| Trigger | Route decision logic selects direct path. |
| Main Flow | 1. Build curl command (optionally adding `--tlsv1.2`). 2. Add OCSP flag if markers exist. 3. Post metadata / acquire S3 URL if multi-step. 4. Upload archive. 5. Capture HTTP code. |
| Postconditions | Archive stored upstream. |
| Exceptions | Non-200 code marks failure; potential block file set externally (if implemented). |

### UC-08 Codebig Proxy Upload
| Item | Description |
|------|-------------|
| Primary Actor | Upload Engine |
| Goal | Use signed request when direct path unavailable. |
| Preconditions | Codebig signing utility accessible; direct path blocked or policy indicates. |
| Trigger | Fallback or explicit selection. |
| Main Flow | 1. Invoke signing helper (GetServiceUrl). 2. Parse OAuth-like header fields. 3. Execute curl with header and encoded parameters. 4. Log remote IP/port. 5. Upload archive. |
| Postconditions | Same as direct but via intermediary. |
| Exceptions | Signing failure → treat as upload failure. |

### UC-09 Upload Retry Handling
| Item | Description |
|------|-------------|
| Primary Actor | Upload Engine |
| Goal | Reduce transient failure probability. |
| Preconditions | Network transient conditions resolvable. |
| Trigger | Non-success HTTP code or curl failure. |
| Main Flow | 1. Loop attempts (3 typical). 2. Sleep fixed (e.g., 1s). 3. Break on success. |
| Postconditions | Either success or final failure recorded. |
| Limitations | No exponential backoff; no classification by failure type. |

### UC-10 Upload Status Signaling
| Item | Description |
|------|-------------|
| Primary Actor | Upload Engine |
| Goal | Provide human/machine readable state. |
| Artifacts | `/opt/loguploadstatus.txt` |
| States | Triggered, In progress, Complete <timestamp>, Failed <timestamp>. |
| Triggers | Each major phase transition. |
| Consumers | Maintenance orchestrator, external monitoring, field analysis. |

### UC-11 Concurrency Prevention
| Item | Description |
|------|-------------|
| Primary Actor | Upload Engine |
| Goal | Ensure only one upload manipulates staged assets. |
| Mechanism | File descriptor + flock on `/tmp/.log-upload.lock`. |
| Outcome | Subsequent invocation exits early (with log). |
| Limitations | Not applied to all scripts (e.g., on-demand path). |

### UC-12 RRD Issue-Specific Naming
| Item | Description |
|------|-------------|
| Primary Actor | Remote Debugger Subsystem |
| Naming Pattern | `<MAC>_<ISSUETYPE>_<TIMESTAMP>_RRD_DEBUG_LOGS.tgz` |
| Purpose | Correlate upload with diagnostic classification. |

### UC-13 Timestamp Prefixing
| Item | Description |
|------|-------------|
| Primary Actor | Upload Engine |
| Goal | Avoid filename collisions; encode temporal ordering. |
| Pattern | `<MM-DD-YY-HH-MM(AM|PM)>-<original>` |
| Scope | Applied selectively unless already time-tagged or exempt. |

### UC-14 TLS / MTLS Conditional Enable
| Item | Description |
|------|-------------|
| Trigger | Detection of platform support / flags. |
| Actions | Add `--tlsv1.2`; choose mutual auth path when xpki feature enabled. |

### UC-15 OCSP Stapling Conditional
| Item | Description |
|------|-------------|
| Trigger | Presence of `/tmp/.EnableOCSPStapling` or `/tmp/.EnableOCSPCA`. |
| Action | Add `--cert-status` to curl invocation. |

### UC-16 Log Directory Exclusion
| Item | Description |
|------|-------------|
| Exclusions | `dcm`, `PreviousLogs`, `PreviousLogs_backup` directories. |
| Goal | Prevent recursion and internal meta duplication. |

### UC-17 Version Metadata Preservation
| Item | Description |
|------|-------------|
| Files | `/version.txt`, `skyversion.txt`, `rippleversion.txt` |
| Stage | Backup phase (added to active log space). |

### UC-18 Disk Threshold Check
| Item | Description |
|------|-------------|
| Trigger | Boot backup script start. |
| Action | Invoke `/lib/rdk/disk_threshold_check.sh 0` if present. |
| Goal | Prevent uncontrolled growth / trigger cleanup logic. |

### UC-19 Remote Debugger Throttling
| Item | Description |
|------|-------------|
| Mechanism | Poll loop (up to 10 attempts; 60s sleep) waiting for absence of PID marker. |
| Goal | Avoid contention with ongoing primary upload. |

### UC-20 Syslog-ng Reinitialization (USB)
| Item | Description |
|------|-------------|
| Trigger | USB extraction after moving active logs. |
| Action | Send SIGHUP to `syslog-ng`. |
| Goal | Reopen log targets to continue logging seamlessly. |

---
## 8. Non-Functional Requirements (Observed Behavior)
| Category | Requirement (As Manifested) |
|----------|-----------------------------|
| Reliability | Limited fixed retry loops for network calls. |
| Availability | Upload skipped if lock held (prevents corruption). |
| Performance | Single-thread compression; synchronous curl requests. |
| Security | Optional MTLS, OCSP; no forced failure if absent. |
| Maintainability | Central engine script large; shared utilities for MAC/IP retrieval. |
| Portability | POSIX shell + core utilities; minimal external dependencies. |
| Traceability | Status + log files provide linear narrative of operations. |

## 9. Data & Artifact Definitions
| Artifact | Description |
|----------|-------------|
| Primary Log Archive | `MAC_Logs_<timestamp>.tgz` (general logs). |
| RRD Debug Archive | `MAC_<ISSUETYPE>_<timestamp>_RRD_DEBUG_LOGS.tgz`. |
| Status File | `/opt/loguploadstatus.txt`. |
| Previous Logs | Rotated or timestamped directories for reboot history. |
| Lock File | `/tmp/.log-upload.lock` (advisory lock). |

## 10. Termination / Exit Conditions
| Condition | Outcome |
|-----------|---------|
| Successful Upload | Status set to Complete; staging cleaned. |
| Failed Upload | Status set to Failed; log entries produced. |
| Lock Contention | Early exit; no modification to existing status (except possible log entry). |
| Missing Logs (on-demand) | Early exit after check; may set failure indirectly depending on path. |


## 11. Glossary
| Term | Definition |
|------|------------|
| SSR | Service / Secure Side Resolver: Service returning upload target or S3 URL. |
| Codebig | Proxy/auth signing mechanism for controlled routing. |
| RRD | Remote debugger diagnostic artifact flow. |
| MTLS | Mutual TLS authentication (client cert + server cert). |
| OCSP | Online Certificate Status Protocol for revocation checking. |

## 12. References
- Sequence: `log-management-sequence-diagram.md`
- Scripts: `backup_logs.sh`, `uploadSTBLogs.sh`, `UploadLogsNow.sh`, `uploadRRDLogs.sh`, `usbLogUpload.sh`
- Support: `logfiles.sh`, `utils.sh`

---
**End of Use Case Requirements (As-Is)**
