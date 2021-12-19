-- exportLilypond - exports MIDI data of selected media items to
--                  clipboard in LilyPond format
--
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

local _, scriptPath = reaper.get_action_context()
local scriptDirectory = scriptPath:match('^.+[\\//]')
package.path = scriptDirectory .. "?.lua"

require("Logging")
require("Lilypond")
require("List")
require("Map")
require("OperatingSystem")
require("Reaper")
require("Set")

-- =======================

-- names of configuration variables in project settings specifying the
-- key of the song and the information whether adapted notation is
-- used
local _keyConfigVariableName = "key"
local _adaptedNotationConfigVariableName = "adaptedNotationIsUsed"

-- =======================

function _initialize ()
    Logging:initialize()
    local directoryPath =
        OperatingSystem.selectDirectory("/tmp", "REAPERLOGS", "TEMP", "TMP")

    if directoryPath ~= nil then
        Logging.setFileName(directoryPath .. "/reaper_exportLilypond.log")
    end
end

-- --------------------

function _finalize ()
    Logging.finalize()
end

-- =======================

function _activeMidiTake (mediaItem)
    -- Returns active take of <mediaItem> if this is a midi
    -- take, otherwise nil is returned

    Logging.trace(">>: %s", mediaItem)

    local result

    if mediaItem:takeCount() ~= 1 then
        Logging.trace("--: take count <> 1")
    else
        local take = mediaItem:activeTake()

        if not take:isMIDI() then
            Logging.trace("--: active take is not MIDI")
        else
            Logging.trace("--: active take is MIDI")
            result = take
        end
    end

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _midiToLilypond (take)
    -- Returns a lilypond note representation of <take>

    Logging.trace(">>: %s", take)

    local result
    local takeName = take:name()
    local mediaSource = take:mediaSource()
    local midiNoteEventList = take:midiEventList(Reaper.MidiEventKind.note)
    local measureBarTickList = mediaSource:measureBarTickList()
    local endPosition = measureBarTickList:last()
    local ticksPerQuarterNote = take:midiResolution()
    local takeLilypondString =
              Lilypond.convertTakeToLilypondString(takeName,
                                                   ticksPerQuarterNote,
                                                   midiNoteEventList,
                                                   measureBarTickList,
                                                   endPosition)
    result = takeLilypondString .. String.newline

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function _readConfigurationVariables (project)
    -- Returns key of song embedded in project notes

    Logging.trace(">>: %s", project)

    local key = Reaper.ConfigData.get(project, _keyConfigVariableName)
    local adaptedNotationIsUsed =
        Reaper.ConfigData.get(project, _adaptedNotationConfigVariableName)
    key = iif(key == nil, "c", key)
    adaptedNotationIsUsed = iif(adaptedNotationIsUsed == nil, true,
                                adaptedNotationIsUsed == "true")

    Logging.trace("<<: key = %s, adaptedNotationIsUsed = %s",
                  key, adaptedNotationIsUsed)
    return key, adaptedNotationIsUsed
end

-- --------------------
-- --------------------

function main ()
    Logging.trace(">>")

    local encounteredTakeNameSet = Set:make()
    local project = Reaper.Project.current()
    local key, adaptedNotationIsUsed =
        _readConfigurationVariables(project)

    local mediaItemList = project:selectedMediaItemList()
    local st = ""

    Lilypond.initialize(key, adaptedNotationIsUsed)

    for i, mediaItem in mediaItemList:iterator() do
        Logging.trace("--: scanning media item %d", i)
        local mediaItemName = tostring(mediaItem)
        local take = _activeMidiTake(mediaItem)

        if take == nil then
            Logging.trace("--: no MIDI in item %s", mediaItemName)
        else
            local takeName = take:name()

            if encounteredTakeNameSet:contains(takeName) then
                Logging.trace("--: already processed %s", mediaItemName)
            else
                Logging.trace("--: MIDI take in item %s", mediaItemName)
                encounteredTakeNameSet:include(takeName)
                st = st .. _midiToLilypond(take)
            end
        end
    end

    Logging.show(st)
    Logging.trace("<<")
end

-- =======================

_initialize()
main()
_finalize()
