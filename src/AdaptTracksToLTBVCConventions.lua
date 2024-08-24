-- adaptTrackLayoutToLTBVCConventions -- changes colours and layout styles
--                                       from tracks to LTBVC conventions;
--                                       assumes track naming adheres to
--                                       those conventions
--
-- by Dr. TT, 2022

local _, scriptPath = reaper.get_action_context()
local scriptDirectory = scriptPath:match('^.+[\\//]')
package.path = scriptDirectory .. "?.lua"

-- =======
-- IMPORTS
-- =======

require("Logging")
require("LTBVCConfiguration")
require("Map")
require("OperatingSystem")
require("Reaper")
require("Set")
require("String")

-- =======================

local _programName = "adaptTracksToLTBVCConventions"
local _configurationFileName = "LTBVC_trackConventions.cfg"

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

    local homeDirectory = OperatingSystem.homeDirectoryPath()
    local configurationPathList =
        List:makeFromArray({ OperatingSystem.dirName(scriptDirectory),
                             homeDirectory .. "/.luasettings"})
    LTBVCConfiguration.initialize(configurationPathList,
                                  _configurationFileName)
end

-- --------------------

function _finalize ()
    Logging.finalize()
end

-- --------------------
-- --------------------

function _adaptLayoutOfTracks (trackList)
    -- Traverses the tracks in <trackList> and changes colours and
    -- layout styles from tracks to LTBVC conventions assuming
    -- track naming adheres to those conventions

    Logging.trace(">>")

    for _, track in trackList:iterator() do
        local trackName = track:name()
        local trackColor, trackMCPLayoutName =
            LTBVCConfiguration.trackColorAndLayoutByTrackName(trackName)

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

function _makeTrackConnection (trackList,
                               track, partnerNamePattern,
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

function _updateSingleTrackInputOutput (trackList, track)
    -- Connects <track> to other tracks according to the LTBVC
    -- conventions assuming track naming adheres to those conventions

    local trackName = track:name()
    Logging.trace(">>: %s", trackName)

    local parentChannelsAreUsed, connectionSettings = 
        LTBVCConfiguration.trackInputOutputSettingsByTrackName(trackName)

    if not parentChannelsAreUsed then
        -- disable parent, set volume to -infinity and pan to center
        track:setPan(0)
        track:setVolume(0)

        -- adapt parent channel usage when parent has connections
        local parentTrack = track:parent()
        local parentSendIsEnabled = false

        if parentTrack ~= nil then
            local _, parentConnectionSettings =
                LTBVCConfiguration
                    .trackInputOutputSettingsByTrackName(parentTrack:name())
            parentSendIsEnabled = (parentConnectionSettings ~= nil)
        end

        track:setSendingToParent(parentSendIsEnabled)
    end

    if connectionSettings ~= nil then
        local partnerNamePattern = connectionSettings:at(1)
        local sendModeAsString   = connectionSettings:at(2)
        local isInverted         = connectionSettings:at(3)

        _makeTrackConnection(trackList,
                             track, partnerNamePattern,
                             sendModeAsString, isInverted)
    end

    Logging.trace("<<")
end

-- --------------------

function _updateInputOutputForTracks (trackList)
    -- Traverses the tracks in track list, changes their output and
    -- connects them according to the LTBVC conventions assuming track
    -- naming adheres to those conventions

    Logging.trace(">>")

    for _, track in trackList:iterator() do
        _updateSingleTrackInputOutput(trackList, track)
    end

    Logging.trace("<<")
end

-- --------------------

function main ()
    Logging.trace(">>")

    local project = Reaper.Project.current()
    local trackList = project:trackList()
    _adaptLayoutOfTracks(trackList)
    _updateInputOutputForTracks(trackList)
    
    -- we're done
    local title = _programName
    Reaper.UI.showMessageBox("Done.", title, Reaper.UI.MessageBoxKind.ok)
    Logging.trace("<<")
end

-- =======================

_initialize()
main()
_finalize()
