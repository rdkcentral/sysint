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


# Get the RFC..  If RFC is not enabled, set both samplingInterval and Logging Interval to 900s as same as existing code.
if [ ! -f /lib/rdk/isFeatureEnabled.sh ]; then
    echo "No logic to verify the Feature is enabled or not. Assuming RFC_ENABLE_WIFI_TM_DC is false"
    exit
fi

if [ -f /lib/rdk/t2Shared_api.sh ]; then
    source /lib/rdk/t2Shared_api.sh
fi

. /lib/rdk/isFeatureEnabled.sh WIFI_TM_DC

if [ "$RFC_ENABLE_WIFI_TM_DC" == "true" ] || [ "$RFC_ENABLE_WIFI_TM_DC" == "1" ] ; then
    samplingInterval=$RFC_DATA_WIFI_TM_DC_SAMPLE_INT
    loggingInterval=$RFC_DATA_WIFI_TM_DC_LOG_INT
else
    echo "RFC_ENABLE_WIFI_TM_DC is false"
    exit
fi


# Since we arrive here only when logging enabled, Set isWifiRFCEnabled to 1; :)
isWifiRFCEnabled=1

iterationCnt=`expr $loggingInterval / $samplingInterval`
echo "Total possible iterations are $iterationCnt"

testValidity=`expr $iterationCnt \\* $samplingInterval`
if [ "$testValidity" != "$loggingInterval" ]; then
    echo "Given Logging_Interval($loggingInterval) is not divisable by the Sampling_Interval($samplingInterval). So we modified the Logging_Interval as $testValidity"
fi

