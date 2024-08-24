-- LTBVCConfiguration -- provides services for reading an LTBVC
--                       configuration file
--
-- author: Dr. Thomas Tensi, 2024

-- =======
-- IMPORTS
-- =======

require("ConfigurationFile")
require("Logging")
require("Map")
require("Set")
require("String")

-- =======================

LTBVCConfiguration = {}

-- ==========================
-- DEFAULTS FOR CONFIGURATION
-- ==========================

-- ------------------------
-- COLORS (in BGR notation)
-- ------------------------

local _COL_red         = 0x0000FF
local _COL_lightRed    = 0x8080FF
local _COL_green       = 0x00FF00
local _COL_lightGreen  = 0x80FF80
local _COL_blue        = 0xFF0000
local _COL_lightBlue   = 0xFF8080
local _COL_yellow      = 0x00FFFF
local _COL_lightYellow = 0x80FFFF
local _COL_cyan        = 0xFFFF00
local _COL_lightCyan   = 0xFFFF80
local _COL_magenta     = 0xFF00FF

-- --------------------
-- LAYOUTS
-- --------------------
    
local _LAY_standardTrack       = "ga - Standard (TT)"
local _LAY_groupTrackWithFX    = "gb - Grouping with FX (TT)"
local _LAY_groupTrackWithoutFX = "gc - Grouping without FX (TT)"
local _LAY_midiTrack           = "gd - MIDI (TT)"
local _LAY_audioTrack          = "ge - ExternalAudio (TT)"
local _LAY_effectBusTrack      = "gf - Effect Bus (TT)"
local _LAY_mixerBusTrack       = "gg - Mixer Bus (TT)"

