-- importMIDI - scans current project for external MIDI file reference
--              and updates all affected tracks
--
-- author: Dr. Thomas Tensi, 2019-08

local _, scriptPath = reaper.get_action_context()
local scriptDirectory = scriptPath:match('^.+[\\//]')
package.path = scriptDirectory .. "?.lua"

-- =======
-- IMPORTS
-- =======

require("List")
require("Logging")
require("Map")
require("OperatingSystem")
require("Reaper")
require("Set")
require("String")

-- =======================

function _initialize ()
    Logging:initialize()
    local directoryPath =
        OperatingSystem.selectDirectory("/tmp", "REAPERLOGS", "TEMP", "TMP")

    if directoryPath ~= nil then
        Logging.setFileName(directoryPath .. "/reaper_importMidi.log")
    end
end

-- --------------------

function _finalize ()
    Logging.finalize()
end

-- =======================

local _programName = "ImportMIDI"

-- name of configuration variable in project settings specifying the
-- MIDI file path
local _configVariableName = "midiFilePath"

-- adapt midi tracks such that volume and reverb is standardized
local _midiTracksArePreprocessed = true

-- --------------------

function _showMessage (message)
    -- Shows <message> in message box

    Logging.trace(">>: %s", message)
    local title = _programName
    Reaper.UI.showMessageBox(message, title, Reaper.UI.MessageBoxKind.ok)
    Logging.trace("<<")
end

-- =======================

function checkForSingleItemAndMidiTake (track)
    -- Checks whether <track> has exactly one media item with one take
    -- containing MIDI data; returns result, media item and midi take

    Logging.trace(">>: %s", track)

    local mediaItem
    local take
    local isOkay = false

    if track:mediaItemCount() ~= 1 then
        Logging.trace("--: item count <> 1")
    else
        mediaItem = track:mediaItemByIndex(1)

        if mediaItem:takeCount() ~= 1 then
            Logging.trace("--: take count <> 1")
        else
            take = mediaItem:takeByIndex(1)

            if not take:isMIDI() then
                Logging.trace("--: take is not MIDI")
            else
                isOkay = true
            end
        end
    end

    Logging.trace("<<: isOkay = %s, mediaItem = %s, take = %s",
                  isOkay, mediaItem, take)
    return isOkay, mediaItem, take
end

-- --------------------

function findMidiFileFromTracks (project)
    -- Returns path of MIDI file calculated from <project> path and
    -- first take with a name containing ".mid" and the start time in
    -- the project of that take

    Logging.trace(">>: %s", project)

    local midiFilePath
    local startTime = project:timeOffset()
    local trackList = project:trackList()
    local midiFileDirectoryPath = midiFileDirectoryPath(project)
    Logging.trace("--: midiFileDirectoryPath = %s", midiFileDirectoryPath)

    for _, track in trackList:iterator() do
        local isOkay, mediaItem, take =
                  checkForSingleItemAndMidiTake(track)

        if isOkay then
            local takeName = take:name()

            if String.hasSuffix(takeName, ".mid") then
                midiFilePath = String.globalReplace(takeName, ".+ ", "")
                startTime = take:startPosition()
                break
            end
        end
    end

    if midiFilePath ~= nil then
        midiFilePath = midiFileDirectoryPath .. "/" .. midiFilePath
    end

    Logging.trace("<<: midiFilePath = '%s', startTime = %s",
                  midiFilePath, startTime)
    return midiFilePath, startTime
end

-- --------------------

