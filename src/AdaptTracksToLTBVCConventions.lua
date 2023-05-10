-- adaptTrackLayoutToLTBVCConventions -- changes colours and layout styles
--                                       from tracks to LTBVC conventions;
--                                       assumes track naming adheres to
--                                       those conventions
--
-- by Dr. TT, 2022

local _, scriptPath = reaper.get_action_context()
local scriptDirectory = scriptPath:match('^.+[\\//]')
package.path = scriptDirectory .. "?.lua"
package.path = ("C:/Programme_LOKAL/Multimedia/MIDI/Reaper"
                .. "/Scripts/DrTT-LTBVC_(Lua)/PluginsForLTBVC"
                .. "/?.lua")

-- =======
-- IMPORTS
-- =======

require("ConfigurationFile")
require("Logging")
require("Map")
require("OperatingSystem")
require("Reaper")
require("Set")
require("String")

-- =======================

local _programName = "adaptTracksToLTBVCConventions"
local _configurationFileName = "LTBVC_adaptTracksToConventions.cfg"
local trackList

-- =======================

function _initialize ()
    Logging:initialize()
    local directoryPath =
        OperatingSystem.selectDirectory("/tmp", "REAPERLOGS", "TEMP", "TMP")

    if directoryPath ~= nil then
        Logging.setFileName(directoryPath
                            .. "/reaper_" .. _programName
                            .. ".log")
    end
end

-- --------------------

function _finalize ()
    Logging.finalize()
end

-- =======================
-- CONFIGURATION VARIABLES
-- =======================

-- mapping from track name pattern to color and layout name
local _trackNamePatternToColorAndLayoutMap

-- list of track name patterns where parent channel connection is
-- disabled
local _trackNamePatternWithParentDisabledList

-- mapping from track name pattern to a tuple of connection partner,
-- send mode and phase inversion settings
local _trackNamePatternToConnectionDataMap

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

-- default value strings for the different configuration variables

function _tnpCLLine (pattern, color, layout, suffix)
    return String.format(" '%s': [%d, '%s']%s",
                         pattern, color, layout, suffix)
end

--

local _defaultTCToTNPString =
    "{"
    .. "'effects' : '^E%s+(%S.*)$',"
    .. "}"

--

local _defaultTNPToColorString =
    "{"
    .. _tnpCLLine("^EFFECTS", _COL_blue, _LAY_groupTrackWithoutFX, ",")
    .. _tnpCLLine("^FINAL MIX", _COL_cyan, _LAY_groupTrackWithFX, ",")
    .. _tnpCLLine("^GEN. MIDI", _COL_green, _LAY_groupTrackWithoutFX, ",")
    .. _tnpCLLine("^ORIGINAL", _COL_red, _LAY_groupTrackWithFX, ",")
    .. _tnpCLLine("^RAW AUDIO", _COL_yellow, _LAY_groupTrackWithoutFX, ",")
    .. _tnpCLLine("^REF. AUDIO", _COL_yellow, _LAY_groupTrackWithoutFX, ",")
    .. _tnpCLLine("^RESULT", _COL_magenta, _LAY_standardTrack, ",")
    .. _tnpCLLine("^STRUCTURED", _COL_green, _LAY_groupTrackWithoutFX, ",")
    .. _tnpCLLine("^E%s+", _COL_lightBlue, _LAY_effectBusTrack, ",")
    .. _tnpCLLine("^F%s+", _COL_lightCyan, _LAY_mixerBusTrack, ",")
    .. _tnpCLLine("^M%s+", _COL_lightGreen, _LAY_midiTrack, ",")
    .. _tnpCLLine("^O%s+", _COL_lightRed, _LAY_standardTrack, ",")
    .. _tnpCLLine("^RA%s+", _COL_lightYellow, _LAY_audioTrack, ",")
    .. _tnpCLLine("^RF%s+", _COL_lightYellow, _LAY_audioTrack, ",")
    .. _tnpCLLine("^S%s+", _COL_lightGreen, _LAY_midiTrac, " ")
    .. "}"

--

local _defaultTNPWithNoParentsString = "["
    .. " '^E%s+', '^EFFECTS', '^GEN. MIDI', '^M%s+', '^RA%s+',"
    .. " '^RAW AUDIO', '^REF. AUDIO', ^RF%s+', '^S%s+', '^STRUCTURED' "
    .. "]"

--

function _tnpConLine (pattern, partner, sendMode, inversion, suffix)
    return String.format(" '%s': ['%s', '%s', %s]%s",
                         pattern, partner, sendMode, inversion, suffix)
end

--

