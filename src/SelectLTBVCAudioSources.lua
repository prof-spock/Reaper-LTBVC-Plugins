-- -*- coding: utf-8 -*- 
-- selectLTBVCAudioSources -- allows the simple selection of the audio
--                            source for each voice by a selection
--                            dialog in a Reaper project conforming to
--                            LTBVC conventions (for example, to
--                            compare the rendering of the MIDI or raw
--                            audio file with the refined audio file
--                            in the final mix)
--
-- author: Dr. Thomas Tensi, 2024-07

local _, scriptPath = reaper.get_action_context()
local scriptDirectory = scriptPath:match('^.+[\\//]')
package.path = scriptDirectory .. "?.lua"

-- =======
-- IMPORTS
-- =======

require("math")

require("Logging")
require("LTBVCConfiguration")
require("Map")
require("OperatingSystem")
require("Reaper")
require("ReaperGraphics")
require("Set")
require("String")

-- =======================

local _programName = "selectLTBVCAudioSources"
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

local _voiceNameToTrackListMap = Map:make()
  -- mapping from voice name to associated tracks with STRUCTURED
  -- MIDI, GENERATED MIDI, RAW AUDIO, EFFECTS and REFINED AUDIO

-- =======================
-- MODULES
-- =======================

local _TrackKind = {}

-- =================
-- module _TrackKind
-- =================
    -- This module provides access to the kinds of tracks available in
    -- an LTBVC configuration in Reaper

    -- special track kinds
    _TrackKind.effects = nil
    _TrackKind.final   = nil

    -- the list of all track kinds to be presented in the selection dialog
    _TrackKind.list      = nil

    -- the list of all track kinds including effects and final track
    _TrackKind.fullList  = nil

    -- the corresponding list of name patterns for the track kinds
    _TrackKind.namePatternList = nil

    -- the name pattern for the final track
    _TrackKind.namePatternFinal = nil

    -- the set of track kinds with direct connection to effects track
    _TrackKind.effectsTrackSourcesSet = Set:make()

    -- --------------------

    function _TrackKind.initializeFromConfiguration ()
        -- Gets track name patterns from configuration file and also the
        -- special track kinds for effects and the final track

        local fName = "_TrackKind.initializeFromConfiguration"
        Logging.traceF(fName, ">>")

        local patternToHeaderProc =
            function (pattern)
                return _TrackKind.fullList:at(
                           _TrackKind.namePatternList:find(pattern))
            end

        local trackNamePatternList, trackKindHeaderList,
              trackNamePatternSentToEffectsSet,
              trackNamePatternForVoiceEffects, trackNamePatternForVoiceFinal =
            LTBVCConfiguration.selectionDialogTrackNameData()

        _TrackKind.list            = trackKindHeaderList
        _TrackKind.fullList        = trackKindHeaderList:clone()
        _TrackKind.namePatternList = trackNamePatternList

        Logging.traceF(fName,
                       "--: headerList = %s, fullHeaderList = %s,"
                       .. " namePatternList = %s",
                       _TrackKind.list, _TrackKind.fullList,
                       _TrackKind.namePatternList)

        -- add the voice effects and voice final track kind to full
        -- list unless already available
        local patternList =
            List:makeFromArray({ trackNamePatternForVoiceEffects,
                                 trackNamePatternForVoiceFinal })

        Logging.traceF(fName, "--: patternList = %s", patternList)

        for _, pattern in patternList:iterator() do
            if not _TrackKind.namePatternList:contains(pattern) then
                _TrackKind.namePatternList:append(pattern)
                local header =
                    iif(pattern == trackNamePatternForVoiceEffects,
                        "EFF", "$$F")
                _TrackKind.fullList:append(header)
            end
        end     

        _TrackKind.effects =
            patternToHeaderProc(trackNamePatternForVoiceEffects)
        _TrackKind.final =
            patternToHeaderProc(trackNamePatternForVoiceFinal)
        _TrackKind.namePatternFinal = trackNamePatternForVoiceFinal

        -- construct the set of track kinds routed to the effects track
        _TrackKind.effectsTrackSourcesSet = Set:make()

        for _, namePattern in trackNamePatternSentToEffectsSet:iterator() do
            local header = patternToHeaderProc(namePattern)
            _TrackKind.effectsTrackSourcesSet:include(header)
        end

        Logging.traceF(fName,
                       "--: headerList = %s, fullHeaderList = %s,"
                      .. " patternList = %s, trackKindWithEffectsSet = %s,"
                      .. " effectsTrackKind = '%s',  finalTrackKind = '%s'",
                      _TrackKind.list, _TrackKind.fullList,
                      _TrackKind.namePatternList,
                      _TrackKind.effectsTrackSourcesSet,
                      _TrackKind.effects, _TrackKind.final)

        Logging.traceF(fName, "<<")
    end

