-- Lilypond - provides services for generating lilypond note
--            strings from MIDI data
--
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

require("List")
require("Logging")
require("Map")
require("math")
require("Set")
require("String")

-- =======================

-- --------------------
-- configuration
-- --------------------

-- the base-2-logarithm of the smallest note supported:
-- here a 32nd triplet note is the smallest supported note
local _log2MinimumNoteLength = 5

-- the indentation count of the notes in a sequence (four blanks)
local _noteSequenceIndentation = 4

-- -----------------------------
-- class and module declarations
-- -----------------------------

local Note          = Class:make("Note")
local NoteGroup     = Class:make("NoteGroup")
local NoteGroupList = Class:make("NoteGroupList")
local SplitHandler  = {}

Lilypond      = {}

-- ===============
-- module Lilypond
-- ===============
    -- This module provides services for generating lilypond note
    -- strings from MIDI data.


    -- ===================
    -- module SplitHandler
    -- ===================
        -- This module provides a service for calculating the split
        -- point of some note group within a measure at a relative
        -- position within the measure.  It is based on a list of
        -- possible durations for plain notes, dotted notes, triplets
        -- and dotted triplets.

        -- --------------------
        -- local features
        -- --------------------

        SplitHandler._measurePositionToDurationsMap = nil
            -- Maps position within measure to allowed note durations

        SplitHandler._durationToComplexityMap = nil
            -- Maps allowed note durations to complexity value; a
            -- plain undotted duration (like e.g. a quarter) has a
            -- complexity of 2, a dotted note has complexity 3 and a
            -- triplet complexity 4; this is used to put a preference
            -- on those duration splits where durations are used that
            -- are simple

        SplitHandler._adaptedNotationIsUsed = nil
            -- tells whether a duration should be split according to
            -- notation practice

        -- --------------------

        function SplitHandler._durationComplexity (duration)
            -- Returns complexity for <duration>

            local fName = "Lilypond.SplitHandler._durationComplexity"
            Logging.traceF(fName, ">>: %d", duration)

            local result

            if SplitHandler._durationToComplexityMap:hasKey(duration) then
                result = SplitHandler._durationToComplexityMap:at(duration)
            else
                result = infinity
            end

            Logging.traceF(fName, "<<: %d", result)
            return result
        end

        -- --------------------

        function SplitHandler._findDurations (maximumSequenceLength,
                                              relativePositionInMeasure,
                                              duration, isInTripletSequence,
                                              dottedIsOkay)
            -- Calculates split duration list for note group that
            -- occurs at <relativePositionInMeasure> in its measure
            -- such that all parts of this duration list are
            -- acceptable at their corresponding positions with list
            -- ordered descendingly; <maximumSequenceLength> tells how
            -- long a split may be at most; <isInTripletSequence>
            -- tells whether list shall start in triplet or normal
            -- context; <dottedIsOkay> tells whether dots may occur in
            -- note lengths; tries to find the shortest possible list
            -- and returns that and the final context kind

            local fName = "Lilypond.SplitHandler._findDurations"
            Logging.traceF(fName,
                           ">>: relativePosition = %d, duration = %d, "
                           .. " maxSeqLength = %d, inTripletSeq = %s,"
                           .. " dottedIsOkay = %s",
                           relativePositionInMeasure, duration,
                           maximumSequenceLength, isInTripletSequence,
                           dottedIsOkay)

            local makeEmptyResultProc = function ()
                                            local r = Map:make()
                                            r.list          = List:make()
                                            r.complexity    = infinity
                                            r.endsAsTriplet = false
                                            return r
                                        end

            local result

            if maximumSequenceLength == 0 then
                result = makeEmptyResultProc()
            else
                local resultA =
                          SplitHandler._findDurationsForOneVariant
                                           (maximumSequenceLength,
                                            relativePositionInMeasure,
                                            duration,
                                            isInTripletSequence,
                                            dottedIsOkay)
                local resultB =
                          SplitHandler._findDurationsForOneVariant
                                           (maximumSequenceLength,
                                            relativePositionInMeasure,
                                            duration,
                                            not isInTripletSequence,
                                            dottedIsOkay)

                if resultA.complexity < resultB.complexity then
                    result = resultA
                else
                    result = resultB
                end
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function SplitHandler._findDurationsForOneVariant
                                  (maximumSequenceLength,
                                   relativePositionInMeasure,
                                   duration, isInTripletSequence,
                                   dottedIsOkay)
            -- Calculates split duration list for note group that
            -- occurs at <relativePositionInMeasure> in its measure
            -- such that all parts of this duration list are
            -- acceptable at their corresponding positions with list
            -- ordered descendingly; <maximumSequenceLength> tells how
            -- long a split may be at most; <isInTripletSequence>
            -- tells whether list shall start in triplet or normal
            -- context; <dottedIsOkay> tells whether dots may occur in
            -- note lengths; tries to find the shortest possible list
            -- and returns that and the final context kind

            local fName =
                      "Lilypond.SplitHandler._findDurationsForOneVariant"
            Logging.traceF(fName,
                           ">>: relativePosition = %d, duration = %d, "
                           .. " maxSeqLength = %d, inTripletSeq = %s,"
                           .. " dottedIsOkay = %s",
                           relativePositionInMeasure, duration,
                           maximumSequenceLength, isInTripletSequence,
                           dottedIsOkay)

            local makeEmptyResultProc = function ()
                                            local r = Map:make()
                                            r.list          = List:make()
                                            r.complexity    = infinity
                                            r.endsAsTriplet = false
                                            return r
                                        end

            local selectionProc = function (element)
                                      return element <= duration
                                  end

            local result = makeEmptyResultProc()
            local key = SplitHandler.mptdmKey(relativePositionInMeasure,
                                              isInTripletSequence)
            local acceptableDurationList =
                     SplitHandler._measurePositionToDurationsMap:at(key)

            Logging.traceF(fName,
                           "--: calculating key = %s,"
                           .. " acceptable durations = %s",
                           key, acceptableDurationList)

            if acceptableDurationList ~= nil then
                -- traverse all acceptable durations that are
                -- less than or equal to given duration (if
                -- any)
                acceptableDurationList =
                    acceptableDurationList:select(selectionProc)

                for _, acceptableDuration
                           in acceptableDurationList:iterator() do
                    if acceptableDuration == duration then
                        Logging.traceF(fName,
                                       "--: duration found %d",
                                       duration)
                        result.list:set(1, duration)
                        result.complexity =
                            SplitHandler._durationComplexity(duration)
                        result.endsAsTriplet = isInTripletSequence
                        break
                    else
                        local position = (relativePositionInMeasure
                                          + acceptableDuration)
                        local remainingDuration = (duration
                                                   - acceptableDuration)
                        Logging.traceF(fName,
                                       "--: splitting after %d,"
                                       .. " remaining duration %d",
                                       acceptableDuration,
                                       remainingDuration)
                        local restResult =
                            SplitHandler._findDurations(
                                maximumSequenceLength - 1, position,
                                remainingDuration, isInTripletSequence,
                                dottedIsOkay)
                        local restResultLength = restResult.list:count()

                        if restResultLength == 0 then
                            Logging.traceF(fName,
                                           "--: no split possible")
                        else
                            restResult.list:prepend(acceptableDuration)
                            restResult.complexity =
                                (restResult.complexity
                                 + SplitHandler._durationComplexity(acceptableDuration))
                            Logging.traceF(fName,
                                           "--: split for %d = %s",
                                           duration, restResult)
                            local complexity = restResult.complexity

                            if complexity < result.complexity then
                                result = restResult
                            end
                        end
                    end
                end
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function SplitHandler._initForDuration (maximumMeasureDuration,
                                                duration,
                                                isTriplet, isDotted)
            -- Adds entries in measurePositionToDurationsMap for note with
            -- <duration> where properties are given by <isTriplet> and
            -- <isDotted>; <maximumMeasureDuration> tell the maximum length
            -- of a measure

            local fName = "Lilypond.SplitHandler._initForDuration"
            Logging.traceF(fName,
                           ">>: maxMeasureLength = %s, duration = %s,"
                           .. " isTriplet = %s, isDotted = %s",
                           maximumMeasureDuration, duration,
                           isTriplet, isDotted)

            local lastPosition = maximumMeasureDuration - duration
            local fillMap =
                      function (delta, s, t)
                          SplitHandler._initForPositions(lastPosition,
                                                         duration,
                                                         isTriplet,
                                                         delta, s, t)
                      end

            Logging.traceF(fName, "--: lastPosition = %d", lastPosition)

            if not isDotted then
                -- all multiples of <duration> are acceptable as
                -- start positions
                fillMap(1, 0, 1)

                if not isTriplet then
                    -- even multiples of <duration> at offbeat position are
                    -- okay
                    fillMap(4, 1, 2)
                else
                    -- a start at second or third triplet in first or second
                    -- super-node is okay
                    for delta = 0, 1 do
                        for s = 1, 2 do
                            fillMap(3 * delta, s, 3)
                        end
                    end
                end
            elseif not isTriplet then
                -- down or off beat positions in even super-nodes are okay
                for s = 0, 1 do
                    fillMap(2, s, 1)
                end
            else
                -- all multiples of <duration> are acceptable as
                -- start positions
                fillMap(1, 0, 1)
            end

            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function SplitHandler._initForPositions (lastPosition,
                                                 duration, isTriplet,
                                                 delta, s, t)
            -- Fills measurePositionToDurationsMap at raster positions
            -- given by multiples (<delta>*i+<s>)/<t> of <duration>

            local fName = "Lilypond.SplitHandler._initForPositions"
            Logging.traceF(fName,
                           ">>: lastPosition = %d, duration = %d,"
                           .. " isTriplet = %s, delta = %d, s = %s, t = %d",
                           lastPosition, duration, isTriplet, delta, s, t)

            local i = 0
            local isDone

            repeat
                local rasterPosition = duration * (delta * i + s) // t
                local isDone = (rasterPosition > lastPosition)

                if not isDone then
                    local key = SplitHandler.mptdmKey(rasterPosition,
                                                      isTriplet)
                    local durationList =
                          SplitHandler._measurePositionToDurationsMap:at(key)

                    if durationList == nil then
                        Logging.traceF(fName, "--: creating new")
                        durationList = List:make()
                        SplitHandler.
                            _measurePositionToDurationsMap:set(key,
                                                               durationList)
                    end

                    Logging.traceF(fName,
                                   "--: bPTDM(%s) += %d",
                                   key, duration)

                    if durationList:find(duration) == 0 then
                        durationList:append(duration)
                    end

                    i = i + 1
                end
            until isDone or delta == 0

            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function SplitHandler._mPosToDurationsMapString ()
            -- Returns string representation of
            -- <measurePositionToDurationsMap>

            local positionToTimeProc = function (st)
                                           local x = String.splitAt(st, "/")
                                           return x + 0
                                       end

            local comparisonProc = function (a, b)
                                       local aTime = positionToTimeProc(a)
                                       local bTime = positionToTimeProc(b)
                                       local result = iif(aTime ~= bTime,
                                                          (aTime < bTime),
                                                          (a < b))
                                       return result
                                   end

            local st = "{"
            local positionList =
                      SplitHandler._measurePositionToDurationsMap:keyList()
            local isFirst = true

            positionList:sort(comparisonProc)

            for _, position in positionList:iterator() do
                local durationList =
                    SplitHandler._measurePositionToDurationsMap:at(position)
                st = (st .. iif(isFirst, "", ", ") .. position .. " => "
                      .. tostring(durationList))
                isFirst = false
            end

            st = st .. "}"
            return st
        end

        -- --------------------
        -- exported features
        -- --------------------

        function SplitHandler.findDurations (relativePositionInMeasure,
                                             duration, isInTripletSequence,
                                             dottedIsOkay)
            -- Calculates split duration list for note group that
            -- occurs at <relativePositionInMeasure> in its measure
            -- such that all parts of this duration list are
            -- acceptable at their corresponding positions;
            -- <isInTripletSequence> tells whether list shall start in
            -- triplet or normal context; <dottedIsOkay> tells whether
            -- dots may occur in note lengths; tries to find the
            -- shortest possible list and returns that and the final
            -- context kind

            local fName = "Lilypond.SplitHandler.findDurations"
            Logging.traceF(fName,
                           ">>: relativePosition = %d, duration = %d,"
                           .. " isInTripletSequence = %s, dottedIsOkay = %s",
                           relativePositionInMeasure, duration,
                           isInTripletSequence, dottedIsOkay)

            local maximumNoteCount = 4
            local result =
                    SplitHandler._findDurations(maximumNoteCount,
                                                relativePositionInMeasure,
                                                duration, isInTripletSequence,
                                                dottedIsOkay)

            Logging.traceF(fName, "<<: result = %s", result)
            return result.list, result.endsAsTriplet
        end

        -- --------------------

        function SplitHandler.initialize (ticksPerQuarterNote,
                                          adaptedNotationIsUsed)
            -- Calculates the measure position to duration map from
            -- <ticksPerQuarterNote> that maps relative measure
            -- positions to lists of note durations that may occur at
            -- that position; <adaptedNotationIsUsed> tells whether
            -- notes should be split according to music notation
            -- conventions

            local fName = "Lilypond.SplitHandler.initialize"
            Logging.traceF(fName, ">>: tpq = %d, adaptedNotationIsUsed = %s",
                           ticksPerQuarterNote, adaptedNotationIsUsed)

            SplitHandler._adaptedNotationIsUsed = adaptedNotationIsUsed
            SplitHandler._measurePositionToDurationsMap = Map:make()
            SplitHandler._durationToComplexityMap = Map:make()

            local maximumMeasureDuration = 8 * ticksPerQuarterNote
            local referenceDuration = 4 * ticksPerQuarterNote

            for i = 0, _log2MinimumNoteLength do
                -- for each note length from whole to 32nd traverse
                -- over plain note, dotted note, triplet and dotted
                -- triplet

                Logging.traceF(fName, "--: note length = 1/%d", 2 ^ i)

                for j = 1, 2 do
                    for k = 1, 2 do
                        local isTriplet = (j == 2)
                        local isDotted  = (k == 2)
                        local duration = referenceDuration
                        duration = iif(isTriplet, duration * 2/3,
                                         duration)
                        duration = iif(isDotted,  duration * 3/2,
                                         duration)
                        SplitHandler._initForDuration(maximumMeasureDuration,
                                                      duration,
                                                      isDotted, isTriplet)

                        -- define complexity of a note length
                        local complexity = iif(isTriplet,
                                               iif(isDotted, 2, 4),
                                               iif(isDotted, 3, 2))
                        SplitHandler._durationToComplexityMap:set(duration,
                                                                  complexity)
                    end
                end

                referenceDuration = referenceDuration // 2
            end

            -- sort all duration lists in decreasing order
            local comparisonProc = function (a, b)  return a > b  end
            keyList = SplitHandler._measurePositionToDurationsMap:keyList()

            for _, key in keyList:iterator() do
                local durationList =
                          SplitHandler._measurePositionToDurationsMap:at(key)
                Logging.traceF(fName, "--: DL(%s) before - %s",
                               key, durationList)
                durationList:sort(comparisonProc)
                Logging.traceF(fName, "--: DL(%s) after  - %s",
                               key, durationList)
                SplitHandler._measurePositionToDurationsMap:set(key,
                                                                durationList)
            end

            Logging.traceF(fName, "<<: %s",
                           SplitHandler._mPosToDurationsMapString())
        end

        -- --------------------

        function SplitHandler.mptdmKey (rasterPosition, isInTripletSequence)
            -- Returns key for <_measurePositionToDurationsMap> for
            -- <rasterPosition> and information <isInTripletSequence>>
            -- whether position is in a triplet sequence

            local contextKind = iif(isInTripletSequence, "TRIPLET", "NORMAL")
            return String.format("%d/%s", rasterPosition, contextKind)
        end

    -- ================
    -- end SplitHandler
    -- ================

    -- ==========
    -- class Note
    -- ==========
        -- This class encapsulates services for lilypond notes like
        -- note names or mapping from pitches to notes etc.

        -- --------------------
        -- local features
        -- --------------------

        Note._drumNoteNames =
            "1,2,3,4,5,6,7,8,9,10,"
         .. "11,12,13,14,15,16,17,18,19,20,"
         .. "21,22,23,24,25,26,27,28,29,30,"
         .. "31,32,33,34,bda,bd,ss,sna,hc,sn,"
         .. "tomfl,hhc,tomfh,hhp,toml,hho,tomml,tommh,cymc,tomh,"
         .. "cymr,cymch,rb,tamb,cyms,cb,cymcb,vibs,cymrb,boh,"
         .. "bol,cghm,cgho,cgl,timh,timl,agh,agl,cab,mar,"
         .. "whs,whl,guis,guil,cl,wbh,wbl,cuim,cuio,trim,"
         .. "trio"

        -- --------------------

        Note._midiPitchToNameMap = nil

        Note._midiPitchToDrumNameMap = String.split(Note._drumNoteNames, ",")

        -- --------------------

        function Note.initialize (cls, key)
            -- Adapts pitch to note name map from <key>

            local fName = "Note.initialize"
            Logging.traceF(fName, ">>: key = %s", key)

            key = String.toLowercase(key)
            local sharpKeys = "c,g,d,a,e,b,fs,cs,"
            local keyIsSharp = (String.find(sharpKeys, key .. ",") ~= nil)
            local sharpNoteNames = "c,cs,d,ds,e,f,fs,g,gs,a,as,b"
            local flatNoteNames = "c,df,d,ef,e,f,gf,g,af,a,bf,b"
            local noteNames = iif(keyIsSharp, sharpNoteNames, flatNoteNames)
            Note._midiPitchToNameMap = String.split(noteNames, ",")

            Logging.traceF(fName, "--: noteNames = %s", noteNames)
            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function Note.absoluteName (midiPitch)
            -- Returns the absolute lilypond note name for given
            -- <midiPitch>

            local fName = "Note._absoluteName"
            Logging.traceF(fName, ">>: %d", midiPitch)

            local note = Note:makeFromMidiPitch(midiPitch, false)

            -- C3..B3 are the unmarked notes in lilypond
            note.octave = note.octave - 3

            local marker = iif(note.octave > 0, "'", ",")
            local markerCount = math.abs(note.octave)
            local result = note.name .. String.replicate(marker, markerCount)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Note.make (cls, name, octave)
            -- Constructs a new note with <name> and <octave>

            local fName = "Note.make"
            Logging.traceF(fName, ">>: %s, %s", name, octave)

            local result = cls:makeInstance()
            result.name   = name
            result.octave = octave

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Note.makeFromMidiPitch (cls, pitch, isDrumNote)
            -- Constructs note for MIDI <pitch>; if <isDrumNote> is
            -- set, no note, but the short form of a drum instrument
            -- name is returned instead

            local fName = "Note.makeFromMidiPitch"
            Logging.traceF(fName,
                           ">>: pitch = %d, isDrumNote = %s",
                           pitch, isDrumNote)

            local name
            local octave

            if not isDrumNote then
                name   = Note._midiPitchToNameMap:at(pitch % 12 + 1)
                octave = pitch // 12 - 1
            elseif isInRange(pitch, 35, 81) then
                name = Note._midiPitchToDrumNameMap:at(pitch)
            else
                name = "???"
            end

            local result = Note:make(name, octave)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Note:relativeNoteString (previousNote)
            -- Returns the relative note string for current note when
            -- following given <previousNote>

            local fName = "Note.relativeNoteString"
            Logging.traceF(fName,
                           ">>: previousNote = %s, note = %s",
                           previousNote, self)

            local baseNoteNames = "cdefgab"
            local direction
            local currentNoteBase  = String.slice(self.name, 1, 1)
            local currentPitch     = String.find(baseNoteNames,
                                                 currentNoteBase)
            local previousNoteBase = String.slice(previousNote.name, 1, 1)
            local previousPitch    = String.find(baseNoteNames,
                                                 previousNoteBase)
            local markerCount = math.abs(self.octave - previousNote.octave)
            local result

            Logging.traceF(fName,
                           "--: previousPitch=%d, currentPitch=%d,"
                           .. " markerCount=%d",
                           previousPitch, currentPitch, markerCount)

            -- find direction of interval (down, up or equal)
            if markerCount ~= 0 then
                direction = iif(self.octave > previousNote.octave, 1, -1)
            elseif previousNote.name == self.name then
                direction = 0
            else
                direction = iif(currentPitch > previousPitch, 1, -1)
            end

            Logging.traceF(fName, "--: direction = %d", direction)

            if direction == 0 then
                result = self.name
            else
                if (direction == 1 and previousPitch > currentPitch
                    or direction == -1 and previousPitch < currentPitch) then
                    currentPitch = currentPitch + direction * 7
                    markerCount = markerCount - 1
                end

                if math.abs(previousPitch - currentPitch) >= 4 then
                    markerCount = markerCount + 1
                end

                local marker = iif(direction == 1, "'", ",")
                result = self.name .. String.replicate(marker, markerCount)
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Note:__tostring ()
            -- Returns a string representation of note

            local octaveString = iif(self.octave == nil, "-",
                                     tostring(self.octave))

            return String.format("%s/%s", self.name, octaveString)
        end

    -- ========
    -- end Note
    -- ========

    -- ===============
    -- class NoteGroup
    -- ===============
        -- This class encapsulates the handling of note groups
        -- (i.e. chords) that may also consist of single notes and
        -- rests.

        -- --------------------
        -- local features
        -- --------------------

        -- map of MIDI ticks to lilypond length encodings in either
        -- normal or triplet context
        NoteGroup._durationToNoteLengthMap = Map:make()

        -- set of MIDI tick counts having a directly corresponding
        -- lilypond length encoding in normal or triplet context
        NoteGroup._acceptableDurationSet = Set:make()

        -- --------------------

        function NoteGroup.defineDurations (cls, ticksPerQuarterNote)
            -- Calculates table of duration strings for given
            -- <ticksPerQuarterNote>

            local fName = "Lilypond.NoteGroup.defineDurations"
            Logging.traceF(fName, ">>: %d", ticksPerQuarterNote)

            local addDuration =
                function (duration, isTriplet, st)
                    local key = SplitHandler.mptdmKey(duration, isTriplet)
                    Logging.traceF(fName, "--: %s -> %s", key, st)
                    cls._acceptableDurationSet:include(duration)
                    cls._durationToNoteLengthMap:set(key, st)
                end

            local value = 1
            local wholeNoteDuration = 4 * ticksPerQuarterNote
            local referenceDuration = wholeNoteDuration

            for i = 1, 6 do
               local st = tostring(value)
               local dottedSt = st .. "."
               addDuration(referenceDuration, false, st)
               addDuration(toInt(referenceDuration * 3 // 2), false, dottedSt)
               addDuration(toInt(referenceDuration * 2 // 3), true, st)
               addDuration(referenceDuration, true, dottedSt)
               value = 2 * value
               referenceDuration = referenceDuration // 2
            end

            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function NoteGroup.encodeDurationAsString (cls,
                                                    duration,
                                                    isInTripletSequence)
            -- Calculates lilypond duration string for given
            -- note <duration> assuming it is either in or out of a
            -- triplet sequence (as given by <isInTripletSequence>

            local fName = "Lilypond.NoteGroup.encodeDurationAsString"
            Logging.traceF(fName,
                           ">>: duration = %d, inTriplet = %s",
                           duration, isInTripletSequence)

            local result

            if not cls._acceptableDurationSet:contains(duration) then
                result = "?" .. duration .. "?"
            else
                local key
                -- first try the duration in the sequence of the
                -- previous note
                key = SplitHandler.mptdmKey(duration, isInTripletSequence)
                Logging.traceF(fName, "--: trying %s", key)
                result = cls._durationToNoteLengthMap:at(key)

                if result == nil then
                    isInTripletSequence = not isInTripletSequence
                    key = SplitHandler.mptdmKey(duration, isInTripletSequence)
                    Logging.traceF(fName, "--: trying %s", key)
                    result = cls._durationToNoteLengthMap:at(key)
                end
            end
            
            Logging.traceF(fName,
                           "<<: result = %s, inTriplet = %s",
                           result, isInTripletSequence)
            return result, isInTripletSequence
        end

        -- --------------------

        function NoteGroup:encodePitchAsString (referenceNote)
            -- Calculates lilypond pitch string for given note group
            -- with preceeding <referenceNote>; returns pitch string
            -- and tie string to be used after duration indication as
            -- well as new reference note

            local fName = "Lilypond.NoteGroup.encodePitchAsString"
            Logging.traceF(fName,
                           ">>: noteGroup = %s, referenceNote = %s",
                           self, referenceNote)

            local noteGroupPitchString
            local tieString
            local isDrum = (referenceNote == nil)

            if self.isRest then
                noteGroupPitchString = "r"
                tieString = ""
            else
                local noteCount = self.pitchDataList:count()
                local allAreTied = true

                for i = 1, noteCount do
                    local isTied = self.pitchDataList:at(i).isTied
                    allAreTied = (allAreTied and isTied)
                end

                local previousNote = referenceNote
                noteGroupPitchString = iif(noteCount > 1, "<", "")

                for i = 1, noteCount do
                    local pitch  = self.pitchDataList:at(i).pitch
                    local isTied = self.pitchDataList:at(i).isTied
                    local note = Note:makeFromMidiPitch(pitch, isDrum)
                    local noteString

                    if i > 1 then
                        noteGroupPitchString = noteGroupPitchString .. " "
                    elseif not isDrum then
                        referenceNote = note
                    end

                    if isDrum then
                        noteString = note.name
                    else
                        noteString = note:relativeNoteString(previousNote)
                        previousNote = note
                    end

                    noteString = noteString ..
                                 iif(isTied and not allAreTied, "~", "")
                    noteGroupPitchString = noteGroupPitchString .. noteString
                end

                noteGroupPitchString = (noteGroupPitchString
                                        .. iif(noteCount > 1, ">", ""))
                tieString = iif(allAreTied, "~", "")
            end

            Logging.traceF(fName,
                           "<<: %s/%s, referenceNote = %s",
                           noteGroupPitchString, tieString,
                          _referenceNote)
            return noteGroupPitchString, tieString, referenceNote
        end

        -- --------------------

        function NoteGroup:extractChord (referenceChord)
            -- Extracts chord from note group into a set returned;
            -- compares it to <referenceChord> and also returns
            -- whether new chord is equal to <referenceChord>

            local fName = "Lilypond.NoteGroup.extractChord"
            Logging.traceF(fName,
                           ">>: group = %s, referenceChord = %s",
                           self, referenceChord)

            local currentChord = Set:make()
            local isEqualToReferenceChord = false
            local isRest = self.isRest
            local pitchCount = self.pitchDataList:count()

            if isRest then
                -- fine
            elseif pitchCount == 1 then
                -- this is no chord, but a single note
                local pitch = self.pitchDataList:first().pitch
                currentChord:include(pitch)
            else
                local allAreTied = true
                local noneIsTied = true
                local hasEqualPitches = referenceChord:count() == pitchCount

                for _, pitchData in self.pitchDataList:iterator() do
                    local pitch, isTied = pitchData.pitch, pitchData.isTied
                    currentChord:include(pitch)
                    allAreTied      = allAreTied and isTied
                    noneIsTied      = noneIsTied and not isTied
                    hasEqualPitches = (referenceChord:contains(pitch)
                                       and hasEqualPitches)
                end

                Logging.traceF(fName,
                               "--: hasEqualPitches = %s,"
                               .. " allAreTied = %s, noneIsTied = %s",
                               hasEqualPitches, allAreTied, noneIsTied)
                isEqualToReferenceChord = (hasEqualPitches
                                           and (allAreTied or noneIsTied))
            end

            Logging.traceF(fName,
                           "<<: chord = %s, isEqual = %s",
                           currentChord, isEqualToReferenceChord)
            return currentChord, isEqualToReferenceChord
        end

        -- --------------------
        -- exported features
        -- --------------------

        function NoteGroup.make (cls)
            -- Makes an empty note group

            local fName = "Lilypond.NoteGroup.make"
            Logging.traceF(fName, ">>")

            local result = NoteGroup:makeInstance()
            result.isRest        = true
            result.startPosition = 0
            result.duration      = 0
            result.pitchDataList = List:make()

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function NoteGroup.makeForRest (cls, startPosition, endPosition)
            -- Makes a group containing a rest with <startPosition>
            -- and <endPosition>

            local fName = "Lilypond.NoteGroup.makeForRest"
            Logging.traceF(fName, ">>")

            local result = NoteGroup:make()
            result.startPosition = startPosition
            result.duration      = endPosition - startPosition

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function NoteGroup.makeForSingleNote (cls,
                                              startPosition, endPosition,
                                              pitch, isTied)
            -- Makes a note group for a single pitch

            local fName = "Lilypond.NoteGroup.makeForSingleNote"
            Logging.traceF(fName, ">>")

            local pitchData = { pitch = pitch, isTied = isTied }
            local result = NoteGroup:make()
            result.isRest        = false
            result.startPosition = startPosition
            result.duration      = endPosition - startPosition
            result.pitchDataList:set(1, pitchData)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function NoteGroup:addNote (pitch, isTied)
            -- Adds single note to note group as <pitch> and with tied
            -- status <isTied>

            local fName = "Lilypond.NoteGroup.addNote"
            Logging.traceF(fName, ">>: %d/%s", pitch, isTied)

            local comparePitchProc = function (x, y)
                                         return x.pitch < y.pitch
                                     end
            local pitchData = { pitch = pitch, isTied = isTied }
            self.pitchDataList:append(pitchData)
            self.pitchDataList:sort(comparePitchProc)

            Logging.traceF(fName, "<<: %s", self)
        end

        -- --------------------

        function NoteGroup:_asLilypondString (referenceChord,
                                              referenceDuration,
                                              referenceNote,
                                              isInTripletSequence)
            -- Returns a lilypond string for note group and also
            -- provides updated values for <referenceChord>,
            -- <referenceDuration>, <referenceNote> and
            -- <isInTripletSequence>

            local fName = "Lilypond.NoteGroup._asLilypondString"
            Logging.traceF(fName, ">>: self = %s, referenceChord = %s",
                           self, referenceChord)

            local duration = self.duration
            local noteGroupPitchString
            local tieString
            local result

            noteGroupPitchString, tieString, referenceNote =
                self:encodePitchAsString(referenceNote)

            local currentChord, isEqualToReferenceChord =
                self:extractChord(referenceChord)

            Logging.traceF(fName, "--: count = %d", currentChord:count())

            if currentChord:count() > 1 then
                referenceChord = currentChord

                if isEqualToReferenceChord then
                    -- we can use the "q" chord repetition symbol
                    noteGroupPitchString = "q"
                end
            end
            
            if referenceDuration == duration then
                durationString = ""
            else
                durationString, isInTripletSequence =
                   self:encodeDurationAsString(duration, isInTripletSequence)
                referenceDuration = duration
            end

            result = noteGroupPitchString .. durationString .. tieString

            Logging.traceF(fName,
                           "<<: result = %s, referenceChord = %s,"
                           .. " referenceDuration = %d, referenceNote = %s,"
                           .. " isInTripletSequence = %s",
                           result, referenceChord, referenceDuration,
                           referenceNote, isInTripletSequence)

            return result, referenceChord, referenceDuration, referenceNote,
                   isInTripletSequence
        end

        -- --------------------

        function NoteGroup.isLess (x, y)
            -- Comparison function for note groups

            return x.startPosition < y.startPosition
        end

        -- --------------------

        function NoteGroup:splitAt (splitPosition)
            -- Splits note group at <splitPosition> and returns both
            -- resulting groups; the split position must be within the
            -- group

            local fName = "Lilypond.NoteGroup.splitAt"
            Logging.traceF(fName,
                           ">>: noteGroup=%s, position=%d",
                           self, splitPosition)

            local groupA = self
            local groupB = NoteGroup:make()
            local groupStart = groupA.startPosition
            local groupEnd   = groupStart + groupA.duration

            assert(groupStart < splitPosition and splitPosition < groupEnd,
                   string.format("%s: position must be in group boundaries",
                                 fName))

            groupA.duration = splitPosition - groupStart
            groupB.isRest        = groupA.isRest
            groupB.startPosition = splitPosition
            groupB.duration      = groupEnd - splitPosition

            if not groupA.isRest then
                for i, pitchDataA in groupA.pitchDataList:iterator() do
                    local pitchData = { pitch = pitchDataA.pitch,
                                        isTied = pitchDataA.isTied }
                    groupB.pitchDataList:set(i, pitchData)
                    groupA.pitchDataList:set(i, { pitch = pitchData.pitch,
                                                  isTied = true })
                end
            end

            Logging.traceF(fName, "<<: a=%s, b=%s", groupA, groupB)
            return groupA, groupB
        end

        -- --------------------

        function NoteGroup:__tostring ()
            -- Returns the string representation of a note group

            local result
            local template =
                      "NoteGroup(isRest = %s, start = %d, duration = %d"
            result = string.format(template,
                                   self.isRest, self.startPosition,
                                   self.duration)

            if not self.isRest then
                result = result .. ", pitchDataList = ("

                for i, pitchData in self.pitchDataList:iterator() do
                    result = result .. iif(i > 1, ", ", "")
                    local isTied = iif(pitchData.isTied, "~", "")
                    result = result .. string.format("%d%s", pitchData.pitch,
                                                     isTied)
                end

                result = result .. ")"
            end

            result = result .. ")"
            return result
        end

    -- =============
    -- end NoteGroup
    -- =============

    -- ===================
    -- class NoteGroupList
    -- ===================
        -- This class covers lists of note groups ordered by start
        -- position.

        -- --------------------
        -- LOCAL FEATURES
        -- --------------------

        function NoteGroupList:_append (noteGroup)
            -- Adds single <noteGroup> to note group list

            local fName = "Lilypond.NoteGroupList._append"
            Logging.traceF(fName, ">>: %s", noteGroup)
            self._data:append(noteGroup)
            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function NoteGroupList:_at (index)
            -- Returns element at <index> in note group list

            return self._data:at(index)
        end

        -- --------------------

        function NoteGroupList:_count ()
            -- Returns number of note groups in list

            return self._data:count()
        end

        -- --------------------

        function NoteGroupList:_divideNotesMusically (measureTickList)
            -- Traverses note group list and splits note groups into
            -- elementary duration values with triplets and dotted
            -- notes

            local fName = "Lilypond.NoteGroupList._divideNotesMusically"
            Logging.traceF(fName, ">>")

            local isInTripletSequence = false

            for i = 1, self:_count() do
                local noteGroup = self:_at(i)
                local groupStart = noteGroup.startPosition

                Logging.traceF(fName, "--: group = %s", noteGroup)

                local j = NoteGroupList._findPrecedingIndex(measureTickList,
                                                            groupStart)

                if j ~= nil then
                    local relativePosition =
                              groupStart - measureTickList:at(j)
                    local groupDuration = noteGroup.duration
                    local durationList
                    isInTripletSequence = iif(relativePosition == 0, false,
                                              isInTripletSequence)
                    durationList, isInTripletSequence =
                              SplitHandler.findDurations(relativePosition,
                                                         groupDuration,
                                                         isInTripletSequence,
                                                         true)

                    local durationCount = durationList:count()

                    if durationCount > 1 then
                        -- there are multiple durations required, hence
                        -- split the note group starting with the last
                        -- duration
                        local splitPosition = groupStart + groupDuration

                        for k = durationCount, 2, -1 do
                            local duration = durationList:at(k)
                            splitPosition = splitPosition - duration
                            local _, newGroup =
                                         noteGroup:splitAt(splitPosition)
                            self:_append(newGroup)
                        end
                    end
                end
            end

            self:_sort()
            Logging.traceF(fName, "<<: %s", self)
        end

        -- --------------------

        function NoteGroupList:_asLilypondString (referencePitch,
                                                  measureTickList)
            -- Calculates lilypond representation of note group list;
            -- starts at <referencePitch> for non-drums and uses drum
            -- notation when <referencePitch> is not set;
            -- <measureTickList> gives the tick positions of
            -- measure bars to be inserted

            local fName = "Lilypond.NoteGroupList._asLilypondString"
            Logging.traceF(fName, ">>")

            local isInTripletSequence = false
            local referenceChord = Set:make()
            local referenceDuration = 0
            local referenceNote
            local result = ""

            if referencePitch ~= nil then
                referenceNote = Note:makeFromMidiPitch(referencePitch,
                                                       false)
            end

            for i = 1, self:_count() do
                local noteGroup = self:_at(i)
                local noteGroupString
                local previousTripletStatus = isInTripletSequence

                noteGroupString, referenceChord, referenceDuration,
                referenceNote, isInTripletSequence =
                    noteGroup:_asLilypondString(referenceChord,
                                                referenceDuration,
                                                referenceNote,
                                                isInTripletSequence)
                result = result .. iif(i > 1, " ", "")

                if not previousTripletStatus and isInTripletSequence then
                    result = result .. "\\triplets { "
                elseif not isInTripletSequence
                       and previousTripletStatus then
                    result = result .. "} "
                end

                result = result .. noteGroupString

                -- check for end of measure
                local groupStart = noteGroup.startPosition
                local groupEnd   = groupStart + noteGroup.duration
                local j = NoteGroupList._findFollowingIndex(measureTickList,
                                                            groupStart)

                if j ~= nil then
                    local measurePosition = measureTickList:at(j)

                    if measurePosition == groupEnd then
                        -- this group extends to end of measure =>
                        -- mark in string and reset some reference
                        -- values
                        if isInTripletSequence then
                            result = result .. " }"
                        end

                        isInTripletSequence = false
                        referenceDuration = 0
                        result = result .. " |"
                    end
                end
            end

            if isInTripletSequence then
                result = result .. " }"
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function NoteGroupList._findFollowingIndex (list, referenceValue)
            -- Returns minimum <j> where value at list[j] (with
            -- list ordered ascendingly) is greater than
            -- <referenceValue>; returned value is the smallest index
            -- with this property or nil if there is none

            local fName = "Lilypond.NoteGroupList._findFollowingIndex"
            Logging.traceF(fName,
                           ">>: value = %d, list = %s",
                           referenceValue, list)

            local result = nil
            local firstIndex = 1
            local lastIndex  = list:count()

            -- do a bisection search
            while firstIndex <= lastIndex do
                local midIndex = (firstIndex + lastIndex) // 2
                local currentValue = list:at(midIndex)
                Logging.traceF(fName, "--: %d [%d] %d",
                               firstIndex, midIndex, lastIndex)

                if firstIndex == lastIndex then
                    result = iif(currentValue > referenceValue, lastIndex, nil)
                    break
                elseif currentValue <= referenceValue then
                    firstIndex = midIndex + 1
                else
                    lastIndex = midIndex
                end
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function NoteGroupList._findPrecedingIndex (list, referenceValue)
            -- Returns maximum <j> where value at list[j] (with
            -- list ordered ascendingly) is less than or equal to
            -- <referenceValue>; returned value is the largest index
            -- with this property or nil if there is none

            local fName = "Lilypond.NoteGroupList._findPrecedingIndex"
            Logging.traceF(fName,
                           ">>: value = %d, list = %s",
                           referenceValue, list)

            local result = nil

            for i, element in list:iterator() do
                if element > referenceValue then
                    result = i - 1
                    break
                end
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function NoteGroupList:_sort ()
            -- Sorts note group list in ascending order of group start
            -- position

            local fName = "Lilypond.NoteGroupList._sort"
            Logging.traceF(fName, ">>")
            self._data:sort(NoteGroup.isLess)
            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function NoteGroupList:_splitAtMeasures (measureTickList)
            -- Splits all groups in note group list that cross a
            -- measure bar given by <measureTickList>

            local fName = "Lilypond.NoteGroupList._splitAtMeasures"
            Logging.traceF(fName, ">>")
            local splitIsDone

            repeat
                splitIsDone = false

                for i = 1, self:_count() do
                    -- check whether current group crosses a measure bar
                    local noteGroup = self:_at(i)
                    local groupStart = noteGroup.startPosition
                    local groupEnd   = groupStart + noteGroup.duration

                    -- find index <j> where measure bar tick is greater
                    -- than <groupStart>
                    local j = NoteGroupList._findFollowingIndex(measureTickList,
                                                                groupStart)

                    if j ~= nil then
                        local measurePosition = measureTickList:at(j)

                        if groupEnd > measurePosition then
                            local _, newGroup =
                                noteGroup:splitAt(measurePosition)
                            self:_append(newGroup)
                            splitIsDone = true
                        end
                    end
               end

               self:_sort()
            until not splitIsDone

            Logging.traceF(fName, "<<: %s", self)
        end

        -- --------------------
        -- exported features
        -- --------------------

        function NoteGroupList.make (cls, noteList, endPosition)
            -- Makes a continuous sequence of groups containing either
            -- rests or "chords" consisting of one or more notes

            local fName = "Lilypond.NoteGroupList.make"
            Logging.traceF(fName, ">>: %d", endPosition)

            -- sort note list by start position ascending and then end
            -- position descending
            local noteComparisonProc =
                function (noteA, noteB)
                    return (noteA.startPosition < noteB.startPosition
                            or (noteA.startPosition == noteB.startPosition
                                and noteA.endPosition > noteB.endPosition))
                end

            noteList:sort(noteComparisonProc)

            local result = cls:makeInstance()
            result._data = List:make()

            for _, note in noteList:iterator() do
                result:addNote(note)
            end

            Logging.traceF(fName,
                           "--: note groups generated = %d",
                           result:_count())

            local newGroup
            local previousEnd = 0

            -- fill gaps with rest groups
            for i = 1, result:_count() do
                local group = result:_at(i)
                local groupStart = group.startPosition

                if groupStart < previousEnd then
                    Logging.traceErrorF(fName, "overlapping groups")
                elseif previousEnd < groupStart then
                    newGroup = NoteGroup:makeForRest(previousEnd, groupStart)
                    result:_append(newGroup)
                end

                previousEnd = groupStart + group.duration
            end

            if previousEnd < endPosition then
                newGroup = NoteGroup:makeForRest(previousEnd, endPosition)
                result:_append(newGroup)
            end

            result:_sort()
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function NoteGroupList:addNote (note)
            -- Adds single <note> to note group list

            local fName = "Lilypond.NoteGroupList.addNote"
            Logging.traceF(fName, ">>: %s", note)

            local noteStart = note.startPosition
            local noteEnd   = note.endPosition

            -- traverse the sorted list of note groups
            local noteGroupCount = self:_count()

            for i = 1, noteGroupCount do
                if noteStart < noteEnd then
                    -- check whether note overlaps current group
                    local group = self:_at(i)
                    local groupStart = group.startPosition
                    local groupEnd   = groupStart + group.duration
                    local newGroup

                    if noteEnd <= groupStart then
                        -- note lies completely before current group
                        newGroup =
                            NoteGroup:makeForSingleNote(noteStart, noteEnd,
                                                        note.pitch, false)
                        self:_append(newGroup)
                        noteStart = noteEnd
                    end

                    if noteStart < groupEnd then
                        -- there is some overlap with current group
                        if noteStart < groupStart then
                            newGroup =
                                NoteGroup:makeForSingleNote(noteStart,
                                                            groupStart,
                                                            note.pitch, true)
                            self:_append(newGroup)
                            noteStart = groupStart
                        end

                        if groupStart < noteStart  then
                            _, newGroup = group:splitAt(noteStart)
                            self:_append(newGroup)
                            group = newGroup
                        end

                        if noteEnd < groupEnd then
                            group, newGroup = group:splitAt(noteEnd)
                            self:_append(newGroup)
                        end

                        group:addNote(note.pitch, noteEnd > groupEnd)
                        noteStart = groupEnd
                    end
                end
            end

            if noteStart < noteEnd then
                -- there is still some part of the note left => make a
                -- new note group after all the others
                newGroup = NoteGroup:makeForSingleNote(noteStart, noteEnd,
                                                       note.pitch, false)
                self:_append(newGroup)
            end

            -- keep list sorted
            self:_sort()
            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function NoteGroupList:toLilypondString (referencePitch,
                                                 measureTickList,
                                                 ticksPerQuarterNote)
            -- Calculates lilypond representation of note group list;
            -- starts at <referencePitch> for non-drums and uses drum
            -- notation when <referencePitch> is not set;
            -- <measureTickList> gives the tick positions of
            -- measure bars to be inserted

            local fName = "Lilypond.NoteGroupList.toLilypondString"
            Logging.traceF(fName,
                           ">>: referencePitch = %s, mbTickList = %s,"
                           .. " noteGroupList = %s",
                           referencePitch, measureTickList, self)

            NoteGroup:defineDurations(ticksPerQuarterNote)
            self:_splitAtMeasures(measureTickList)
            self:_divideNotesMusically(measureTickList)
            local result = self:_asLilypondString(referencePitch,
                                                  measureTickList)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function NoteGroupList:__tostring ()
            -- Returns the string representation of note group list

            return tostring(self._data)
        end

    -- =================
    -- end NoteGroupList
    -- =================

    -- --------------
    -- LOCAL FEATURES
    -- --------------

    Lilypond._quantisation = nil
    Lilypond._ticksPerQuarterNote = nil

    -- --------------------

    -- mapping from instrument name to pitch used for
    -- "relative" indication introducing phrases; a pitch of nil
    -- indicates phrases in drum mode
    Lilypond._trackNameToReferenceMidiPitchMap =
              Map:makeFromTuple({
                  bass           = 36,
                  drums          = nil,
                  guitar         = 60,
                  keyboard       = 48,
                  keyboardBottom = 36,
                  keyboardTop    = 60,
                  strings        = 60,
                  vocals         = 72
              })

    -- --------------------

    function Lilypond._adaptedTakeName (takeName)
       -- Makes lilypond name from <takeName>

        local fName = "Lilypond._adaptedTakeName"
        Logging.traceF(fName, ">>: %s", takeName)

        local result = takeName

        while String.find(result, " ") do
            local prefix, suffix = String.splitAt(result, " ")
            local ch   = String.slice(suffix, 1, 1)
            local rest = String.slice(suffix, 2)
            result = prefix .. String.toUppercase(ch) .. rest
        end

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function Lilypond._quantiseNoteList (noteList)
        -- Makes a naive quantisation of <noteList>

        local fName = "Lilypond._quantiseNoteList"
        Logging.traceF(fName, ">>: %s", noteList)

        local positionQuantisationProc = function (position)
           -- makes a naive quantisation of <position>
           position = position + Lilypond._quantisation // 2
           return position - position % Lilypond._quantisation
        end

        local comparisonProc =
            function (noteA, noteB)
                local result

                if noteA.startPosition < noteB.startPosition then
                    result = true
                elseif noteA.startPosition > noteB.startPosition then
                    result = false
                else
                    result = noteA.pitch < noteB.pitch
                end

                return result
            end

        local noteQuantisationProc =
            function (note)
                note.startPosition =
                         positionQuantisationProc(note.startPosition)
                note.endPosition   =
                         positionQuantisationProc(note.endPosition)
            end

        noteList:applyToAll(noteQuantisationProc)
        noteList:sort(comparisonProc)
        Logging.traceF(fName, "<<: %s", noteList)
    end

    -- --------------------

    function Lilypond._referencePitchForName (takeName)
        -- Returns reference pitch for starting a relative note
        -- sequence for take with <takeName>; result may be nil when
        -- take specifies a drum take

        local fName = "Lilypond._referencePitchForName"
        Logging.traceF(fName, ">>: %s", takeName)

        local defaultPitch = 60  -- MIDI pitch for middle c
        local instrumentName, _ = String.splitAt(takeName, " ")
        local result

        Logging.traceF(fName, "--: %s", instrumentName)

        if instrumentName == "drums" or instrumentName == "percussion" then
            result = nil
        else
            local midiPitch =
                Lilypond._trackNameToReferenceMidiPitchMap:at(instrumentName)
            result = iif(midiPitch == nil, defaultPitch, midiPitch)
        end

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function Lilypond._setupAllowedNoteDurationTable (ticksPerQuarterNote)
        -- Recalculates the internal table of allowed note durations
        -- per raster position based on the midi ticks per quarter in
        -- <ticksPerQuarterNote>
            
        local fName = "Lilypond._setupAllowedNoteDurationTable"

        Logging.traceF(fName, ">>: ticksPerQuarterNote = %s",
                       ticksPerQuarterNote)
        
        if Lilypond._ticksPerQuarterNote ~= ticksPerQuarterNote then
            -- the smallest supported note is a triplet of the note
            -- given by <_log2MinimumNoteLength>
            local quantisationFactor = 2 ^ (_log2MinimumNoteLength - 2)
            Lilypond._quantisation =
                ticksPerQuarterNote * 2 // (quantisationFactor * 3)
            Logging.traceF(fName,
                           "--: ticks per minimum note = %s",
                           Lilypond._quantisation)

            SplitHandler.initialize(ticksPerQuarterNote,
                                    adaptedNotationIsUsed)
            Lilypond._ticksPerQuarterNote = ticksPerQuarterNote
        end

        Logging.traceF(fName, "<<")
    end

    -- --------------------

    function Lilypond._splitAndIndentString (st, separator, indentation,
                                             blankIsInsertedBeforeSeparator)
        -- Splits <st> at <separator> and makes lines with
        -- <indentation> blanks as prefix;
        -- <blankIsInsertedBeforeSeparator> tells whether a single
        -- blank has to be inserted before separator

        local fName = "Lilypond._splitAndIndentString"
        Logging.traceF(fName,
                       ">>: st = '%s', sep = '%s', indentation = %d",
                       st, separator, indentation)

        local lineList = String.split(st, separator)
        lineList:applyToAll(String.trim)

        while true do
            -- get rid of trailing blank lines
            local lineCount = lineList:count()

            if lineCount == 0 or lineList:at(lineCount) > "" then
                break
             end

            lineList:removeLast()
        end

        local lastLineIsComplete = String.hasSuffix(st, separator)
        local indentationString = String.replicate(" ", indentation)
        separator = (iif(blankIsInsertedBeforeSeparator, " ", "")
                     .. separator)
        local separatorString = (separator .. String.newline
                                 .. indentationString)
        local result = (indentationString
                        .. String.join(lineList, separatorString)
                        .. iif(lastLineIsComplete, separator, "")
                        .. String.newline)

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------
    -- EXPORTED FEATURES
    -- --------------------

    function Lilypond.convertNoteListToLilypondString (referencePitch,
                                                       noteList,
                                                       measureTickList,
                                                       endPosition)
        -- Produces a Lilypond note sequence with relative notes
        -- grouped by measures; when <referencePitch> is not set, a
        -- drum note list is assumed

        local fName = "Lilypond.convertNoteListToLilypondString"
        Logging.traceF(fName,
                       ">>: referencePitch = %s,"
                       .. " mbTickList = %s, noteList = %s",
                       referencePitch, measureTickList, noteList)

        Lilypond._quantiseNoteList(noteList)
        local noteGroupList = NoteGroupList:make(noteList, endPosition)
        local ticksPerQuarterNote = Lilypond._ticksPerQuarterNote
        local result =
                  noteGroupList:toLilypondString(referencePitch,
                                                 measureTickList,
                                                 ticksPerQuarterNote)

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function Lilypond.convertTakeToLilypondString (takeName,
                                                   ticksPerQuarterNote,
                                                   noteList,
                                                   measureTickList,
                                                   endPosition)
        -- Produces a Lilypond note sequence for take with <takeName>
        -- using relative notes for a non-drum take with the number of
        -- midi ticks per quarter in <ticksPerQuarterNote>; notes in
        -- <noteList> are grouped by measures in <measureTickList>

        local fName = "Lilypond.convertTakeToLilypondString"
        Logging.traceF(fName,
                       ">>: take = '%s', ticksPerQuarterNote = %s, "
                       .. " noteList = '%s', mbTickList = '%s',"
                       .. " endPosition = %d",
                       takeName, ticksPerQuarterNote,
                       noteList, measureTickList, endPosition)

        local adaptedTakeName = Lilypond._adaptedTakeName(takeName)
        local referencePitch = Lilypond._referencePitchForName(takeName)

        Logging.traceF(fName,
                       "--: adTN = '%s', pitch = %s",
                       adaptedTakeName, referencePitch)

        Lilypond._setupAllowedNoteDurationTable(ticksPerQuarterNote)

        if referencePitch == nil then
            noteListReference = "\\drummode"
        else
            local referenceNote = Note.absoluteName(referencePitch)
            noteListReference = "\\relative " .. referenceNote
        end

        local noteListString =
                  Lilypond.convertNoteListToLilypondString(referencePitch,
                                                           noteList,
                                                           measureTickList,
                                                           endPosition)
        noteListString =
            Lilypond._splitAndIndentString(noteListString, "|",
                                           _noteSequenceIndentation, true)
        local result = adaptedTakeName .. " = " .. noteListReference .. " {"
                       .. String.newline
                       .. noteListString
                       .. "}" .. String.newline

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function Lilypond.initialize (key, adaptedNotationIsUsed)
        -- Initializes conversion parameters like the mapping from
        -- pitch within octave to note name or the length based on the
        -- <key> of the song and whether notes should be split at
        -- raster positions by <adaptedNotationIsUsed>

        local fName = "Lilypond.initialize"
        Logging.traceF(fName,
                       ">>: key = %s, adaptedNotationIsUsed = %s",
                       key, adaptedNotationIsUsed)

        Lilypond._quantisation = nil
        Lilypond._ticksPerQuarterNote = nil
        Note:initialize(key)

        Logging.traceF(fName, "<<")
    end

-- ============
-- end Lilypond
-- ============