local _defaultTNPToConnectionString = "{"
    .. _tnpConLine("^E%s+(.*)",  "^F%s+%1", "postFX",  true, ",")
    .. _tnpConLine("^M%s+(.*)",  "^E%s+%1", "postFX", false, ",")
    .. _tnpConLine("^RA%s+(.*)", "^E%s+%1", "preFX",  false, ",")
    .. _tnpConLine("^RF%s+(.*)", "^F%s+%1", "preFX",  false, ",")
    .. _tnpConLine("^S%s+(.*)",  "^E%s+%1", "postFX", false, " ")
    .. "}"

-- --------------------
-- --------------------

function _adaptLayoutOfTracks ()
    -- Traverses the tracks in track list and changes colours and
    -- layout styles from tracks to LTBVC conventions assuming
    -- track naming adheres to those conventions

    Logging.trace(">>")

    for _, track in trackList:iterator() do
        local trackName = track:name()
        local trackColor, trackMCPLayoutName =
            _findTrackColorAndLayoutByTrackName(trackName)

        if trackMCPLayoutName == nil then
            Logging.trace("--: track does not adhere to conventions %s",
                          trackName)
        else
            Logging.trace("--: track = %s", track)
            -- set color and layout
            local mixerControlPanel =
                Reaper.UI.MixerControlPanel.findByTrack(track)
            mixerControlPanel:setLayout(trackMCPLayoutName)
            mixerControlPanel:setColor(trackColor)
        end
    end

    Logging.trace("<<")
end

-- --------------------

function _findTrackColorAndLayoutByTrackName (trackName)
    -- Returns associated color and MCP layout name for track with
    -- <trackName>

    Logging.trace(">>: %s", trackName)
    local resultPair
    local trackColor, trackMCPLayoutName

    local namePatternsSet =
        _trackNamePatternToColorAndLayoutMap:keySet()

    for _, namePattern in namePatternsSet:iterator() do
        local isFound = trackName:find(namePattern)
        Logging.trace("--: scanning for color/layout '%s' -> '%s' - %s",
                      trackName, namePattern, isFound)

        if isFound then
            resultPair =
                _trackNamePatternToColorAndLayoutMap:at(namePattern)
        end
    end
        
    if resultPair == nil then
        trackColor, trackMCPLayoutName = nil, nil
    else
        trackColor, trackMCPLayoutName = resultPair:at(1), resultPair:at(2)
    end
    
    Logging.trace("<<: color = %s, layoutName = '%s'",
                  trackColor, trackMCPLayoutName)
    return trackColor, trackMCPLayoutName
end

-- --------------------

function _findTrackInputOutputSettingsByTrackName (trackName)
    -- Returns associated information about used parent channels and
    -- connection settings for track with <trackName>

    Logging.trace(">>: %s", trackName)
    local parentChannelsAreUsed = true
    local isFound
    local connectionSettings

    local namePatternList = _trackNamePatternWithParentDisabledList

    for _, namePattern in namePatternList:iterator() do
        isFound = trackName:find(namePattern)
        Logging.trace("--: scanning for parent channels '%s' -> '%s' - %s",
                      trackName, namePattern, isFound)

        if isFound then
            parentChannelsAreUsed = false
        end
    end

    local namePatternSet =
        _trackNamePatternToConnectionDataMap:keySet()

    for _, namePattern in namePatternSet:iterator() do
        isFound = String.findPattern(trackName, namePattern)
        Logging.trace("--: scanning for connections '%s' -> '%s' - %s",
                      trackName, namePattern, isFound)

        if isFound then
            connectionSettings =
                _trackNamePatternToConnectionDataMap:at(namePattern)
            connectionSettings = connectionSettings:clone()
            local groupList = String.captureList(trackName, namePattern)
            Logging.trace("--: match with '%s' (%s),"
                          .. " connection settings raw = %s",
                          namePattern, groupList, connectionSettings)
            local st = connectionSettings:at(1)

            -- replace all groups in target pattern
            for i = 1, groupList:count() do
                local template = "%%" .. String.format("%d", i)
                local value = groupList:at(i)
                Logging.trace("--: template = %s, value = %s",
                              template, value)
                st = st:gsub(template, value)
            end
            
            connectionSettings:set(1, st)
            break
        end
    end

    Logging.trace("<<: parentChannelsAreUsed = %s,"
                  .. " connectionSettings = %s",
                  parentChannelsAreUsed, connectionSettings)
    return parentChannelsAreUsed, connectionSettings
end

-- --------------------

