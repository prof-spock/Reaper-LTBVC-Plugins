-- SoXEffectNamesAdjuster -- functional module to change descriptions
--                           of SoX effects in effects lists
--
--
-- by Dr. TT, 2023

-- =======
-- IMPORTS
-- =======

require("Logging")
require("Map")
require("OperatingSystem")
require("Reaper")
require("Set")
require("String")

-- =======================

local _freqBWString = "'Frequency [Hz]', 'Bandwidth', 'Bandwidth Unit'"
local _fNameToPList =
    ("{"
     .. " 'allpass' :"
     .. " [ " .. _freqBWString .. " ],"
     .. " 'band' :"
     .. " [ 'Unpitched Mode?', " .. _freqBWString .. " ],"
     .. " 'bandpass' :"
     .. " [ 'Cst. Skirt Gain?', " .. _freqBWString .. " ],"
     .. " 'bandreject' :"
     .. " [ "  .. _freqBWString .. " ],"
     .. " 'bass' :"
     .. " [ 'Gain [dB]', " .. _freqBWString .. " ],"
     .. " 'biquad' :"
     .. " [ 'b0', 'b1', 'b2', 'a0', 'a1', 'a2' ],"
     .. " 'equalizer' :"
     .. " [ " .. _freqBWString .. ", 'Eq. Gain [dB]' ],"
     .. " 'highpass' :"
     .. " [ 'Number of Poles', " .. _freqBWString .. "],"
     .. " 'lowpass' :"
     .. " [ 'Number of Poles', " .. _freqBWString .. "],"
     .. " 'treble' :"
     .. " [ 'Gain [dB]', " .. _freqBWString .. " ]"
     .. "}")

-- list of default values for filter effects
local _fNameToDVList =
    ("{"
     .. " 'allpass' : [ ],"
     .. " 'band' : [ 'No' ],"
     .. " 'bandpass' : [ 'No' ],"
     .. " 'bandreject' : [ ],"
     .. " 'bass' : [ 'X', '300' ],"
     .. " 'biquad' : [ ],"
     .. " 'equalizer' : [ ],"
     .. " 'highpass' : [ '2', 'X' ],"
     .. " 'lowpass' : [ '2', 'X' ],"
     .. " 'treble' : [ 'X', '3000' ]"
     .. "}")


-- mapping from bandwidth unit to suffix for SoX
_bandwidthUnitToSuffixMap =
    String.deserialize("{"
                       .. " 'Frequency' : 'h',"
                       .. " 'Octave(s)' : 'o',"
                       .. " 'Quality'   : 'q',"
                       .. " 'Slope'     : 's'"
                       .. "}")

-- mapping from filter effect name to parameter name list
local _filterNameToParameterListMap = String.deserialize(_fNameToPList)

-- mapping from filter effect name to list of default values
local _filterNameToDefaultValueListMap =
    String.deserialize(_fNameToDVList)

-- mapping from filter effect name to position of bandwidth parameter
-- in parameter value list
local _filterNameToBWPositionMap =
    String.deserialize("{"
                       .. " 'allpass'    : 2,"
                       .. " 'band'       : 3,"
                       .. " 'bandpass'   : 3,"
                       .. " 'bandreject' : 2,"
                       .. " 'bass'       : 3,"
                       .. " 'biquad'     : 0,"
                       .. " 'equalizer'  : 2,"
                       .. " 'highpass'   : 3,"
                       .. " 'lowpass'    : 3,"
                       .. " 'treble'     : 3"
                       .. "}")
    
-- ==========================
-- PRIVATE FEATURES
-- ==========================

