#!/bin/sh
##############################################################################
# Copyright 2020 RDK Management
# Licensed under the Apache License, Version 2.0 (the "License");
##############################################################################

. /etc/device.properties
if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

REBOOT_INFO_LOG_FILE="/opt/logs/rebootInfo.log"
KERNEL_LOG_FILE="/opt/logs/messages.txt"
UIMGR_LOG_FILE="/opt/logs/PreviousLogs/uimgr_log.txt"
OCAPRI_LOG_FILE="/opt/logs/PreviousLogs/ocapri_log.txt"
ECM_CRASH_LOG_FILE="/opt/logs/PreviousLogs/messages-ecm.txt"
PSTORE_CONSOLE_LOG_FILE="/sys/fs/pstore/console-ramoops-0"
KERNEL_PANIC_SEARCH_STRING="PREVIOUS_KERNEL_OOPS_DUMP"
KERNEL_PANIC_SEARCH_STRING_01="Kernel panic - not syncing"
KERNEL_PANIC_SEARCH_STRING_02="Oops - undefined instruction"
KERNEL_PANIC_SEARCH_STRING_03="Oops - bad syscall"
KERNEL_PANIC_SEARCH_STRING_04="branch through zero"
KERNEL_PANIC_SEARCH_STRING_05="unknown data abort code"
KERNEL_PANIC_SEARCH_STRING_06="Illegal memory access"
ECM_CRASH_SEARCH_STRING="\*\*\*\* CRASH \*\*\*\*"
MAX_REBOOT_STRING="Box has rebooted 10 times"
POWERON_STRING="POWER_ON"
REBOOT_INFO_DIR="/opt/secure/reboot"
REBOOT_INFO_FILE="/opt/secure/reboot/reboot.info"
PARODUS_REBOOT_INFO_FILE="/opt/secure/reboot/parodusreboot.info"
KEYPRESS_INFO_FILE="/opt/secure/reboot/keypress.info"
PREVIOUS_REBOOT_INFO_FILE="/opt/secure/reboot/previousreboot.info"
PREVIOUS_PARODUSREBOOT_INFO_FILE="/opt/secure/reboot/previousparodusreboot.info"
PREVIOUS_HARD_REBOOT_INFO_FILE="/opt/secure/reboot/hardpower.info"
PREVIOUS_KEYPRESS_INFO_FILE="/opt/secure/reboot/previouskeypress.info"
STT_FLAG="/tmp/stt_received"
REBOOT_INFO_FLAG="/tmp/rebootInfo_Updated"
UPDATE_REBOOT_INFO_INVOKED_FLAG="/tmp/Update_rebootInfo_invoked"
LOCK_DIR="/tmp/rebootInfo.lock"
PARODUS_LOG="/opt/logs/parodus.log"

rebootLog()
{
    echo "$0: $*"
}

rebootLog "Start of Reboot Reason Script"