-- ==============
-- end _TrackKind
-- ==============


-- ======================
-- module _SettingsDialog
-- ======================

    local _SettingsDialog__idleDuration = 0
        -- the maximum idle duration of the settings dialog

    local _SettingsDialog__isDone = false
        -- tells whether settings dialog is completed

    local _SettingsDialog__mouseButtonLeftIsDown = false
       -- the mouse left button state

    local _SettingsDialog__voiceNameList = nil
       -- the list of displayed voice names
    
    local _SettingsDialog__trackKindList = nil
       -- the list of displayed track kinds

    -- additional track kinds
    local _SettingsDialog__trackKindSolo = "SOL"
    local _SettingsDialog__trackKindMute = "MTE"

    -- dialog geometry settings
    local _SettingsDialog__leftRightMargin  =  20
    local _SettingsDialog__topBottomMargin  =  20
    local _SettingsDialog__cellSize         = nil
    local _SettingsDialog__cellHeightFactor = 1.5
    local _SettingsDialog__cellWidthFactor  = 1.3
    local _SettingsDialog__tickMarkSize     =   5

    -- logical BGR colors
    local _SettingsDialog__colorBackground     = ReaperGraphics.Color.white
    local _SettingsDialog__colorText           = ReaperGraphics.Color.black
    local _SettingsDialog__colorBlockStd       = 0x006000
    local _SettingsDialog__colorBlockHollow    = ReaperGraphics.Color.black
    local _SettingsDialog__colorBlockMute      = ReaperGraphics.Color.red
    local _SettingsDialog__colorBlockSolo      = ReaperGraphics.Color.yellow
    local _SettingsDialog__colorGridLine       = ReaperGraphics.Color.lightGray
    local _SettingsDialog__colorGridBorderLine = ReaperGraphics.Color.darkGray

    local _SettingsDialog__fontStandard = nil
    local _SettingsDialog__fontBold     = nil

    local _SettingsDialog__fontName = "Arial"
    local _SettingsDialog__fontHeight = 20
    
    local _SettingsDialog__clickArea = nil
        -- the rectangle where mouse clicks are accepted

    local _SettingsDialog__cellFillRatio = 0.6
        -- ratio for filling (in one dimension only)

    local _SettingsDialog__window = nil
        -- the dialog window shown
    
    -- --------------------

    function _SettingsDialog__handleMouse ()
        -- checks whether left mouse button has been pressed and
        -- updates the source track accordingly; returns whether some
        -- successful click has been done

        Logging.trace(">>")

        local result = false
        local mouseStatus = ReaperGraphics.Mouse.status()
        Logging.trace("--: buttonIsDown = %s, shiftIsPressed = %s",
                      mouseStatus.leftMouseButtonIsDown,
                      mouseStatus.shiftKeyIsPressed)

        if (mouseStatus.leftMouseButtonIsDown
            and not _SettingsDialog__mouseButtonLeftIsDown) then
            local mousePosition = ReaperGraphics.Mouse.position()
            Logging.trace("--: mouse click at %s", mousePosition)
            local clickArea = _SettingsDialog__clickArea

            -- is mouse click in the matrix?
            if clickArea:contains(mousePosition) then
                Logging.trace("--: click is relevant")
                result = true
                local columnIndex, rowIndex =
                    clickArea:cell(mousePosition, _SettingsDialog__cellSize)
                local voiceName = _SettingsDialog__voiceNameList:at(rowIndex)
                local trackKind = _SettingsDialog__trackKindList:at(columnIndex)
                _SettingsDialog__switchVoiceToTrack(
                    voiceName, trackKind, mouseStatus.shiftKeyIsPressed)
            end
        end

        _SettingsDialog__mouseButtonLeftIsDown =
            mouseStatus.leftMouseButtonIsDown
            
        Logging.trace("<<: %s", result)
        return result
    end

    -- --------------------

    function _SettingsDialog_initializeVoicesAndTrackKinds ()
        -- Initializes the list of voices and the list of allowed
        -- track kinds

        Logging.trace(">>")

        _SettingsDialog__voiceNameList =
            List:makeFromIterable(_voiceNameToTrackListMap:keySet())
        local comparisonProc = function (a, b)  return a < b  end
        _SettingsDialog__voiceNameList:sort(comparisonProc)

        -- calculate effective track kind list for the dialog
        local trackKindList = _TrackKind.list:clone()
        trackKindList:prepend(_SettingsDialog__trackKindSolo)
        trackKindList:prepend(_SettingsDialog__trackKindMute)
        _SettingsDialog__trackKindList = trackKindList

        Logging.trace("--: voiceNameList = %s, trackKindList = %s",
                      _SettingsDialog__voiceNameList,
                      _SettingsDialog__trackKindList)

        Logging.trace("<<")
    end

    -- --------------------

    function _SettingsDialog__switchVoiceToTrack (voiceName,
                                                  trackKind,
                                                  shiftIsPressed)
        -- Changes audio source for voice with <voiceName> to track
        -- with <trackKind>; if <shiftIsPressed> is set, the existing
        -- tracks are not changed, but the new one is toggled

        Logging.trace(">>: voiceName = '%s', trackKind = '%s'",
                      voiceName, trackKind)

        local voiceNameToDataMap = _voiceNameToTrackListMap:at(voiceName)

        if voiceNameToDataMap ~= nil then
            if trackKind == _TrackKind.effects then
                Logging.trace("--: skipped effect track")
            elseif (trackKind == _SettingsDialog__trackKindSolo
                    or trackKind == _SettingsDialog__trackKindMute) then
                -- change status of final track for that voice
                local finalTrack = voiceNameToDataMap:at(_TrackKind.final)

                if finalTrack == nil then
                    Logging.trace("--: skipped empty final track")
                elseif trackKind == _SettingsDialog__trackKindMute then
                    finalTrack:setMuted(not finalTrack:isMuted())
                else
                    finalTrack:setSoloed(not finalTrack:isSoloed())
                end
            else
                local selectedTrack = voiceNameToDataMap:at(trackKind)

                if selectedTrack ~= nil then
                    -- mute all tracks associated with <voiceName>
                    -- (except for the final track) unless
                    -- <existingTracksAreKept> is set
                    Logging.trace("--: selectedTrack = %s", selectedTrack)

                    if not shiftIsPressed then
                        local trackList = voiceNameToDataMap:valueSet()

                        for _, track in trackList:iterator() do
                            local isFinalTrack =
                                track:name():find(_TrackKind.namePatternFinal)

                            if not isFinalTrack then
                                Logging.trace("--: mute track %s", track)
                                track:setMuted(true)
                            end
                        end
                    end

                    -- unmute track with <trackKind> and the effects track
                    -- (if needed)
                    local trackKindList = List:make()
                    trackKindList:append(trackKind)

                    if _TrackKind.effectsTrackSourcesSet:contains(trackKind) then
                        trackKindList:append(_TrackKind.effects)
                    end

                    for _, activeTrackKind in trackKindList:iterator() do
                        Logging.trace("--: activeTrackKind = '%s'",
                                      activeTrackKind)
                        local activeTrack =
                            voiceNameToDataMap:at(activeTrackKind)

                        if activeTrack == nil then
                            Logging.traceError("cannot find track for %s",
                                               activeTrackKind)
                        else
                            Logging.trace("--: unmute track %s", activeTrack)
                            local isMuted = iif(shiftIsPressed,
                                                not activeTrack:isMuted(),
                                                false)
                            activeTrack:setMuted(isMuted)
                        end
                    end
                end
            end
        end

        Logging.trace("<<")
    end

    -- --------------------

    function _SettingsDialog__update ()
        -- updates the settings dialog with the current active tracks
        -- for all voices

        Logging.trace(">>")

        ReaperGraphics.setBackgroundColor(_SettingsDialog__colorBackground)
        _SettingsDialog__writeHeader()
        _SettingsDialog__writeVoiceDataLine()
        _SettingsDialog__writeGrid()
        
        _SettingsDialog__isDone = (gfx.getchar() == -1)
        local dataHasChanged = _SettingsDialog__handleMouse()
        _SettingsDialog__window:update()
        
        Logging.trace("<<")

        if dataHasChanged then
            -- restart idle timer
            local idleDialogDuration = _SettingsDialog__idleDialogDuration
            Reaper.Coroutine.setMaximumDialogDuration(idleDialogDuration)
        end

        Reaper.Coroutine.yield(_SettingsDialog__update,
                               _SettingsDialog__isDone)
    end

    -- --------------------

    function _SettingsDialog__windowSize (fontForVoiceNames)
        -- Returns the optimal size of the settings dialog window

        Logging.trace(">>: %s", fontForVoiceNames)

        -- maximum string width for some font in list
        maximumStringWidthProc =
            function (font, stringList)
                local maximumWidth = 0
                local maximumWidthString = ""

                for _, st in stringList:iterator() do
                    local width, _ = font:stringSize(st):unpack()

                    if width > maximumWidth then
                        maximumWidth = width
                        maximumWidthString = st
                    end
                end

                return maximumWidth, maximumWidthString
            end

        -- find maximum width voice name and its length
        local maximumVoiceNameWidth, maximumWidthVoiceName =
            maximumStringWidthProc(fontForVoiceNames,
                                   _SettingsDialog__voiceNameList)
        Logging.trace("--: longest voice name = '%s', width = %d",
                      maximumWidthVoiceName, maximumVoiceNameWidth)

        -- find maximum width track kind name and its length
        local maximumTrackKindWidth, maximumWidthTrackKind =
            maximumStringWidthProc(fontForVoiceNames,
                                   _SettingsDialog__trackKindList)
        Logging.trace("--: longest track kind name = '%s', width = %d",
                      maximumWidthTrackKind, maximumTrackKindWidth)

        -- adjust cell size
        _SettingsDialog__cellSize =
            fontForVoiceNames
                :stringSize(maximumWidthTrackKind)
                :scaledBy(_SettingsDialog__cellWidthFactor,
                          _SettingsDialog__cellHeightFactor)

        -- calculate click area: a row for each voice and a column for
        -- each track kind (including mute and solo)
        local columnCount = _SettingsDialog__trackKindList:count()
        local rowCount    = _SettingsDialog__voiceNameList:count()

        local x = maximumVoiceNameWidth + 2 * _SettingsDialog__leftRightMargin
        local y = (_SettingsDialog__topBottomMargin
                   + math.floor(_SettingsDialog__cellSize.height
                                * _SettingsDialog__cellHeightFactor))
        local clickAreaSize =
            _SettingsDialog__cellSize:scaledBy(columnCount, rowCount)
        local clickArea =
            ReaperGraphics.Rectangle:make(x, y, clickAreaSize:unpack())

        -- calculate window size (using click area)
        local windowWidth  = (clickArea.x
                              + clickArea.width
                              + _SettingsDialog__leftRightMargin)
        local windowHeight = (clickArea.y
                              + clickArea.height
                              + _SettingsDialog__topBottomMargin)
        local windowSize =
            ReaperGraphics.Size:make(windowWidth, windowHeight)
        
        Logging.trace("<<: windowSize = %s, clickArea = %s",
                      windowSize, clickArea)
        return windowSize, clickArea
    end

    -- --------------------

    function _SettingsDialog__writeHeader ()
        -- writes the heading for the settings dialog   

        Logging.trace(">>")

        local x, y, deltaX =
            _SettingsDialog__clickArea.x,
            _SettingsDialog__topBottomMargin,
            _SettingsDialog__cellSize.width

        x = x + deltaX / 2
        _SettingsDialog__fontBold:activate()
        ReaperGraphics.setColor(_SettingsDialog__colorText)
        local hAlignment = ReaperGraphics.Alignment.hCentered

        for _, trackKind in _SettingsDialog__trackKindList:iterator() do
            _SettingsDialog__window:drawString(x, y, trackKind, hAlignment)
            x = x + deltaX
        end

        Logging.trace("<<")
    end

    -- --------------------

    function _SettingsDialog__writeGrid ()
        -- Writes grid in click area to separate click cells

        Logging.trace(">>")

        local xOffset, yOffset, startPosition, endPosition
        local x0, y0, clickAreaWidth, clickAreaHeight =
            _SettingsDialog__clickArea.x,
            _SettingsDialog__clickArea.y,
            _SettingsDialog__clickArea.width,
            _SettingsDialog__clickArea.height
        local cellWidth, cellHeight, tickMarkSize =
            _SettingsDialog__cellSize.width,
            _SettingsDialog__cellSize.height,
            _SettingsDialog__tickMarkSize
        
        writeLines =
            function (x, y, deltaX, deltaY, lineX, lineY, count)
                local startPoint, deltaSize, lineSize =
                    ReaperGraphics.Point:make(x, y),
                    ReaperGraphics.Size:make(deltaX, deltaY),
                    ReaperGraphics.Size:make(lineX, lineY)
                _SettingsDialog__writeLineSequence (startPoint, deltaSize,
                                                    lineSize, count)
            end

        -- == INTERNAL LINES ==
        ReaperGraphics.setColor(_SettingsDialog__colorGridLine)

        -- draw the vertical internal lines

        writeLines(x0 + cellWidth, y0, cellWidth, 0, 0, clickAreaHeight,
                   clickAreaWidth // cellWidth - 1)

        -- draw the horizontal internal lines
        writeLines(x0, y0 + cellHeight, 0, cellHeight, clickAreaWidth, 0,
                   clickAreaHeight // cellHeight - 1)

        -- == BORDER LINES ==
        ReaperGraphics.setColor(_SettingsDialog__colorGridBorderLine)

        -- draw the vertical tick mark lines and the vertical border
        writeLines(x0, y0 - tickMarkSize, cellWidth, 0, 0, tickMarkSize,
                   clickAreaWidth // cellWidth + 1)

        writeLines(x0, y0, clickAreaWidth, 0, 0, clickAreaHeight, 2)

        -- draw the horizontal tick mark lines and the horizontal
        -- border
        writeLines(x0 - tickMarkSize, y0, 0, cellHeight, tickMarkSize, 0,
                   clickAreaHeight // cellHeight + 1)

        writeLines(x0, y0, 0, clickAreaHeight, clickAreaWidth, 0, 2)

        -- draw separation between mute/solo and normal tracks
        for i = 0, 2 do
            local x = x0 + 2 * cellWidth + i - 1
            local color = iif(i == 1,
                              _SettingsDialog__colorBackground,
                              _SettingsDialog__colorGridBorderLine)

            ReaperGraphics.setColor(color)
            _SettingsDialog__window:drawLine(x, y0 + 1,
                                             x, y0 + clickAreaHeight - 1)
        end

        Logging.trace("<<")
    end

    -- --------------------

    function _SettingsDialog__writeLineSequence (startPoint,
                                                 deltaSize,
                                                 lineSize,
                                                 count)
        -- Draws lines from <start> with <lineSize> and
        -- increments position by <delta> for <count> - 1 times

        Logging.trace(">>: startPoint = %s, deltaSize = %s,"
                      .. " lineSize = %s, count = %d",
                      startPoint, deltaSize, lineSize, count)

        local endPoint = startPoint:plus(lineSize)

        for i = 1, count do
            _SettingsDialog__window:drawLine(startPoint.x, startPoint.y,
                                             endPoint.x, endPoint.y)
            startPoint:increment(deltaSize)
            endPoint:increment(deltaSize)
        end

        Logging.trace("<<")
    end

    -- --------------------

    function _SettingsDialog__writeVoiceDataLine ()
        -- writes voices names and their active sources to window
        
        Logging.trace(">>")

        local x, y, deltaX, deltaY =
            _SettingsDialog__leftRightMargin,
            _SettingsDialog__clickArea.y,
            _SettingsDialog__cellSize.width,
            _SettingsDialog__cellSize.height

        local factorA, factorB, cellWidth, cellHeight =
            _SettingsDialog__cellFillRatio,
            (1 - _SettingsDialog__cellFillRatio) / 2,
            _SettingsDialog__cellSize.width,
            _SettingsDialog__cellSize.height

        local currentDialog = _SettingsDialog__window
        
        Logging.trace("--: x = %s, y = %s, deltaX = %s, deltaY = %s",
                      x, y, deltaX, deltaY)
        
        for _, voiceName in _SettingsDialog__voiceNameList:iterator() do
            _SettingsDialog__fontBold:activate()
            ReaperGraphics.setColor(_SettingsDialog__colorText)
            currentDialog:drawString(x, y, voiceName)

            x = _SettingsDialog__clickArea.x
            local voiceNameToDataMap =
                _voiceNameToTrackListMap:at(voiceName)
            _SettingsDialog__fontStandard:activate()

            for _, trackKind in _SettingsDialog__trackKindList:iterator() do
                local track
                local columnIsMarked = false
                local isFinalTrackMarker =
                    (trackKind == _SettingsDialog__trackKindSolo
                     or trackKind == _SettingsDialog__trackKindMute)
                local markerIsUnclickable = false
                local markerColor

                if not isFinalTrackMarker then
                    -- check whether associated audio track is active
                    track = voiceNameToDataMap:at(trackKind)

                    if track ~= nil then
                        columnIsMarked = not track:isMuted()
                        local isEffectsTrack =
                            trackKind == _TrackKind.effects
                        markerIsUnclickable = isEffectsTrack
                        markerColor = iif(isEffectsTrack,
                                          _SettingsDialog__colorBlockHollow,
                                          _SettingsDialog__colorBlockStd)
                    end
                else
                    -- get mute or solo status from final track
                    track = voiceNameToDataMap:at(_TrackKind.final)

                    if track ~= nil then
                        local isTrackKindMute =
                            trackKind == _SettingsDialog__trackKindMute
                        columnIsMarked = iif(isTrackKindMute,
                                             track:isMuted(),
                                             track:isSoloed())
                        markerColor = iif(isTrackKindMute,
                                          _SettingsDialog__colorBlockMute,
                                          _SettingsDialog__colorBlockSolo)
                    end
                end

                local rectangle =
                    ReaperGraphics.Rectangle:make(
                        x + math.floor(factorB * cellWidth),
                        y + math.floor(factorB * cellHeight),
                        math.floor(factorA * cellWidth),
                        math.floor(factorA * cellHeight))

                if track == nil then
                    -- draw a cross in <rectangle>
                    ReaperGraphics.setColor(_SettingsDialog__colorBlockHollow)
                    currentDialog:drawLine(rectangle.x,
                                           rectangle.y + rectangle.height,
                                           rectangle.x + rectangle.width,
                                           rectangle.y)
                    currentDialog:drawLine(rectangle.x,
                                           rectangle.y,
                                           rectangle.x + rectangle.width,
                                           rectangle.y + rectangle.height)
                elseif columnIsMarked then
                    ReaperGraphics.setColor(markerColor)

                    if isFinalTrackMarker then
                        -- currentDialog:drawEllipse(rectangle, true)
                        currentDialog:drawRectangle(rectangle, true)
                    else
                        currentDialog:drawRectangle(rectangle,
                                                    not markerIsUnclickable)
                    end
                end
                
                x = x + deltaX
            end

            -- start new row
            x = _SettingsDialog__leftRightMargin
            y = y + deltaY
        end

        Logging.trace("<<")
        return x, y
    end

    -- --------------------
    -- --------------------

    function _SettingsDialog_show (idleDialogDuration)
        -- Displays the current active tracks for all voices with an
        -- idle dialog duration of this dialog of <idleDialogDuration>

        Logging.trace(">>: %s", idleDialogDuration)

        _SettingsDialog__idleDialogDuration = idleDialogDuration
        Reaper.Coroutine.setMaximumDialogDuration(idleDialogDuration)   

        _SettingsDialog_initializeVoicesAndTrackKinds()

        local fontName   = _SettingsDialog__fontName
        local fontHeight = _SettingsDialog__fontHeight

        _SettingsDialog__fontStandard =
            ReaperGraphics.Font:make(1, fontName, fontHeight)
        _SettingsDialog__fontBold =
            ReaperGraphics.Font:make(2, fontName, fontHeight, "b")
       
        local windowSize, clickArea =
            _SettingsDialog__windowSize(_SettingsDialog__fontBold)
        _SettingsDialog__clickArea = clickArea
        local boundingRectangle =
            ReaperGraphics.Rectangle:make(300, 300,
                                          windowSize.width, windowSize.height)
        _SettingsDialog__window =
            ReaperGraphics.Dialog:make("Voice Sources", boundingRectangle)
        _SettingsDialog__update()

        Logging.trace("<<")
    end

-- ===================
-- end _SettingsDialog
-- ===================

function _updateVoiceNameToDataMap (trackList)
    -- updates internal data from <trackList>

    Logging.trace(">>: %s", trackList)

    for _, track in trackList:iterator() do
        local trackName = track:name()
        Logging.trace("--: processing '%s'", trackName)

        for i, trackKind in _TrackKind.fullList:iterator() do
            Logging.trace("--: processing trackKind '%s'", trackKind)
            local trackNamePattern = _TrackKind.namePatternList:at(i)
            local isRelevant, _, voiceName = trackName:find(trackNamePattern)

            if isRelevant then
                -- also check whether parent track has some send
                -- connection; if yes, do not include this track at all
                local parentTrack = track:parent()

                if parentTrack ~= nil then
                    local parentTrackName = parentTrack:name()
                    local _, parentConnectionSettings =
                        LTBVCConfiguration
                            .trackInputOutputSettingsByTrackName(parentTrackName  )
                    local parentSendIsEnabled =
                        parentConnectionSettings ~= nil
                    isRelevant = not parentSendIsEnabled
                end
            end
            
            if isRelevant then
                if not _voiceNameToTrackListMap:hasKey(voiceName) then
                    Logging.trace("--: new voice '%s'", voiceName)
                    _voiceNameToTrackListMap:set(voiceName, Map:make())
                end

                local voiceNameData = _voiceNameToTrackListMap:at(voiceName)
                voiceNameData:set(trackKind, track)
                Logging.trace("--: trackForVoice('%s', '%s') = %s",
                              voiceName, trackKind, track)
            end
        end
    end

    Logging.trace("--: voiceNameToDataMap = %s", _voiceNameToTrackListMap)
    
    Logging.trace("<<")
end

-- --------------------

function main ()
    Logging.trace(">>")

    local project = Reaper.Project.current()
    _TrackKind.initializeFromConfiguration()

    local trackList = project:trackList()
    _updateVoiceNameToDataMap(trackList)

    Reaper.Coroutine.atExit(_finalize)
    local idleDialogDuration =
        LTBVCConfiguration.selectionDialogIdleDuration()
    _SettingsDialog_show(idleDialogDuration)

    Logging.trace("<<")
end

-- =======================

_initialize()
main()
