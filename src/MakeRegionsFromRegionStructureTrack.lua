-- makeRegionsFromStructureTrack - makes regions from items in STRUCTURE track
--                                 (if any) and also reuses coloring; also the
--                                 vice versa transformation is available
--
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

local _, scriptPath = reaper.get_action_context()
local scriptDirectory = scriptPath:match('^.+[\\//]')
package.path = scriptDirectory .. "?.lua"

require("List")
require("Logging")
require("Map")
require("Reaper")
require("OperatingSystem")

-- =======================

function _initialize ()
    Logging:initialize()
    local directoryPath =
        OperatingSystem.selectDirectory("/tmp", "REAPERLOGS", "TEMP", "TMP")

    if directoryPath ~= nil then
        Logging.setFileName(directoryPath .. "/reaper_makeRegions.log")
    end
end

-- --------------------

function _finalize ()
    Logging.finalize()
end

-- =======================

local _structureTrackName = "STRUCTURE"

-- --------------------

function deleteAllMediaItems (track)
    -- Gets rid of all existing media items in <track>

    Logging.trace(">>")

    local mediaItemList = track:mediaItemList()

    for _, mediaItem in mediaItemList:iterator() do
        mediaItem:delete()
    end

    Logging.trace("<<")
end

-- --------------------

function deleteAllRegions (project)
    -- Gets rid of all existing regions/markers in <project>

    Logging.trace(">>")

    local regionList = project:regionList()
    regionList:applyToAll(Reaper.Region.delete)

    Logging.trace("<<")
end

-- ------------------

function findStructureTrackList (project)
    -- Returns list of all tracks with name equals to
    -- <_structureTrackName> in <project (hopefully just a single one)

    Logging.trace(">>: %s", project)
    local hasStructureNameProc =
              function (track)
                  return track:name() == _structureTrackName
              end
    local result = project:trackList():filter(hasStructureNameProc)

    Logging.trace("<<: %s", result)
    return result
end

-- --------------------

function makeMediaItemForRegion (region, track)
    -- Makes media item from structure-defining <region> in
    -- <track>
    
    Logging.trace(">>: region = %s", region)

    local regionColor   = region:color()
    local regionName    = region:name()
    local startPosition = region:startPosition()
    local endPosition   = region:endPosition()

    local mediaItem = Reaper.MediaItem:make(track)
    local take = mediaItem:takeByIndex(1)
    take:setName(regionName)
    mediaItem:setColor(regionColor)
    mediaItem:setStartPosition(startPosition)
    mediaItem:setEndPosition(endPosition)
    Logging.trace("<<")
end

-- --------------------

function makeRegionForItem (project, mediaItem)
    -- Makes region from structure-defining <mediaItem> within
    -- <project>
    
    Logging.trace(">>: project = %s, mediaItem = %s",
                  project, mediaItem)

    local mediaItemColor = mediaItem:color()

    -- use the first take from media item      
    local take = mediaItem:takeByIndex(1)
    local takeName = take:name()
    local startPosition = take:startPosition()
    local endPosition = take:endPosition()

    local region = Reaper.Region:make(project)
    region:setName(takeName)
    region:setColor(mediaItemColor)
    region:setEndPosition(endPosition)
    region:setStartPosition(startPosition)

    Logging.trace("<<")
end

-- ------------------

function processRegionList (project)
    -- Converts region in <project> to an item in STRUCTURE track

    Logging.trace(">>: %s", project)

    local structureTrack
    local structureTrackList = findStructureTrackList(project)

    if not structureTrackList:isEmpty() then
        structureTrack = structureTrackList:first()
    else
        Logging.trace("--: no structure track found")
        structureTrack = Reaper.Track:make(project, 1)
        structureTrack:setName(_structureTrackName)
    end

    local regionList = project:regionList()

    -- insert a corresponding media item for each region
    deleteAllMediaItems(structureTrack)

    for _, region in regionList:iterator() do
        makeMediaItemForRegion(region, structureTrack)
    end

    Logging.trace("<<")
end

-- ------------------

function processStructureTrack (project)
    -- Scans current project for STRUCTURE track and converts each
    -- item to a region

    Logging.trace(">>: %s", tostring(project))

    local structureTrackList = findStructureTrackList(project)

    if structureTrackList:isEmpty() then
        Logging.trace("--: no structure track found")
    else
        local structureTrack = structureTrackList:first()
        local mediaItemList = structureTrack:mediaItemList()

        -- insert a corresponding region for each media item
        deleteAllRegions(project)

        for _, mediaItem in mediaItemList:iterator() do
            makeRegionForItem(project, mediaItem)
        end
    end

    Logging.trace("<<")
end

-- --------------------

function main()
    Logging.trace(">>")

    local message = "Create regions (or else create a structure track)?"
    local title = "Song Structure Marking:"
    local messageBoxKind = Reaper.UI.MessageBoxKind.yesNoCancel
    local answer = Reaper.UI.showMessageBox(message, title, messageBoxKind)
    local project = Reaper.Project.current()
    local isProcessed = true

    if answer == Reaper.UI.MessageBoxAnswerKind.yes then
        processStructureTrack(project)
    elseif answer == Reaper.UI.MessageBoxAnswerKind.no then
        processRegionList(project)
    else
        isProcessed = false
    end

    if isProcessed then
        Reaper.UI.updateTimeline()
        Reaper.UI.showMessageBox("Done.", title, Reaper.UI.MessageBoxKind.ok)
    end

    Logging.trace("<<")
end

-- --------------------

_initialize()
main()
_finalize()