function _makeTrackConnection (track, partnerNamePattern,
                               sendModeAsString, isInverted)
    -- Connects <track> to other track(s) having <partnerNamePattern> with
    -- standard volume and pan, given <sendModeAsString> and phase
    -- inversion depending on <isInverted>

    local noMidiTransfer = 31
    local trackName = track:name()
    Logging.trace(">>: track = %s, partner = %s, sendMode = %s,"
                  .. " isInverted = %s",
                  trackName, partnerNamePattern, sendModeAsString,
                  isInverted)

    local isFound = false

    for _, partnerTrack in trackList:iterator() do
        local partnerTrackName = partnerTrack:name()

        if partnerTrackName:match(partnerNamePattern) then
            isFound = true
            local connection = track:makeConnection(partnerTrack, false)
            local sendMode =
                Reaper.TrackSendModeKind.makeFromString(sendModeAsString)

            connection:setInverted(isInverted)
            connection:setMidiFlags(noMidiTransfer)
            connection:setMono(false)
            connection:setMuted(false)
            connection:setPan(0.0)
            connection:setSendMode(sendMode)
            connection:setVolume(1.0)
        end
    end

    if not isFound then
        Logging.trace("--: no partner track found for pattern %s",
                      partnerNamePattern)
    end
    
    Logging.trace("<<")
end

-- --------------------

function _readConfigurationFile ()
    -- Reads configuration file (if available) and returns
    -- configuration file object

    Logging.trace(">>")

    ConfigurationFile:initialize()
    local homeDirectory = OperatingSystem.homeDirectoryPath()
    local configPathList =
        List:makeFromArray({ OperatingSystem.dirName(scriptDirectory),
                             homeDirectory .. "/.luasettings"})
    ConfigurationFile:setSearchPaths(configPathList)
    result = ConfigurationFile:make(_configurationFileName)

    Logging.trace("<<: found = %s", result ~= nil)
    return result
end

-- --------------------

function _readVariables (configurationFile)
    -- Reads configuration file given by <configurationFile>
    -- into variables or sets them to defaults

    Logging.trace(">>")

    local tnpToColString
    local tnpToConnectionString
    local tnpWithNoParentsString

    if configurationFile == nil then
        Logging.trace("--: no configuration file")
    else
        key = "trackNamePatternToColorAndLayoutMap"
        tnpToColString = configurationFile:value(key)
        key = "trackNamePatternToConnectionDataMap"
        tnpToConnectionString = configurationFile:value(key)
        key = "trackNamePatternWithParentDisabledList"
        tnpWithNoParentsString = configurationFile:value(key)
    end

    -- apply default values if configuration file values are not valid
    tnpToColString =
        tnpToColString or _defaultTNPToColorString
    tnpToConnectionString =
        tnpToConnectionString or _defaultTNPToConnectionString
    tnpWithNoParentsString =
        tnpWithNoParentsString or _defaultTNPWithNoParentsString

    -- set configuration variables
    _trackNamePatternToColorAndLayoutMap =
        String.deserialize(tnpToColString)
    _trackNamePatternToConnectionDataMap =
        String.deserialize(tnpToConnectionString)
    _trackNamePatternWithParentDisabledList =
        String.deserialize(tnpWithNoParentsString)

    Logging.trace("<<")
end

-- --------------------

function _updateSingleTrackInputOutput (track)
    -- Connects <track> to other tracks according to the LTBVC
    -- conventions assuming track naming adheres to those conventions

    local trackName = track:name()
    Logging.trace(">>: %s", trackName)

    local parentChannelsAreUsed, connectionSettings = 
        _findTrackInputOutputSettingsByTrackName(trackName)

    if not parentChannelsAreUsed then
        -- disable parent, set volume to -infinity and pan to center
        track:setPan(0)
        track:setVolume(0)
        track:setSendingToParent(false)
    end
    
    if connectionSettings ~= nil then
        local partnerNamePattern = connectionSettings:at(1)
        local sendModeAsString   = connectionSettings:at(2)
        local isInverted         = connectionSettings:at(3)

        _makeTrackConnection(track, partnerNamePattern,
                             sendModeAsString, isInverted)
    end

    Logging.trace("<<")
end

-- --------------------

function _updateInputOutputForTracks ()
    -- Traverses the tracks in track list, changes their output and
    -- connects them according to the LTBVC conventions assuming track
    -- naming adheres to those conventions

    Logging.trace(">>")

    for _, track in trackList:iterator() do
        _updateSingleTrackInputOutput(track)
    end

    Logging.trace("<<")
end

-- --------------------

function main ()
    Logging.trace(">>")

    local project = Reaper.Project.current()
    trackList = project:trackList()
    configurationFile = _readConfigurationFile()
    _readVariables(configurationFile)
    
    _adaptLayoutOfTracks()
    _updateInputOutputForTracks()
    
    -- we're done
    local title = _programName
    Reaper.UI.showMessageBox("Done.", title, Reaper.UI.MessageBoxKind.ok)
    Logging.trace("<<")
end

-- =======================

_initialize()
main()
_finalize()