-- =========================
-- module LTBVCConfiguration
-- =========================
    -- This module provides services for reading an LTBVC
    -- configuration file

    -- --------------------
    -- local features
    -- --------------------

    -- the maximum idle duration in seconds for the selection dialog
    -- after which it automatically closes; zero means "no autoclose"
    LTBVCConfiguration._selectionDialogIdleDuration = nil
    
    -- mapping from track name pattern to color and layout name
    LTBVCConfiguration._trackNamePatternToColorAndLayoutMap = nil

    -- list of track name patterns where parent channel connection is
    -- disabled
    LTBVCConfiguration._trackNamePatternWithParentDisabledList = nil

    -- mapping from track name pattern to a tuple of connection partner,
    -- send mode and phase inversion settings
    LTBVCConfiguration._trackNamePatternToConnectionDataMap = nil

    -- list of track name patterns and associated headers in order for
    -- the audio source selection dialog
    LTBVCConfiguration._trackNamePatternAndHeaderList = nil

    -- track name pattern for the effects voice track
    LTBVCConfiguration._trackNamePatternForVoiceEffects = nil

    -- track name pattern for the final voice track
    LTBVCConfiguration._trackNamePatternForVoiceFinal = nil

    -- the set of track name patterns fed into the effects voice track
    LTBVCConfiguration._trackNamePatternTNPSentToEffectsSet = nil

    -- --------------------
    -- auxiliary variables
    -- --------------------

    local _PREFIX_voiceEffects = "^E%s+"
    local _PREFIX_voiceFinal   = "^F%s+"

    local _TRK_bus_effect           = "^EFFECTS"
    local _TRK_bus_final            = "^FINAL MIX"
    local _TRK_bus_generatedMIDI    = "^GEN. MIDI"
    local _TRK_bus_original         = "^ORIGINAL"
    local _TRK_bus_rawAudio         = "^RAW AUDIO"
    local _TRK_bus_refinedAudio     = "^REFINED AUDIO"
    local _TRK_bus_structuredMIDI   = "^STRUCTURED"
    local _TRK_mix_result           = "^RESULT"
    local _TRK_voice_effects        = _PREFIX_voiceEffects .. "(%S.*)"
    local _TRK_voice_final          = _PREFIX_voiceFinal  .. "(%S.*)"
    local _TRK_voice_generatedMIDI  = "^M%s+(%S.*)"
    local _TRK_voice_original       = "^O%s+(%S.*)"
    local _TRK_voice_rawAudio       = "^RA%s+(%S.*)"
    local _TRK_voice_refinedAudio   = "^RF%s+(%S.*)"
    local _TRK_voice_structuredMIDI = "^S%s+(%S.*)"

    -- --------------------

    -- default value strings for the different configuration variables

    function _tnpCLLine (pattern, color, layout, suffix)
        return String.format(" %s: [%d, '%s']%s",
                             pattern, color, layout, suffix)
    end

    --

    local _defaultTCToTNPString =
        "{"
        .. "'effects' : " .. _TRK_voice_effects .. ","
        .. "}"

    --

    local _defaultTNPAndHeaderList = "["
        .. " ['" .. _TRK_voice_original       .. "', " .. "'O'  ],"
        .. " ['" .. _TRK_voice_structuredMIDI .. "', " .. "'S'  ],"
        .. " ['" .. _TRK_voice_generatedMIDI  .. "', " .. "'M'  ],"
        .. " ['" .. _TRK_voice_rawAudio       .. "', " .. "'RA' ],"
        .. " ['" .. _TRK_voice_effects        .. "', " .. "'E'  ],"
        .. " ['" .. _TRK_voice_refinedAudio   .. "', " .. "'RF' ]"
        .. "]"

    --

    local _defaultTNPToColorString =
        "{"
        .. _tnpCLLine(_TRK_bus_effect, _COL_blue, _LAY_groupTrackWithoutFX, ",")
        .. _tnpCLLine(_TRK_bus_final, _COL_cyan, _LAY_groupTrackWithFX, ",")
        .. _tnpCLLine(_TRK_bus_generatedMIDI, _COL_green, _LAY_groupTrackWithoutFX, ",")
        .. _tnpCLLine(_TRK_bus_original, _COL_red, _LAY_groupTrackWithFX, ",")
        .. _tnpCLLine(_TRK_bus_rawAudio, _COL_yellow, _LAY_groupTrackWithoutFX, ",")
        .. _tnpCLLine(_TRK_bus_refinedAudio, _COL_yellow, _LAY_groupTrackWithoutFX, ",")
        .. _tnpCLLine(_TRK_bus_structuredMIDI, _COL_green, _LAY_groupTrackWithoutFX, ",")
        .. _tnpCLLine(_TRK_mix_result, _COL_magenta, _LAY_standardTrack, ",")
        .. _tnpCLLine(_TRK_voice_effects, _COL_lightBlue, _LAY_effectBusTrack, ",")
        .. _tnpCLLine(_TRK_voice_final, _COL_lightCyan, _LAY_mixerBusTrack, ",")
        .. _tnpCLLine(_TRK_voice_generatedMIDI, _COL_lightGreen, _LAY_midiTrack, ",")
        .. _tnpCLLine(_TRK_voice_original, _COL_lightRed, _LAY_standardTrack, ",")
        .. _tnpCLLine(_TRK_voice_rawAudio, _COL_lightYellow, _LAY_audioTrack, ",")
        .. _tnpCLLine(_TRK_voice_refinedAudio, _COL_lightYellow, _LAY_audioTrack, ",")
        .. _tnpCLLine(_TRK_voice_structuredMIDI, _COL_lightGreen, _LAY_midiTrac, " ")
        .. "}"

    --

    local _defaultTNPWithNoParentsString = "["
        .. "'" .. _TRK_bus_effect           .. "',"
        .. "'" .. _TRK_bus_generatedMIDI    .. "',"
        .. "'" .. _TRK_bus_original         .. "',"
        .. "'" .. _TRK_bus_rawAudio         .. "',"
        .. "'" .. _TRK_bus_refinedAudio     .. "',"
        .. "'" .. _TRK_bus_structuredMIDI   .. "',"
        .. "'" .. _TRK_voice_effects        .. "',"
        .. "'" .. _TRK_voice_generatedMIDI  .. "',"
        .. "'" .. _TRK_voice_original       .. "',"
        .. "'" .. _TRK_voice_rawAudio       .. "',"
        .. "'" .. _TRK_voice_refinedAudio   .. "',"
        .. "'" .. _TRK_voice_structuredMIDI .. "'"
        .. "]"

    --

    function _tnpConLine (pattern, partner, sendMode, inversion, suffix)
        return String.format(" '%s': ['%s', '%s', %s]%s",
                             pattern, partner, sendMode, inversion, suffix)
    end

    --

    local _TRK_effect_matched = _PREFIX_voiceEffects .. "%1"
    local _TRK_final_matched  = _PREFIX_voiceFinal   .. "%1"
    
    local _defaultTNPToConnectionString = "{"
        .. _tnpConLine(_TRK_voice_effects, _TRK_final_matched,
                       "postFX",  true, ",")
        .. _tnpConLine(_TRK_voice_generatedMIDI, _TRK_effect_matched,
                       "postFX", false, ",")
        .. _tnpConLine(_TRK_voice_rawAudio, _TRK_effect_matched,
                       "preFX",  false, ",")
        .. _tnpConLine(_TRK_voice_refinedAudio, _TRK_final_matched,
                       "preFX",  false, ",")
        .. _tnpConLine(_TRK_voice_structuredMIDI, _TRK_effect_matched,
                       "postFX", false, " ")
        .. "}"

    local _defaultTNPSentToEffectsList = "["
        .. " '" .. _TRK_voice_structuredMIDI .. "',"
        .. " '" .. _TRK_voice_generatedMIDI  .. "',"
        .. " '" .. _TRK_voice_rawAudio       .. "'"
        .. "]"

    local _defaultTrackNamePatternEffects = _TRK_voice_effects
    local _defaultTrackNamePatternFinal   = _TRK_voice_final

    local _defaultSelectionDialogIdleDuration = 10

    -- --------------------
    -- local features
    -- --------------------

    function _readConfigurationFile (configurationPathList,
                                     configurationFileName)
        -- Reads configuration file given by <configurationFileName>
        -- from paths in <configurationPathList> (if available) and
        -- returns configuration file object

        local fName = "LTBVCConfiguration._readConfigurationFile"
        Logging.traceF(fName,
                       ">>: configurationPathList = %s,"
                       .. " configurationFileName = %s",
                       configurationPathList, configurationFileName)

        ConfigurationFile:initialize()
        ConfigurationFile:setSearchPaths(configurationPathList)
        result = ConfigurationFile:make(configurationFileName)

        Logging.traceF(fName, "<<: found = %s", result ~= nil)
        return result
    end

    -- --------------------

    function _readVariables (configurationFile)
        -- Reads configuration file given by <configurationFile>
        -- into variables or sets them to defaults

        local fName = "LTBVCConfiguration._readVariables"
        Logging.traceF(fName,">>")

        local dialogIdleDuration
        local tnpAndHeaderList
        local tnpVoiceEffects
        local tnpVoiceFinal
        local tnpSentToEffectsSet
        local tnpToColString
        local tnpToConnectionString
        local tnpWithNoParentsString

        if configurationFile == nil then
            Logging.traceF(fName, "--: no configuration file")
        else
            key = "selectionDialogIdleDuration"
            dialogIdleDuration = configurationFile:value(key)
            key = "trackNamePatternToColorAndLayoutMap"
            tnpToColString = configurationFile:value(key)
            key = "trackNamePatternToConnectionDataMap"
            tnpToConnectionString = configurationFile:value(key)
            key = "trackNamePatternWithParentDisabledList"
            tnpWithNoParentsString = configurationFile:value(key)
            key = "trackNamePatternAndHeaderList"
            tnpAndHeaderList = configurationFile:value(key)
            key = "trackNamePatternSentToEffectsList"
            tnpSentToEffectsSet = configurationFile:value(key)
            key = "trackNamePatternForVoiceEffects"
            tnpVoiceEffects = configurationFile:value(key)
            key = "trackNamePatternForVoiceFinal"
            tnpVoiceFinal = configurationFile:value(key)
        end

        -- apply default values if configuration file values are not valid
        dialogIdleDuration =
            dialogIdleDuration or _defaultSelectionDialogIdleDuration
        tnpToColString =
            tnpToColString or _defaultTNPToColorString
        tnpToConnectionString =
            tnpToConnectionString or _defaultTNPToConnectionString
        tnpWithNoParentsString =
            tnpWithNoParentsString or _defaultTNPWithNoParentsString
        tnpAndHeaderList = tnpAndHeaderList or _defaultTNPAndHeaderList
        tnpSentToEffectsSet =
            tnpSentToEffectsSet or _defaultTNPSentToEffectsList
        tnpVoiceEffects = tnpVoiceEffects or _defaultTrackNamePatternEffects
        tnpVoiceFinal   = tnpVoiceFinal   or _defaultTrackNamePatternFinal

        -- set configuration variables
        LTBVCConfiguration._selectionDialogIdleDuration = dialogIdleDuration
        LTBVCConfiguration._trackNamePatternToColorAndLayoutMap =
            String.deserialize(tnpToColString)
        LTBVCConfiguration._trackNamePatternToConnectionDataMap =
            String.deserialize(tnpToConnectionString)
        LTBVCConfiguration._trackNamePatternWithParentDisabledList =
            String.deserialize(tnpWithNoParentsString)
        LTBVCConfiguration._trackNamePatternAndHeaderList =
            String.deserialize(tnpAndHeaderList)
        LTBVCConfiguration._trackNamePatternSentToEffectsSet =
            Set:makeFromIterable(String.deserialize(tnpSentToEffectsSet))
        
        LTBVCConfiguration._trackNamePatternForVoiceEffects = tnpVoiceEffects
        LTBVCConfiguration._trackNamePatternForVoiceFinal   = tnpVoiceFinal

        Logging.traceF(fName,
                       "--: tnpToColorAndLayoutMap = %s,"
                       .. " tnpToConnectionDataMap = %s,"
                       .. " tnpWithParentDisabledList = %s,"
                       .. " tnpAndHeaderList = %s,"
                       .. " tnpSentToEffectsSet = %s,"
                       .. " tnpVoiceEffects = '%s',"
                       .. " tnpVoiceFinal = '%s'",
                       LTBVCConfiguration._trackNamePatternToColorAndLayoutMap,
                       LTBVCConfiguration._trackNamePatternToConnectionDataMap,
                       LTBVCConfiguration._trackNamePatternWithParentDisabledList,
                       LTBVCConfiguration._trackNamePatternAndHeaderList,
                       LTBVCConfiguration._trackNamePatternSentToEffectsSet,
                       LTBVCConfiguration._trackNamePatternForVoiceEffects,
                       LTBVCConfiguration._trackNamePatternForVoiceFinal)
        
        
        Logging.traceF(fName, "<<")
    end

    -- --------------------
    -- exported features
    -- --------------------

    function LTBVCConfiguration.initialize (configurationPathList,
                                            configurationFileName)
        -- Reads configuration file given by <configurationFileName>
        -- from paths in <configurationPathList> (if available) and
        -- sets internal variables

        local fName = "LTBVCConfiguration.initialize"
        Logging.traceF(fName,
                       ">>: configurationPathList = %s,"
                       .. " configurationFileName = '%s'",
                       configurationPathList, configurationFileName)

        configurationFile = _readConfigurationFile(configurationPathList,
                                                   configurationFileName)
        _readVariables(configurationFile)

        Logging.traceF(fName, "<<")
    end

    -- --------------------

    function LTBVCConfiguration.selectionDialogIdleDuration ()
        -- Returns for audio source selection dialog the maximum idle
        -- duration

        local fName = "LTBVCConfiguration.selectionDialogIdleDuration"
        Logging.traceF(fName, ">>")
        local result = LTBVCConfiguration._selectionDialogIdleDuration
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function LTBVCConfiguration.selectionDialogTrackNameData ()
        -- Returns for audio source selection dialog the list of
        -- ordered track name patterns, list of associated headers,
        -- set of track name patterns sent to effects track and effects
        -- and final voice track pattern name

        local fName = "LTBVCConfiguration.selectionDialogTrackNameData"
        Logging.traceF(fName, ">>")

        local trackNamePatternAndHeaderList,
              trackNamePatternSentToEffectsSet,
              trackNamePatternForVoiceEffects,
              trackNamePatternForVoiceFinal =
            LTBVCConfiguration._trackNamePatternAndHeaderList,
            LTBVCConfiguration._trackNamePatternSentToEffectsSet,
            LTBVCConfiguration._trackNamePatternForVoiceEffects,
            LTBVCConfiguration._trackNamePatternForVoiceFinal

        local trackNamePatternList = List:make()
        local trackKindHeaderList  = List:make()

        for _, patternAndHeader in trackNamePatternAndHeaderList:iterator() do
            local namePattern, header = patternAndHeader:unpack()
            trackNamePatternList:append(namePattern)
            trackKindHeaderList:append(header)
        end
        
        Logging.traceF(fName,
                       "<<: trackNamePatternList = %s,"
                       .. " trackKindHeaderList = %s,"
                       .. " trackNamePatternSentToEffectsSet = %s,"
                       .. " trackNamePatternForVoiceEffects = '%s',"
                       .. " trackNamePatternForVoiceFinal = '%s'",
                       trackNamePatternList,
                       trackKindHeaderList,
                       trackNamePatternSentToEffectsSet,
                       trackNamePatternForVoiceEffects,
                       trackNamePatternForVoiceFinal)

        return trackNamePatternList,
               trackKindHeaderList,
               trackNamePatternSentToEffectsSet,
               trackNamePatternForVoiceEffects,
               trackNamePatternForVoiceFinal
    end

    -- --------------------

    function LTBVCConfiguration.trackColorAndLayoutByTrackName (trackName)
        -- Returns associated color and MCP layout name for track with
        -- <trackName>

        local fName = "LTBVCConfiguration.trackColorAndLayoutByTrackName"
        Logging.traceF(fName, ">>: %s", trackName)

        local resultPair
        local trackColor, trackMCPLayoutName

        local namePatternsSet =
            LTBVCConfiguration._trackNamePatternToColorAndLayoutMap:keySet()

        for _, namePattern in namePatternsSet:iterator() do
            local isFound = trackName:find(namePattern)
            Logging.traceF(fName,
                           "--: scanning for color/layout '%s' -> '%s' - %s",
                           trackName, namePattern, isFound)

            if isFound then
                resultPair =
                    LTBVCConfiguration.
                        _trackNamePatternToColorAndLayoutMap:at(namePattern)
            end
        end

        if resultPair == nil then
            trackColor, trackMCPLayoutName = nil, nil
        else
            trackColor, trackMCPLayoutName = resultPair:at(1), resultPair:at(2)
        end

        Logging.traceF(fName,
                       "<<: color = %s, layoutName = '%s'",
                       trackColor, trackMCPLayoutName)
        return trackColor, trackMCPLayoutName
    end

    -- --------------------

    function LTBVCConfiguration.trackInputOutputSettingsByTrackName (trackName)
        -- Returns associated information about connection settings for
        -- track with <trackName>

        local fName = "LTBVCConfiguration.trackInputOutputSettingsByTrackName"
        Logging.traceF(fName, ">>: %s", trackName)

        local parentChannelsAreUsed = true
        local isFound
        local connectionSettings

        local namePatternList =
            LTBVCConfiguration._trackNamePatternWithParentDisabledList

        for _, namePattern in namePatternList:iterator() do
            isFound = trackName:find(namePattern)
            Logging.trace("--: scanning for parent channels '%s' -> '%s' - %s",
                          trackName, namePattern, isFound)

            if isFound then
                parentChannelsAreUsed = false
            end
        end

        local namePatternSet =
            LTBVCConfiguration._trackNamePatternToConnectionDataMap:keySet()

        for _, namePattern in namePatternSet:iterator() do
            isFound = String.findPattern(trackName, namePattern)
            Logging.traceF(fName,
                           "--: scanning for connections '%s' -> '%s' - %s",
                           trackName, namePattern, isFound)

            if isFound then
                connectionSettings =
                    LTBVCConfiguration.
                        _trackNamePatternToConnectionDataMap:at(namePattern)
                connectionSettings = connectionSettings:clone()
                local groupList = String.captureList(trackName, namePattern)
                Logging.traceF(fName,
                               "--: match with '%s' (%s),"
                               .. " connection settings raw = %s",
                               namePattern, groupList, connectionSettings)
                local st = connectionSettings:at(1)

                -- replace all groups in target pattern
                for i = 1, groupList:count() do
                    local template = "%%" .. String.format("%d", i)
                    local value = groupList:at(i)
                    Logging.traceF(fName,
                                   "--: template = %s, value = %s",
                                   template, value)
                    st = st:gsub(template, value)
                end

                connectionSettings:set(1, st)
                break
            end
        end

        if connectionSettings == nil then
        end

        Logging.traceF(fName,
                       "<<: parentChannelsAreUsed = %s,"
                       .. " connectionSettings = %s",
                       parentChannelsAreUsed, connectionSettings)
        return parentChannelsAreUsed, connectionSettings
    end

-- ======================
-- end LTBVCConfiguration
-- ======================