wifiDataHeader=(tx inbss obss nocat txop glitch badplcp idle)
wifiDataValues=(0  0     0    0     0    0      0       0)
wifiDataArrayLen=`echo ${#wifiDataHeader[@]}`
wifiTemperature=0
wifiCounterHeader=(rxcrsglitch rxbadfcs rxbadplcp txctsfrm txframe txmpdu txampdu rxrsptmout txretrans txchit txucast txrtsfrm txinrtstxop txper_ucastdt rxackucast rxback)
wifiCounterValues=(0           0        0         0        0       0      0       0          0         0      0       0        0           0             0          0)
wifiCounterlength=${#wifiCounterHeader[@]}

wifiTelemetryCacheFile="/tmp/.wifi-telemetry-data.cache"
iterationIndex=0

collectWifiData()
{
    count=1
    index=0
    parameters=`wl chanim_stats | sed -n 2p`
    extractedData=`wl chanim_stats | sed -n 3p`
    if [ "$parameters" != "" ] && [ "$extractedData" != "" ]; then

        key=`echo $parameters | cut -d ' ' -f$count`
        value=`echo $extractedData | cut -d ' ' -f$count`

        while [ "$key" != "" ]
        do
            if [[ "${wifiDataHeader[*]}" == *"$key"* ]]; then
                temp=${wifiDataValues[index]}
                wifiDataValues[index]=`expr $temp + $value`
                index=`expr $index + 1`
            fi

            count=`expr $count + 1`
            key=`echo $parameters | cut -d ' ' -f$count`
            value=`echo $extractedData | cut -d ' ' -f$count`
        done
    fi
}

collectTemperatureData()
{
    temp=$wifiTemperature
    currTemp=`wl phy_tempsense | cut -d ' ' -f1`
    wifiTemperature=`expr $temp + $currTemp`
}

collectWifiCounterData()
{
    value=`wl counters`
    for ((j=0; j < $wifiCounterlength; j++)); do
        key=${wifiCounterHeader[$j]}
        temp=`echo $value | sed "/\<${key}\>/s/.*\<${key}\> \([^ ][^ ]*\)*.*/\1/" | sed "s/[^0-9]//g"`

        backup=${wifiCounterValues[j]}
        wifiCounterValues[j]=`expr $temp + $backup`
    done
}

doCollectData()
{
    collectWifiData
    collectTemperatureData
    collectWifiCounterData
}

findAvgOfWifiCounterData()
{
    for ((i=0; i < wifiCounterlength; i++)); do
        temp=${wifiCounterValues[i]}
        # This is % value but for calculation, we made it to numbers
        if [ "${wifiCounterHeader[i]}" == "txper_ucastdt" ]; then
            wifiCounterValues[i]=`echo $temp $iterationCnt | awk '{ printf "%.1f%%", ($1 / $2)}'`
        else
            wifiCounterValues[i]=`expr $temp / $iterationCnt`
        fi
    done
}

findAverage()
{
    #WifiData Details
    for ((i=0; i < wifiDataArrayLen; i++)); do
        temp=${wifiDataValues[i]}
        wifiDataValues[i]=`expr $temp / $iterationCnt`
    done

    #Temperature Details
    temp=$wifiTemperature
    wifiTemperature=`expr $temp / $iterationCnt`

    #Wifi Counter Details
    findAvgOfWifiCounterData
}

doWifiCaching()
{
    value="WIFI_TM_DC: \"wl chanim_stats\": "
    for ((i=0; i < wifiDataArrayLen; i++)); do
        temp1=`echo "${wifiDataHeader[i]} = ${wifiDataValues[i]}"`
        temp2=`echo $value $temp1`
        value=$temp2
    done
    echo $value >>$wifiTelemetryCacheFile
}

doTemperatureCaching()
{
    echo "WIFI_TM_DC: \"wl phy_tempsense\": $wifiTemperature" >>$wifiTelemetryCacheFile
}

doWifiCounterCaching()
{
    value="WIFI_TM_DC: \"wl counters\": "
    for ((i=0; i < $wifiCounterlength; i++)); do
        # This is % value but for calculation, we made it to numbers
        if [ "${wifiCounterHeader[i]}" == "txper_ucastdt" ]; then
            temp=${wifiCounterValues[i]}
            wifiCounterValues[i]=`echo $temp | awk '{ printf "%.1f%%", $1 / 10 }'`
            temp=`echo "$value ${wifiCounterHeader[i]} = ${wifiCounterValues[i]}"`
        else
            temp=`echo "$value ${wifiCounterHeader[i]} = ${wifiCounterValues[i]}"`
        fi
        value=$temp
    done
    echo $value >>$wifiTelemetryCacheFile
}


doLogging()
{
    echo "temperature:$wifiTemperature"
    t2ValNotify "Board_temperature_split" "$wifiTemperature"
    # Wifi Data Logging
    for ((i=0; i < wifiDataArrayLen; i++)); do
        echo "${wifiDataHeader[i]}:${wifiDataValues[i]}"
    done

    # Wifi Counter Logging
    headersValue=${wifiCounterHeader[0]}
    dataValue=${wifiCounterValues[0]}
    for ((i=1; i < $wifiCounterlength; i++)); do
        tempH=`echo "$headersValue,${wifiCounterHeader[i]}"`

        # This is % value but for calculation, we made it to numbers
        if [ "${wifiCounterHeader[i]}" == "txper_ucastdt" ]; then
            tempD=${wifiCounterValues[i]}
            wifiCounterValues[i]=`echo $tempD | awk '{ printf "%.1f%%", $1 / 10 }'`
            tempD=`echo "$dataValue,${wifiCounterValues[i]}"`
        else
            tempD=`echo "$dataValue,${wifiCounterValues[i]}"`
        fi
        headersValue=$tempH
        dataValue=$tempD
    done
    echo "wlCounterHeader:$headersValue"
    echo "wlCounterValues:$dataValue"
}

loadFromCache()
{
    iterationIndex=`cat $wifiTelemetryCacheFile | grep iterationIndex | awk '{print $3}'`
    baseValue=6
    for ((i=0; i < wifiDataArrayLen; i++)); do
        x=`expr $i \* 3`
        y=`expr $x + $baseValue`
        wifiDataValues[i]=`cat $wifiTelemetryCacheFile | grep chanim_stats | cut -d ' ' -f$y`
    done
    for ((i=0; i < wifiCounterlength; i++)); do
        x=`expr $i \* 3`
        y=`expr $x + $baseValue`

        if [ "${wifiCounterHeader[i]}" == "txper_ucastdt" ]; then
            wifiCounterValues[i]=`cat $wifiTelemetryCacheFile | grep "wl counters" | cut -d ' ' -f$y | sed "s/[^0-9]//g"`
        else
            wifiCounterValues[i]=`cat $wifiTelemetryCacheFile | grep "wl counters" | cut -d ' ' -f$y`
        fi
    done
    wifiTemperature=`cat $wifiTelemetryCacheFile | grep "wl phy_tempsense" | cut -d ' ' -f4`
}

writeToCache()
{
    echo "iterationIndex = $iterationIndex" >$wifiTelemetryCacheFile
    doWifiCaching
    doTemperatureCaching
    doWifiCounterCaching
}

if [ -f $wifiTelemetryCacheFile ]; then
    loadFromCache
fi

iterationIndex=`expr $iterationIndex + 1`
echo "Current iterationIndex = $iterationIndex"

# Start the collection n looping
doCollectData

if [ "$iterationIndex" == "$iterationCnt" ]; then
    findAverage
    doLogging
    rm -f $wifiTelemetryCacheFile
else
    writeToCache
fi

# End of Script