function findTargetTrackAndReplace (project, track,
                                    nameToTrackIndexMap)
    -- Searches <nameToTrackIndexMap> for target track containing the
    -- MIDI snippet with the same name as the one in <track> and
    -- replaces it; returns target track index if found, otherwise 0

    Logging.trace(">>: %s", track)

    -- make sure that there is exactly one media item with one take
    -- containing MIDI data
    local isOkay, mediaItem, take = checkForSingleItemAndMidiTake(track)
    local targetTrackIndex = 0

    if not isOkay then
        Logging.trace("--: skipped")
    else
        local takeName = take:name()
        targetTrackIndex = nameToTrackIndexMap:at(takeName)

        if targetTrackIndex == nil then
            targetTrackIndex = 0
            Logging.trace("--: no partner for '%s'", takeName)
        else
            Logging.trace("--: partner for '%s' at index %d",
                          takeName, targetTrackIndex)
            local targetTrack = project:trackByIndex(targetTrackIndex)
            local targetMediaItem = targetTrack:mediaItemByIndex(1)
            targetMediaItem:delete()
            mediaItem:setTrack(targetTrack)
            mediaItem:setLocked(true)
            mediaItem:setTimeBase(Reaper.TimeBaseKind.beatPos)
        end
    end

    Logging.trace("<<: %d", targetTrackIndex)
    return targetTrackIndex
end

-- --------------------

function handleUnwantedMidiEvents (trackIndex, take)
    -- Removes volume, pan and program change midi events in current
    -- take

    Logging.trace(">>: %s", take)

    -- control change codes to be deleted
    local panControlChangeCode = 10
    local reverbControlChangeCode = 91
    local volumeControlChangeCode = 7

    local midiControlEventKind = Reaper.MidiEventKind.controlChange
    local midiControlEventList = take:midiEventList(midiControlEventKind)
    local eventCount = midiControlEventList:count()

    Logging.trace("--: ccEventCount[%s] = %d", take, eventCount)

    for eventIndex, controlEvent in midiControlEventList:reversedIterator() do
        local controlChange = controlEvent.messagePart1
        Logging.trace("--: index = %d, cc = %d", eventIndex, controlChange)
        local isRelevant = (controlChange == reverbControlChangeCode
                            or controlChange == volumeControlChangeCode
                            or controlChange == panControlChangeCode)

        if isRelevant then
            midiControlEventList:deleteEvent(eventIndex)
        end
    end

    Logging.trace("<<")
end

-- --------------------

function insertMediaFile (project, midiFileName, startTime)
    -- Inserts midi file given by <midiFileName> into several tracks
    -- after last track of <project> starting at <startTime>; returns
    -- whether insertion was successful

    Logging.trace(">>: project = '%s', midiFileName = '%s', startTime = %s",
                  project, midiFileName, startTime)

    -- make empty track for separation and as the insertion point
    local track = project:makeTrack()
    local result =
              project:insertMediaFileAfterTrackIndex(midiFileName,
                                                     project:trackCount(),
                                                     startTime)

    Logging.trace("<<: result = %s", result)
    return result
end

-- --------------------

function midiFileDirectoryPath (project)
    -- calculates midi file directory path for <project> by
    -- getting the project path and scanning the project description
    -- for a relative midi file path

    Logging.trace(">>: project = %s", project)

    local result

    -- strip off last part in project path and replace by either
    -- relative midiFilePath from project description or the current
    -- directory
    local midiFilePath = Reaper.ConfigData.get(project, _configVariableName)
    midiFilePath = iif(midiFilePath ~= nil, midiFilePath, ".")
    Logging.trace("--: path configuration read '%s'", midiFilePath)
    
    if OperatingSystem.isAbsolutePath(midiFilePath) then
        result = midiFilePath
    else
        local projectPath = project:path()
        result = projectPath .. "/" .. midiFilePath
    end

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function processAllTracks (project, trackList, previousTrackCount)
    -- traverses all tracks in <trackList>; those with index not
    -- greater than <previousTrackCount> contain material to be
    -- replaced by those with index greater than <previousTrackCount>

    local nameToTrackIndexMap = Map:make()

    Logging.trace(">>: project = %s, tracks = %s, previousTrackCount = %d",
                  project, trackList, previousTrackCount)

    -- find all media items imported from the external midi file
    for trackIndex, track in trackList:iterator() do
        Logging.trace("--: %d", trackIndex)

        if trackIndex > previousTrackCount then
            -- imported track
            targetTrackIndex =
                findTargetTrackAndReplace(project, track,
                                          nameToTrackIndexMap)
        else
            -- already existing track
            updateNameMapFromExistingTrack(track, trackIndex,
                                           nameToTrackIndexMap)
        end

        if trackIndex == previousTrackCount then
            Logging.trace("--: %s", nameToTrackIndexMap)
        end
    end

    Logging.trace("<<")