APP_TRIGGERED_REASONS=(Servicemanager systemservice_legacy WarehouseReset WarehouseService HrvInitWHReset HrvColdInitReset HtmlDiagnostics InstallTDK StartTDK TR69Agent SystemServices Bsu_GUI SNMP CVT[...]
OPS_TRIGGERED_REASONS=(ScheduledReboot RebootSTB.sh FactoryReset UpgradeReboot_restore XFS wait_for_pci0_ready websocketproxyinit NSC_IR_EventReboot host_interface_dma_bus_wait usbhotplug Receiver_MDV[...]
MAINTENANCE_TRIGGERED_REASONS=(AutoReboot.sh PwrMgr)

setPreviousRebootInfo()
{
    timestamp=$1
    source=$2
    reason=$3
    custom=$4
    other=$5
    if [ ! -z $PREVIOUS_REBOOT_INFO_FILE ]; then
        rebootLog "Reboot reason present in $PREVIOUS_REBOOT_INFO_FILE file:"
        cat $PREVIOUS_REBOOT_INFO_FILE
    fi
    rebootLog "Updating Reboot reason in $PREVIOUS_REBOOT_INFO_FILE file"
    echo "{" > $PREVIOUS_REBOOT_INFO_FILE
    echo "\"timestamp\":\"$timestamp\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"source\":\"$source\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"reason\":\"$reason\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"customReason\":\"$custom\"," >> $PREVIOUS_REBOOT_INFO_FILE
    echo "\"otherReason\":\"$other\"" >> $PREVIOUS_REBOOT_INFO_FILE
    echo "}" >> $PREVIOUS_REBOOT_INFO_FILE

    rebootLog "Updating previous reboot reason in $PARODUS_LOG"
    existing_reboot_info=$(grep "PreviousRebootInfo" "$PARODUS_LOG" 2>/dev/null | tail -1)

    if [ -z "$existing_reboot_info" ]; then
        echo "$(/bin/timestamp): $0: Updating previous reboot info to Parodus" >> "$PARODUS_LOG"
        echo "$(/bin/timestamp): $0: PreviousRebootInfo:$timestamp,$custom,$source,$reason" >> "$PARODUS_LOG"
        rebootLog "Reboot Information Updated to parodus log:$timestamp,$custom,$source,$reason"
    else
        rebootLog "${FUNCNAME[0]}: Reboot info already present in $PARODUS_LOG as $existing_reboot_info, skipping update"
    fi

    if [ "$reason" == "HARD_POWER" ] || [ "$reason" == "POWER_ON_RESET" ] || [ "$reason" == "UNKNOWN_RESET" ] || [ ! -f "$PREVIOUS_HARD_REBOOT_INFO_FILE" ];then
        echo "{" > $PREVIOUS_HARD_REBOOT_INFO_FILE
        echo "\"lastHardPowerReset\":\"$timestamp\"" >> $PREVIOUS_HARD_REBOOT_INFO_FILE
        echo "}" >> $PREVIOUS_HARD_REBOOT_INFO_FILE
        rebootLog "Updated Hard Power Reboot Time stamp"
    fi

    rebootLog "Updated Previous Reboot Reason information"
}

fwFailureCheck()
{
    fw_failure=0
    rebootLog "Checking firmware failure cases (ECM Crash, Max Reboot etc)..."

    if [ "$DEVICE_TYPE" != "mediaclient" ]; then
        if  [ -f "$OCAPRI_LOG_FILE" ] && [[ $(grep "$MAX_REBOOT_STRING" $OCAPRI_LOG_FILE) ]]; then
            fw_failure=1
            rebootInitiatedBy="OcapRI"
            otherReason="Reboot due to STB reached maximum (10) reboots"
            t2CountNotify "SYST_ERR_10Times_reboot"
        fi

        if [ -f "$ECM_CRASH_LOG_FILE" ] && [[ $(grep "$ECM_CRASH_SEARCH_STRING" $ECM_CRASH_LOG_FILE) ]]; then
            fw_failure=1
            rebootInitiatedBy="EcmLogger"
            otherReason="Reboot due to ecm logger crash"
        fi
    else
        if  [ -f "$UIMGR_LOG_FILE" ] && [[ $(grep "$MAX_REBOOT_STRING" $UIMGR_LOG_FILE) ]]; then
            fw_failure=1
            rebootInitiatedBy="UiMgr"
            otherReason="Reboot due to STB reached maximum (10) reboots"
            t2CountNotify "SYST_ERR_10Times_reboot"
        fi
    fi

    return $fw_failure
}

oopsDumpCheck()
{
    oops_dump=0

    if [ "$SOC" = "BRCM" ]; then
        if [ -f "$KERNEL_LOG_FILE" ] && [[ $(grep $KERNEL_PANIC_SEARCH_STRING $KERNEL_LOG_FILE) ]];then
            if [[ $(grep -e "Kernel Oops" -e "Kernel Panic" $KERNEL_LOG_FILE) ]];then
                oops_dump=1
            fi
        fi
    elif [ "$RDK_PROFILE" = "TV" ]; then
        if [ -f "$PSTORE_CONSOLE_LOG_FILE" ]; then
            if [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_01" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            elif [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_02" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            elif [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_03" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            elif [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_04" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            elif [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_05" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            elif [[ $(grep "$KERNEL_PANIC_SEARCH_STRING_06" $PSTORE_CONSOLE_LOG_FILE) ]];then
                oops_dump=1
            else
                oops_dump=0
            fi

            if [ "$oops_dump" -eq "1" ];then
                for pstorefile in /sys/fs/pstore/*
                do
                    filename=$(basename "${pstorefile}")
                    cat $pstorefile > /opt/logs/${filename}.log
                done
                rebootLog "Please check pstore logs(/sys/fs/pstore/*) for more detail about kerenl panic !"
            fi
        fi
    fi

    return $oops_dump
}

setRebootReason()
{
    rebootReason=$1
    case $rebootReason in
        SOFTWARE|SOFTWARE_MASTER_RESET)
            rebootInitiatedBy="SoftwareReboot"
            rebootReason="SOFTWARE_MASTER_RESET"
            t2CountNotify "Test_SWReset"
            otherReason="Reboot due to user triggered reboot command"
            ;;
        WATCHDOG|WATCHDOG_TIMER_RESET)
            rebootInitiatedBy="WatchDog"
            rebootReason="WATCHDOG_TIMER_RESET"
            otherReason="Reboot due to watch dog timer reset"
            ;;
        KERNEL_PANIC_RESET)
            rebootInitiatedBy="Kernel"
            rebootReason="KERNEL_PANIC"
            otherReason="Reboot due to Kernel Panic captured by Oops Dump"
            ;;
        HARDWARE|POWER_ON_RESET)
            rebootInitiatedBy="PowerOn"
            rebootReason="POWER_ON_RESET"
            otherReason="Reboot due to unplug of power cable from the STB"
            ;;
        MAIN_CHIP_INPUT_RESET)
            rebootInitiatedBy="Main Chip"
            rebootReason="MAIN_CHIP_INPUT_RESET"
            otherReason="Reboot due to chip's main reset input has been asserted"
            ;;
        MAIN_CHIP_RESET_INPUT)
            rebootInitiatedBy="Main Chip"
            rebootReason="MAIN_CHIP_RESET_INPUT"
            otherReason="Reboot due to chip's main reset input has been asserted"
            ;;
        TAP_IN_SYSTEM_RESET)
            rebootInitiatedBy="Tap-In System"
            rebootReason="TAP_IN_SYSTEM_RESET"
            otherReason="Reboot due to the chip's TAP in-system reset has been asserted"
            ;;
        FRONT_PANEL_4SEC_RESET)
            rebootInitiatedBy="FrontPanel Button"
            rebootReason="FRONT_PANEL_RESET"
            otherReason="Reboot due to the front panel 4 second reset has been asserted"
            ;;
        S3_WAKEUP_RESET)
            rebootInitiatedBy="Standby Wakeup"
            rebootReason="S3_WAKEUP_RESET"
            otherReason="Reboot due to the chip woke up from deep standby"
            ;;
        SMARTCARD_INSERT_RESET)
            rebootInitiatedBy="SmartCard Insert"
            rebootReason="SMARTCARD_INSERT_RESET"
            otherReason="Reboot due to the smartcard insert reset has occurred"
            ;;
        OVERHEAT|OVERTEMP_RESET)
            rebootInitiatedBy="OverTemperature"
            rebootReason="OVERTEMP_RESET"
            otherReason="Reboot due to chip temperature is above threshold (125*C)"
            ;;
        OVERVOLTAGE_1_RESET|OVERVOLTAGE_RESET)
            rebootInitiatedBy="OverVoltage"
            rebootReason="OVERVOLTAGE_RESET"
            otherReason="Reboot due to chip voltage is above threshold"
            ;;
        PCIE_1_HOT_BOOT_RESET|PCIE_0_HOT_BOOT_RESET)
            rebootInitiatedBy="PCIE Boot"
            rebootReason="PCIE_HOT_BOOT_RESET"
            otherReason="Reboot due to PCIe hot boot reset has occurred"
            ;;
        UNDERVOLTAGE_1_RESET|UNDERVOLTAGE_0_RESET|UNDERVOLTAGE_RESET)
            rebootInitiatedBy="LowVoltage"
            rebootReason="UNDERVOLTAGE_RESET"
            otherReason="Reboot due to chip voltage is below threshold"
            ;;
        SECURITY_MASTER_RESET)
            rebootInitiatedBy="SecutiryReboot"
            rebootReason="SECURITY_MASTER_RESET"
            otherReason="Reboot due to security master reset has occurred"
            ;;
        CPU_EJTAG_RESET)
            rebootInitiatedBy="CPU EJTAG"
            rebootReason="CPU_EJTAG_RESET"
            otherReason="Reboot due to CPU EJTAG reset has occurred"
            ;;
        SCPU_EJTAG_RESET)
            rebootInitiatedBy="SCPU EJTAG"
            rebootReason="SCPU_EJTAG_RESET"
            otherReason="Reboot due to SCPU EJTAG reset has occurred"
            ;;
        GEN_WATCHDOG_1_RESET)
            rebootInitiatedBy="GEN WatchDog"
            rebootReason="GEN_WATCHDOG_RESET"
            otherReason="Reboot due to gen_watchdog_1 timeout reset has occurred"
            ;;
        AUX_CHIP_EDGE_RESET_0|AUX_CHIP_EDGE_RESET_1)
            rebootInitiatedBy="Aux Chip Edge"
            rebootReason="AUX_CHIP_EDGE_RESET"
            otherReason="Reboot due to the auxiliary edge-triggered chip reset has occurred"
            ;;
        AUX_CHIP_LEVEL_RESET_0|AUX_CHIP_LEVEL_RESET_1)
            rebootInitiatedBy="Aux Chip Level"
            rebootReason="AUX_CHIP_LEVEL_RESET"
            otherReason="Reboot due to the auxiliary level-triggered chip reset has occurred"
            ;;
        MPM_RESET)
            rebootInitiatedBy="MPM"
            rebootReason="MPM_RESET"
            otherReason="Reboot due to the MPM reset has occurred"
            ;;
        *)
            rebootInitiatedBy="Hard Power"
            rebootReason="$rebootReason"
            otherReason="Reboot due to $rebootReason"
            ;;
        esac
}

lock()
{
    while ! mkdir "$LOCK_DIR" &> /dev/null;do
        rebootLog "Waiting for rebootInfo lock"
        sleep 5
    done
    rebootLog "Acquired rebootInfo lock"
}

unlock()
{
    rm -rf "$LOCK_DIR"
    rebootLog "Releasing rebootInfo lock"
}

CheckSTT()
{
    rebootLog "Checking ${STT_FLAG} and ${REBOOT_INFO_FLAG} flag to update the reboot reason"
    if [ ! -f "${STT_FLAG}" ] || [ ! -f "${REBOOT_INFO_FLAG}" ];then
        rebootLog "Exiting since ${STT_FLAG} or  ${REBOOT_INFO_FLAG} flag is not available"
        unlock
        rebootLog "End of Reboot Reason Script"
        exit 0
    fi
}

exitforNullrebootreason()
{
    rebootInitiatedBy="Hard Power Reset"
    customReason="Hardware Register - NULL"
    otherReason="No information found"
    rebootReason="HARD_POWER"
    setPreviousRebootInfo "$rebootTime" "$rebootInitiatedBy" "$rebootReason" "$customReason" "$otherReason"
    unlock
    rebootLog "End of Reboot Reason Script"
    exit 0
}

##############################
########## Main APP ##########
##############################

lock

CheckSTT

if [ ! -d $REBOOT_INFO_DIR ]; then
    rebootLog "Creating $REBOOT_INFO_DIR folder..."
    mkdir $REBOOT_INFO_DIR
fi

# --- Remove OEM check for the TV platforms ---
# --- Remove sourcing/usage of OEM files/functions ---

# --- Execute vendor provided script for hardware reboot reason ---
# If vendor hardware reboot reason script exists, run it and capture the reason
VENDOR_HW_REBOOT_REASON_SCRIPT="/lib/rdk/vendor/get-hw-reboot-reason.sh"
if [ -f "$VENDOR_HW_REBOOT_REASON_SCRIPT" ]; then
    rebootLog "Executing vendor script to get hardware reboot reason: $VENDOR_HW_REBOOT_REASON_SCRIPT"
    hw_reboot_reason="$(sh "$VENDOR_HW_REBOOT_REASON_SCRIPT")"
    if [ ! -z "$hw_reboot_reason" ]; then
        rebootLog "Vendor provided hardware reboot reason: $hw_reboot_reason"
        setRebootReason "$hw_reboot_reason"
        rebootTime=`date -u`
        customReason="Vendor HW Reboot"
        setPreviousRebootInfo "$rebootTime" "$rebootInitiatedBy" "$rebootReason" "$customReason" "$otherReason"
        unlock
        rebootLog "End of Reboot Reason Script"
        exit 0
    fi
fi

rebootTimestamp=`date -u`

if [ -f "$REBOOT_INFO_FILE" ];then
    rebootLog "New $REBOOT_INFO_FILE file found, Creating previous reboot info file..."
    cat $REBOOT_INFO_FILE
    mv $REBOOT_INFO_FILE $PREVIOUS_REBOOT_INFO_FILE
    if [ -f "$PARODUS_REBOOT_INFO_FILE" ];then
       rebootLog "New $PARODUS_REBOOT_INFO_FILE file found, updating parodus logfile..."
       rebootinfo=`cat $PARODUS_REBOOT_INFO_FILE`
       echo "`/bin/timestamp` $0: $rebootinfo" >> $PARODUS_LOG
       mv $PARODUS_REBOOT_INFO_FILE $PREVIOUS_PARODUSREBOOT_INFO_FILE
    fi   
else
    rebootLog "$REBOOT_INFO_FILE file not found, Assigning default values..."
    rebootInitiatedBy=""
    rebootTime=""
    customReason=""
    otherReason=""

    if [ -f "$REBOOT_INFO_LOG_FILE" ];then
        rebootLog "$REBOOT_INFO_LOG_FILE logfile found, Fetching source, time and other reasons"
        rebootInitiatedBy=`grep "PreviousRebootInitiatedBy:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F "PreviousRebootInitiatedBy:" '{print $2}' | sed 's/^ *//'`
        rebootTime=`grep "PreviousRebootTime:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F 'PreviousRebootTime:' '{print $2}' | sed 's/^ *//'`
        customReason=`grep "PreviousCustomReason:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F "PreviousCustomReason:" '{print $2}' | sed 's/^ *//'`
        otherReason=`grep "PreviousOtherReason:" $REBOOT_INFO_LOG_FILE | grep -v grep | awk -F 'PreviousOtherReason:' '{print $2}' | sed 's/^ *//'`
    fi

    rebootLog "Validating reboot information received from $REBOOT_INFO_LOG_FILE..."
    if [ "x$rebootInitiatedBy" == "x" ];then
        rebootLog "$REBOOT_INFO_LOG_FILE file not found and Value of rebootInitiatedBy=$rebootInitiatedBy is empty"
        rebootTime="$rebootTimestamp"
        rebootLog "Checking for OOPS DUMP for Kernel Panic..."
        oopsDumpCheck
        kernel_crash=$?
        if [ $kernel_crash -eq 1 ];then
            rebootReason="KERNEL_PANIC"
            rebootInitiatedBy="Kernel"
            customReason="Hardware Register - KERNEL_PANIC"
            otherReason="Reboot due to Kernel Panic captured by Oops Dump"
        else
            rebootLog " Hard Power Reboot info is missing!!!"
            exitforNullrebootreason
        fi
    else
        rebootLog "$REBOOT_INFO_LOG_FILE logfile found and received source of rebootInitiatedBy=$rebootInitiatedBy"
        if [[ "${APP_TRIGGERED_REASONS[@]}" == *"$rebootInitiatedBy"* ]];then
            rebootReason="APP_TRIGGERED"
            if [ $customReason == "MAINTENANCE_REBOOT" ];then
                 rebootReason="MAINTENANCE_REBOOT"
            fi
        elif [[ "${OPS_TRIGGERED_REASONS[@]}" == *"$rebootInitiatedBy"* ]];then
            rebootReason="OPS_TRIGGERED"
        elif [[ "${MAINTENANCE_TRIGGERED_REASONS[@]}" == *"$rebootInitiatedBy"* ]];then
            rebootReason="MAINTENANCE_REBOOT"
        else
            rebootReason="FIRMWARE_FAILURE"
        fi
    fi

    setPreviousRebootInfo "$rebootTime" "$rebootInitiatedBy" "$rebootReason" "$customReason" "$otherReason"
fi

if [ -f "$KEYPRESS_INFO_FILE" ]; then
    cp -f $KEYPRESS_INFO_FILE $PREVIOUS_KEYPRESS_INFO_FILE
    rebootLog "Updated previous keypress info"
else
    rebootLog "Unable to find the $KEYPRESS_INFO_FILE file"
fi

if [ ! -f "$UPDATE_REBOOT_INFO_INVOKED_FLAG" ];then
    touch $UPDATE_REBOOT_INFO_INVOKED_FLAG
fi

rebootLog "End of Reboot Reason Script"
unlock
