-- NormalizeStructuredMidiTracks - sets all midi items in structured MIDI
--                                 tracks (with a name starting with "S ")
--                                 to standard note velocity, and removes
--                                 volume, pan and reverb settings
--
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

local _, scriptPath = reaper.get_action_context()
local scriptDirectory = scriptPath:match('^.+[\\//]')
package.path = scriptDirectory .. "?.lua"

require("math")

require("List")
require("Logging")
require("Map")
require("OperatingSystem")
require("Reaper")
require("Set")

-- =======================

function _initialize ()
    Logging:initialize()
    local directoryPath =
        OperatingSystem.selectDirectory("/tmp", "REAPERLOGS", "TEMP", "TMP")

    if directoryPath ~= nil then
        Logging.setFileName(directoryPath .. "/reaper_normalizeStrMIDI.log")
    end
end

-- --------------------

function _finalize ()
    Logging.finalize()
end

-- =======================

local _programName = "NormalizeStructuredVoiceTracks"
local _trackNamePatternVariableName = "structuredMidiTrackNamePattern"
local _defaultMidiTrackNamePattern = "S .*"
local _defaultNoteVelocity = 80

-- the set of control codes to be removed
local _controlCodeSet = Set:make()
_controlCodeSet:include( 7) -- volume
_controlCodeSet:include(10) -- pan
_controlCodeSet:include(91) -- reverb
    
-- =======================

function _adaptToRaster (value, rasterSize)
    -- Quantizes <value> to raster given by <rasterSize> and returns
    -- resulting value; the value is adapted to either 2 or 3 times
    -- the raster size and the value with the minimal distance is
    -- selected

    Logging.trace(">>: value = %d, raster = %d", value, rasterSize)

    local distance = 9999
    local result
    
    for i = 2, 3 do
        local currentRasterSize = i * rasterSize
        local rasteredValue =
            math.floor(0.5 + value / currentRasterSize) * currentRasterSize
        local newDistance = math.abs(value - rasteredValue)

        if newDistance < distance then
            result = rasteredValue
            distance = newDistance
        end
    end

    Logging.trace("<<: %d", result)
    return result
end

-- --------------------

function _processTake (take)
    -- Sets events in <take>: adapts note velocity to standard value,
    -- quantizes notes to 32nds and removes volume, pan and reverb
    -- settings

    Logging.trace(">>: take = %s", take)

    _removeUnwantedControlCodes(take)
    _setNoteVelocitiesAndPositions(take)

    Logging.trace("<<")
end

-- --------------------

function _processVoiceTrack (track)
    -- Adapts each midi media item in <track>; sets note velocity to
    -- standard value, quantizes notes according to 32nds and removes
    -- volume, pan and reverb settings

    Logging.trace(">>: track = %s", track)

    local visitedMediaItemSet = Set:make()

    for _, mediaItem in track:mediaItemList():iterator() do
        if visitedMediaItemSet:contains(mediaItem) then
              Logging.trace("--: skipped visited item %s", mediaItem)
        else
            -- mark this item as visited
            visitedMediaItemSet:include(mediaItem)

            for _, take in mediaItem:takeList():iterator() do
                if not take:isMIDI() then
                    Logging.trace("--: skipped non-MIDI take %s", take)
                else
                    _processTake(take)
                end
            end
        end
    end

    Logging.trace("<<")
end

-- --------------------

function _removeUnwantedControlCodes (take)
    -- Removes control events in <take> as specified in
    -- <_controlCodeSet>

    Logging.trace(">>: %s", take)

    local midiControlEventKind = Reaper.MidiEventKind.controlCode
    local midiControlEventList = take:midiEventList(midiControlEventKind)
    Logging.trace("--: ccEventCount[%s] = %d",
                  take, midiControlEventList:count())

    for i, controlEvent in midiControlEventList:reversedIterator() do
        local controlCode = controlEvent.messagePart1
        local isRelevant = _controlCodeSet.contains(controlCode)
        Logging.trace("--: index = %d, cc = %d, isRelevant = %s",
                      i, controlCode, isRelevant)

        if isRelevant then
            midiControlEventList:deleteEvent(eventIndex)
        end
    end

    Logging.trace("<<")
end

-- --------------------

function _setNoteVelocitiesAndPositions (take)
    -- Adapts note events in <take>: set velocity to default and
    -- quantize to raster positions

    Logging.trace(">>: take = %s", take)

    local midiNoteEventList =
              take:midiEventList(Reaper.MidiEventKind.note)
    Logging.trace("--: noteEventCount[%s] = %d",
                  take, midiNoteEventList:count())

    local midiResolution = take:midiResolution() / 24
    Logging.trace("--: midiResolution = %s", midiResolution)
    
    for i, noteEvent in midiNoteEventList:iterator() do
        Logging.trace("--: event %s", noteEvent)

        -- adapt velocity
        noteEvent.velocity = _defaultNoteVelocity

        -- adapt start and end position to resolution
        local startPosition = noteEvent.startPosition
        local duration = noteEvent.endPosition - startPosition
        startPosition = _adaptToRaster(startPosition, midiResolution)
        duration = math.max(midiResolution,
                            _adaptToRaster(duration, midiResolution))
        noteEvent.startPosition = startPosition
        noteEvent.endPosition   = startPosition + duration
        Logging.trace("--: new event %s", noteEvent)
        take:setMidiEvent(i, noteEvent)
    end

    Logging.trace("<<")
end

-- =======================

function main()
    Logging.trace(">>")

    local project = Reaper.Project.current()
    local trackNamePattern =
        Reaper.ConfigData.get(project, _trackNamePatternVariableName)

    trackNamePattern =
        iif(trackNamePattern == nil,
            _defaultMidiTrackNamePattern, trackNamePattern)
    Logging.trace("--: pattern = \"%s\"", trackNamePattern)
    
    local isStructuredVoiceTrackProc =
              function (track)
                  return String.findPattern(track:name(),
                                            trackNamePattern)
              end
    local trackList =
              project:trackList():filter(isStructuredVoiceTrackProc)
    Logging.trace("--: trackList = %s", trackList)

    for _, track in trackList:iterator() do
        _processVoiceTrack(track)
    end

    -- we're done
    local title = _programName
    Reaper.UI.showMessageBox("Done.", title, Reaper.UI.MessageBoxKind.ok)
    Logging.trace("<<")
end

-- --------------------

_initialize()
main()
_finalize()