end

-- --------------------

function preprocessImportedTracks (project, trackList,
                                   previousTrackCount)
    -- Traverses all tracks in <trackList>; those with index greater
    -- than <previousTrackCount> contain imported material to be
    -- preprocessed: here only the midi volume changes and effect
    -- settings are removed

    Logging.trace(">>: project = %s, previousCount = %d",
                  project, previousTrackCount)

    -- traverse all media items imported from the external midi file
    for trackIndex, track in trackList:iterator() do
        local isRelevant = (trackIndex > previousTrackCount)
        local actionName = iif(isRelevant, "process", "skipped")
        Logging.trace("--: %s %d", actionName, trackIndex)

        if isRelevant and track:mediaItemCount() == 1 then
            -- the external track has exactly one item
            local mediaItem = track:mediaItemByIndex(1)
            local take = mediaItem:activeTake()
            handleUnwantedMidiEvents(trackIndex, take)
        end
    end

    Logging.trace("<<")
end

-- --------------------

function updateMidiTracks (project, midiFileName, startTime)
    -- Updates midi track in <project> by tracks in midi file given by
    -- <midiFileName> inserted at time <startTime>; returns whether
    -- insertion was done (or cancelled)

    Logging.trace(">>: project = '%s', file = '%s', startTime = %s",
                  project, midiFileName, startTime)

    local previousTrackCount = project:trackCount()

    -- insert midi file
    local insertionIsDone =
        insertMediaFile(project, midiFileName, startTime)

    if insertionIsDone then
        -- move tracks to end of list
        local trackList = project:trackList()

        if _midiTracksArePreprocessed then
            preprocessImportedTracks(project, trackList,
                                     previousTrackCount)
        end

        processAllTracks(project, trackList, previousTrackCount)

        -- delete all tracks imported from the midi file
        Logging.trace("--: deleting imported tracks")

        for trackIndex, track in trackList:iterator() do
            if trackIndex > previousTrackCount then
                track:delete()
            end
        end
    end

    Logging.trace("<<: %s", insertionIsDone)
    return insertionIsDone
end

-- --------------------

function updateNameMapFromExistingTrack (track, trackIndex,
                                         nameToTrackIndexMap)
    -- Scans <track> with index <trackIndex> for MIDI items and
    -- updates <nameToTrackIndexMap> accordingly; there should be
    -- exactly one media item with one take here, otherwise this track
    -- is ignored

    Logging.trace(">>: %s", track:name())

    -- make sure that there is exactly one media item with one take
    -- containing MIDI data
    local isOkay, mediaItem, take =
        checkForSingleItemAndMidiTake(track)

    if not isOkay then
        Logging.trace("--: skipped")
    else
        local takeName = take:name()
        nameToTrackIndexMap:set(takeName, trackIndex)
        Logging.trace("--: %s -> %d", takeName, trackIndex)
    end

    Logging.trace("<<")
end

-- --------------------
-- --------------------

function main ()
    Logging.trace(">>")

    Logging.trace("--: MidiEventList = %s", Reaper.MidiEventList)

    local message
    local project = Reaper.Project.current()
    local midiFileName, startTime = findMidiFileFromTracks(project)
    local fileExists = (midiFileName ~= nil
                        and OperatingSystem.hasFile(midiFileName))

    if midiFileName == nil then
        message = "Could not find any file name in MIDI tracks"
    elseif not fileExists then
        message = "Could not find file: " .. midiFileName
    else
        local isOkay = updateMidiTracks(project, midiFileName, startTime)
        message = iif(isOkay, "Import done.", "Import cancelled.")
    end
    
    _showMessage(message)
    Logging.trace("<<")
end

-- =======================

_initialize()
main()
_finalize()