function _adaptedBandwidth (bandwidth, bandwidthUnit)
    -- Returns SoX format of <bandwidth> and <bandwidthUnit>

    Logging.trace(">>: %s/%s", bandwidth, bandwidthUnit)

    local result
    local suffix
    
    if bandwidthUnit == "Butterworth" then
        bandwidth = "0.7071068"
        suffix = "q"
    elseif bandwidthUnit == "Frequency" then
        bandwidth = _adaptedFrequency(bandwidth)
        suffix = iif(String.hasSuffix(bandwidth, "k"), "", "h")
    else
        suffix = _bandwidthUnitToSuffixMap:at(bandwidthUnit)
    end

    result = bandwidth .. suffix

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _adaptedFrequency (st)
    -- Returns frequency <st> with possible "k" extension

    Logging.trace(">>: %s", st)
    st = String.trim(st)
    local result = st

    if not String.find(st, ".") then
        local formatString =
            iif(String.hasSuffix(st, "000"), "%2.0fk",
                iif(String.hasSuffix(st, "00"), "%3.1fk", "%5.0f"))
        local divisor = iif(String.hasSuffix(st, "00"), 1000, 1)
        result = String.lTrim(String.format(formatString,
                                            tonumber(st) / divisor))

        if String.length(st) <= String.length(result) then
            -- only use modified form when it is shorter, otherwise
            -- use original string
            result = st
        end
    end
    
    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _adjustEffectsInSingleTrack (track)
    -- Adjusts all effects in <track> and returns text representation

    Logging.trace(">>: %s", track)

    local effectList = track:effectList()
    local result = ""

    for _, effect in effectList:iterator() do
        local effectName = effect:name()
        local effectKind = _simpleEffectKind(effect:kind())
        Logging.trace("--: scanning effect %s (%s)",
                      effectName, effectKind)

        if effect:isEnabled() then
            local effectResult = _adjustSingleEffect(effect)

            if effectResult > "" then
                result = String.format("%s%s    %s",
                                       result,
                                       iif(result == "", "", "\n"),
                                       effectResult)
            end
        end
    end

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _adjustSingleEffect (effect)
    -- Adjusts <effect> and returns text representation

    Logging.trace(">>: %s", effect)

    local effectParameterToStringProc =
        function (effectParameter)
            return (effectParameter:name()
                    .. "->" .. effectParameter:value())
        end

    local effectName = effect:name()
    local effectKind = _simpleEffectKind(effect:kind())
    local effectParameterString = ""

    if String.hasPrefix(effectKind, "SoX") then
        Logging.trace("--: effect is from SoX suite")
        local activePreset = effect:activePreset()

        -- if activePreset ~= "" then
        if false then
            effectParameterString = "PRE: " .. activePreset
        elseif effectKind == "SoXCompander" then
            effectParameterString =
                _effectParameterStringForCmpdEffect(effect)
        elseif effectKind == "SoXFilter" then
            effectParameterString =
                _effectParameterStringForFltrEffect(effect)
        elseif effectKind == "SoXGain" then
            effectParameterString =
                _effectParameterStringForGainEffect(effect)
        elseif effectKind == "SoXOverdrive" then
            effectParameterString =
                _effectParameterStringForOdrvEffect(effect)
        elseif effectKind == "SoXPhaserAndTremolo" then
            effectParameterString =
                _effectParameterStringForPhtrEffect(effect)
        elseif effectKind == "SoXReverb" then
            effectParameterString =
                _effectParameterStringForRvrbEffect(effect)
        end

        effect:setName("SoX " .. effectParameterString)
    end

    local result = effectParameterString

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _cmpdEffectStringFromValues (valueList, isMultibandCompander,
                                      bandCount, effectiveParameterCount)
    -- Returns compander effect string combined from values in
    -- <valueList> and the fact whether this is a multiband compander
    -- given by <isMultibandCompander>; <effectiveParameterCount> is a
    -- function from band index to number of consumed parameters in
    -- <valueList>

    Logging.trace(">>: valueList = %s, isMBCompander = %s,"
                  .. " bandCount = %s",
                  valueList, isMultibandCompander, bandCount)

    local result = iif(isMultibandCompander, "m", "") .. "compand"
    local firstIndex = 1

    for bandIndex = 1, bandCount do
        local attack, decay, knee, threshold, ratio, gain, frequency
        local isLastBand = (bandIndex == bandCount)
        local lastIndex =
            firstIndex + effectiveParameterCount(bandIndex) - 1
        local bandValueList = valueList:slice(firstIndex, lastIndex)
        firstIndex = lastIndex + 1

        if isLastBand then
            attack, decay, knee, threshold, ratio, gain =
                bandValueList:unpack()
        else
            attack, decay, knee, threshold, ratio, gain, frequency =
                bandValueList:unpack()
        end

        local fThreshold = tonumber(threshold)
        ratio = tonumber(ratio)
        local dBValueAtZero =
            _normalizeValue(String.format("%5.3f",
                                          fThreshold - fThreshold / ratio))

        local formatString =
            String.format(iif(isMultibandCompander, " \"%s\"", " %s"),
                          "%s,%s %s:%s,0,%s %s")
        local bandResult =
            String.format(formatString,
                          attack, decay, knee, threshold,
                          dBValueAtZero, gain)

        if not isLastBand then
            bandResult = bandResult .. " " .. frequency
        end

        result = result .. bandResult
    end

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _effectParameterValue (effect, effectParameterName,
                                defaultValue)
    -- Returns value associated with parameter in <effect> named
    -- <effectParameterName>; if not available, <defaultValue> is
    -- returned

    Logging.trace(">>: effect = %s, parameterName = %s, default = %s",
                  effect, effectParameterName, defaultValue)

    local effectParameter =
        effect:parameterByName(effectParameterName)
    local result

    if effectParameter ~= nil then
        result = effectParameter:value()
    else
        result = defaultValue
    end

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _effectParameterStringForCmpdEffect (effect)
    -- Returns parameter string for a SoX compander effect

    Logging.trace(">>: %s", effect)

    local result = ""
    local bandCountAsString =
        _effectParameterValue(effect, "-2#Band Count", "")

    if bandCountAsString == "" then
        result = "mcompand ???"
    else
        local bandCount = tonumber(bandCountAsString)
        local isMultibandCompander = (bandCount > 1)
        local bandParameterNameList =
            String.deserialize("[ 'Attack [s]', 'Decay [s]',"
                               .. " 'Knee [dB]', 'Threshold [dB]',"
                               .. " 'Ratio', 'Gain [dB]',"
                               .. " 'Top Frequency [Hz]' ]")
        local bandParameterNameCount = bandParameterNameList:count()
        local effectParameterNameList = List:make()

        local effectiveParameterCount =
            function (bandIndex)
                return (bandParameterNameCount
                        + iif(bandIndex == bandCount, -1, 0))
            end

        -- construct the parameter name list for this compander
        for bandIndex = 1, bandCount do
            local prefix = String.format("%d#", bandIndex)

            for effectParameterIndex = 1,
                effectiveParameterCount(bandIndex) do
                local bandParameterName =
                    prefix .. bandParameterNameList:at(effectParameterIndex)
                effectParameterNameList:append(bandParameterName)
            end
        end

        Logging.trace("--: effectParameterNameList = %s",
                      effectParameterNameList)

        local defaultValueList = List:make()
        local valueList = _effectParameterValueList(effect,
                                                    effectParameterNameList,
                                                    defaultValueList)
        result =
            _cmpdEffectStringFromValues(valueList, isMultibandCompander,
                                        bandCount, effectiveParameterCount)
    end

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _effectParameterStringForFltrEffect (effect)
    -- Returns parameter string for a SoX filter effect

    Logging.trace(">>: %s", effect)

    local result = ""
    local filterKind =
        String.toLowercase(_effectParameterValue(effect,
                                                 "Filter Kind", ""))

    if filterKind == "" then
        result = "filter ???"
    else
        local isHighOrLowpass = (filterKind == "highpass"
                                 or filterKind == "lowpass")
        local effectParameterNameList =
            _filterNameToParameterListMap:at(filterKind)
        local defaultValueList =
            _filterNameToDefaultValueListMap:at(filterKind)
            
        local valueList = _effectParameterValueList(effect,
                                                    effectParameterNameList,
                                                    defaultValueList)

        local adaptValue =
            function (i, newValue)
                valueList:set(i, newValue)
            end

        local prependValue =
            function (i, prefix)
                valueList:set(i, prefix .. valueList:at(i))
            end

        local bandwidthPosition =
            _filterNameToBWPositionMap:at(filterKind)

        if filterKind ~= "biquad" then
            local frequencyPosition = bandwidthPosition - 1
            local bandwidth     = valueList:at(bandwidthPosition)
            local bandwidthUnit = valueList:at(bandwidthPosition + 1)
            local frequency     = valueList:at(frequencyPosition)
            adaptValue(frequencyPosition, _adaptedFrequency(frequency))
            valueList:remove(bandwidthPosition)
            adaptValue(bandwidthPosition,
                       _adaptedBandwidth(bandwidth, bandwidthUnit))

            if isHighOrLowpass and bandwidthUnit == "Butterworth" then
                valueList:remove(bandwidthPosition)
            end
        end

        if filterKind == "band" then
            -- handle parameter "Unpitched Mode"
            if valueList:at(1) == "Yes" then
                adaptValue(1, "-n")
            else
                valueList:remove(1)
            end
        end

        if filterKind == "bandpass" then
            -- handle parameter "Cst. Skirt Gain"
            if valueList:at(1) == "Yes" then
                adaptValue(1, "-c")
            else
                valueList:remove(1)
            end
        end

        if isHighOrLowpass then
            if valueList:at(1) == "1" then
                -- a one-pole filter must not have a bandwidth
                -- information
                valueList:remove(bandwidthPosition)
            end
                
            prependValue(1, "-")
        end

        result = String.format("%s %s",
                               filterKind, String.join(valueList, " "))
    end

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _effectParameterStringForGainEffect (effect)
    -- Returns parameter string for a SoX gain effect

    Logging.trace(">>: %s", effect)

    local effectParameterNameList = String.deserialize("[ 'Gain [dB]' ]")
    local defaultValueList = List:make()
    local valueList = _effectParameterValueList(effect,
                                                effectParameterNameList,
                                                defaultValueList)

    local result = String.format("gain %s",
                                 String.join(valueList, " "))

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _effectParameterStringForOdrvEffect (effect)
    -- Returns parameter string for a SoX overdrive effect

    Logging.trace(">>: %s", effect)

    local effectParameterNameList =
        String.deserialize("[ 'Gain [dB]', 'Colour' ]")
    local defaultValueList =
        String.deserialize("[ '20' , '20' ]")
    local valueList = _effectParameterValueList(effect,
                                                effectParameterNameList,
                                                defaultValueList)

    local result = String.format("overdrive %s",
                                 String.join(valueList, " "))

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _effectParameterStringForPhtrEffect (effect)
    -- Returns parameter string for a SoX phaser and tremolo effect

    Logging.trace(">>: %s", effect)

    local effectParameter = effect:parameterByName("Effect Kind")
    local result = ""

    if effectParameter ~= nil then
        local effectKind = effectParameter:value()
        local effectParameterNameList
        local defaultValueList

        if effectKind == "Tremolo" then
            effectParameterNameList =
                String.deserialize("[ 'Modulation [Hz]', 'Depth [%]' ]")
            defaultValueList =
                String.deserialize("[ 'X' , '40' ]")
        else
            effectParameterNameList =
                String.deserialize("[ 'In Gain', 'Out Gain',"
                                   .. " 'Delay [ms]', 'Decay',"
                                   .. " 'Modulation [Hz]',"
                                   .. " 'Waveform' ]")
            defaultValueList = List:make()
        end

        local valueList = _effectParameterValueList(effect,
                                                    effectParameterNameList,
                                                    defaultValueList)

        if effectKind == "Phaser" then
            local waveFormKind = valueList:at(6)
            valueList:set(6,
                          iif(waveFormKind == "Triangle", "-t", "-s"))
        end
        
        result = String.format("%s %s",
                               String.toLowercase(effectKind),
                               String.join(valueList, " "))
    end

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _effectParameterStringForRvrbEffect (effect)
    -- Returns parameter string for a SoX reverb effect

    Logging.trace(">>: %s", effect)

    local effectParameterNameList =
        String.deserialize("[ 'Is Wet Only?', 'Reverberance [%]',"
                           .. "'HF Damping [%]', 'Room Scale [%]',"
                           .. "'Stereo Depth [%]', 'Predelay [ms]',"
                           .. "'Wet Gain [dB]' ]")
    local defaultValueList =
        String.deserialize("[ 'No', 'X',"
                           .. "'50.000', '100.000',"
                           .. "'100.000', '0.000',"
                           .. "'0.000' ]")
    local valueList = _effectParameterValueList(effect,
                                                effectParameterNameList,
                                                defaultValueList)

    -- correct the wet only parameter
    if valueList:at(1) == "No" then
        valueList:remove(1)
    else
        valueList:set(1, "-w")
    end
    
    local result = String.format("reverb %s",
                                 String.join(valueList, " "))

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _effectParameterValueList (effect,
                                    effectParameterNameList,
                                    defaultValueList)
    -- Returns parameter string for <effect> with parameter names
    -- given by <effectParameterNameList> and their default values by
    -- <defaultValueList>

    Logging.trace(">>: effect = %s, parameterNames = %s, defaults = %s",
                  effect, effectParameterNameList, defaultValueList)

    local effectParameterCount = effectParameterNameList:count()
    local defaultValueCount    = defaultValueList:count()

    while defaultValueCount < effectParameterCount do
        defaultValueCount = defaultValueCount + 1
        defaultValueList:append("X")
    end

    local tempList = List:make()
    local atDefaultValue = true

    for i = effectParameterCount, 1, -1 do
        local defaultValue        = defaultValueList:at(i)
        local effectParameterName = effectParameterNameList:at(i)
        local effectParameterValue =
            _effectParameterValue(effect, effectParameterName,
                                  defaultValue)
        atDefaultValue = (atDefaultValue
                          and (effectParameterValue == defaultValue))

        if not atDefaultValue then
            tempList:append(effectParameterValue)
        end
    end

    local result = List:make()

    for _, value in tempList:reversedIterator() do
        value = _normalizeValue(value)
        result:append(value)
    end

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _normalizeValue (value)
    -- Analyses string <value> and removes trailing zeroes after
    -- a decimal point

    Logging.trace(">>: %s", value)

    local result
    local pattern = "^(%-?%d+%.%d+)$"
    local captureList = String.captureList(value, pattern)

    if captureList == nil then
        result = value
    else
        -- this is a real number
        local i = String.length(value)

        while i > 0 do
            local ch = String.at(value, i)

            if ch ~= "0" and ch ~= "." then
                break
            else
                i = i - 1

                if ch == "." then
                    break
                end
            end
        end
        
        result = String.slice(value, 1, i)
    end
    
    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _simpleEffectKind (extendedKind)
    -- returns the simple effect kind from the extended kind given by
    -- the system

    Logging.trace(">>: %s", extendedKind)

    local result = ""
    local isRelevant = String.find(extendedKind, "SoX")
    
    if isRelevant then
        -- parse the string for the effect kind
        local pattern = "SoX +(%a+)"
        local captureList = String.captureList(extendedKind, pattern)

        if captureList ~= nil then
            result = "SoX" .. captureList:at(1)
        end
    end

    Logging.trace("<<: '%s'", result)
    return result
end

-- --------------------
-- --------------------

function SoXEffectNamesAdjuster_normalize (trackList)
    -- adjusts all effects in <trackList> and returns text
    -- representation

    Logging.trace(">>: %s", trackList)

    local result = ""

    for _, track in trackList:iterator() do
        local trackName = track:name()
        Logging.trace("--: scanning track %s", trackName)
        local effectsString =
            _adjustEffectsInSingleTrack(track)

        if effectsString > "" then
            result = String.format("%s%s%s%s%s",
                                   result,
                                   iif(result == "", "", "\n"),
                                   trackName,
                                   iif(effectsString == "", "", "\n"),
                                   effectsString)
        end
    end

    Logging.trace("<<: %s", result)
    return result
end
