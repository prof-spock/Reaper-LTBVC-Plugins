-- Reaper - object-oriented wrapper around the Reaper API functions
-- 
-- author: Dr. Thomas Tensi, 2019-2023

-- =======================
-- IMPORTS
-- =======================

require("math")
-- require("reaper")

require("Class")
require("List")
require("Logging")
require("String")

-- ===============
-- module Reaper
-- ===============
    -- This module provides a simplified object-based API for Reaper.

    -- =======================
    -- ENUMERATION TYPES (=KIND)
    -- =======================

    local TimeBaseKind = {
        default = -1,
        time    =  0,
        beats   =  1,
        beatPos =  2
    }

    -- --------------------

    local MessageBoxKind = {
      ok               = 0,
      okCancel         = 1,
      abortRetryIgnore = 2,
      yesNoCancel      = 3,
      yesNo            = 4,
      retryCancel      = 5
    }

    -- --------------------

    local MessageBoxAnswerKind = {
      ok     = 1,
      cancel = 2,
      abort  = 3,
      retry  = 4,
      ignore = 5,
      yes    = 6,
      no     = 7
    }

    -- --------------------

    local MidiEventKind = {
        controlCode = "cc",
        note        = "note",
        text        = "text"
    }

    -- --------------------

    local function _trackSendModeKindToString (value)
        local result
        
        if value == 0 then
            result = "postFader"
        elseif value == 1 then
            result = "preFX"
        else
            result = "postFX"
        end

        return result
    end

    -- --------------------

    local TrackSendModeKind = {
        postFader  = 0,
        preFX      = 1,
        deprecated = 2,
        postFX     = 3,
        __tostring = _trackSendModeKindToString
    }

    -- --------------------

    function TrackSendModeKind.makeFromString (st)
        local result
        local uppercasedSt = String.toUppercase(st)

        if uppercasedSt == "POSTFADER" then
            result = TrackSendModeKind.postFader
        elseif uppercasedSt == "PREFX" then
            result = TrackSendModeKind.preFX
        else
            result = TrackSendModeKind.postFX
        end

        return result
    end

    -- ----------------------------
    -- CLASS AND MODULE DEFINITIONS
    -- ----------------------------

    local ConfigData           = Class:make("ConfigData")
    local Effect               = Class:make("Effect")
    local EffectParameter      = Class:make("EffectParameter")
    local Generics             = {}
    local MediaSource          = Class:make("MediaSource")
    local MediaItem            = ClassWithPeer:make("MediaItem")
    local MidiEvent            = Class:make("MidiEvent")
    local MidiEventList        = Class:makeVariant("MidiEventList", List)
    local Project              = ClassWithPeer:make("Project")
    local Region               = Class:make("Region")
    local Take                 = ClassWithPeer:make("Take")
    local Track                = ClassWithPeer:make("Track")
    local TrackConnection      = Class:make("TrackConnection")
    local UI_MixerControlPanel = ClassWithPeer:make("UI.MixerControlPanel")

    -- ===============
    -- module Generics
    -- ===============
        -- Several utility functions for Reaper like e.g. generic list
        -- output.

        -- ------------------

        function Generics.findElementByIndexNOLOG (container, index,
                                                   elementType,
                                                   selectionProc,
                                                   elementCount)
            -- Generic routine to extract a single element in
            -- <container> by <index>; <selectionProc> selects the
            -- element from the container and <elementCount> gives the
            -- number of those elements in container

            local lowercasedTypeName =
                      String.toLowercase(elementType.__name)
            local errorMessage =
                      String.format("bad %s with index %s",
                                    lowercasedTypeName, index)
            assert(1 <= index and index <= elementCount, errorMessage)
            return selectionProc(container, index)
        end

        -- ------------------

        function Generics.findElementByIndex (container, index,
                                              elementTypeName,
                                              selectionProc,
                                              elementCount)
            -- Generic routine to extract a single element in
            -- <container> by <index>; <selectionProc> selects the
            -- element from the container and <elementCount> gives the
            -- number of those elements in container

            local fName = "Reaper.Generics.findElementByIndex"
            Logging.traceF(fName, ">>: %s, %d", container, index)
            local result =
                      Generics.findElementByIndexNOLOG(container, index,
                                                       elementTypeName,
                                                       selectionProc,
                                                       elementCount)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Generics.findElementByIndexRawNOLOG (container, index,
                                                      elementType,
                                                      rawSelectionProc,
                                                      elementCount)
            -- Generic routine to extract a single element in
            -- <container> by <index> and finally wrap it into type
            -- <elementType>; <rawSelectionProc> selects the element
            -- from the container peer object via (index - 1),
            -- <elementCount> gives the number of those elements in
            -- container

            local reaperContainer = container._peerObject
            local lowercasedTypeName =
                      String.toLowercase(elementType.__name)
            local errorMessage =
                      String.format("bad %s with index %s",
                                    lowercasedTypeName, index)
            assert(1 <= index and index <= elementCount, errorMessage)
            local reaperObject = rawSelectionProc(reaperContainer, index - 1)
            local result = elementType:_make(reaperObject)
            return result
        end

        -- ------------------

        function Generics.findElementByIndexRaw (container, index,
                                                 elementType,
                                                 rawSelectionProc,
                                                 elementCount)
            -- Generic routine to extract a single element in
            -- <container> by <index> and finally wrap it into type
            -- <elementType>; <rawSelectionProc> selects the element
            -- from the container peer object via (index - 1),
            -- <elementCount> gives the number of those elements in
            -- container

            local fName = "Reaper.Generics.findElementByIndexRaw"
            Logging.traceF(fName,
                           ">>: container = %s, index = %s",
                           container, index)
            local result =
                      Generics.findElementByIndexRawNOLOG(container,
                                                          index,
                                                          elementType,
                                                          rawSelectionProc,
                                                          elementCount)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Generics.makeList (container, elementType,
                                    selectionProc, elementCount)
            -- Generic routine to make a list from all elements within
            -- <container>; <selectionProc> selects the elements from
            -- the container via an index and <elementCount> returns
            -- the number of those elements in container

            local fName = "Reaper.Generics.makeList"
            Logging.traceF(fName,
                           ">>: container = %s, kind = %s, count = %s",
                           container, elementType.__name, elementCount)

            local result = List:make()

            for elementIndex = 1, elementCount do
                Logging.traceF(fName,
                               "--: processing element %d", elementIndex)
                local element = selectionProc(container, elementIndex)
                result:append(element)
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Generics.makeListByPredicateRaw (container,
                                                  elementType,
                                                  rawSelectionProc,
                                                  elementCount,
                                                  isValidProc)
            -- Generic routine to make a list of all elements in
            -- <container> having <isValidProc> fulfilled;
            -- <rawSelectionProc> selects the raw element from the
            -- container via (index - 1), <elementCount> is the number
            -- of all elements in container and <isValidProc> gives a
            -- boolean predicate

            local fName = "Reaper.Generics.makeListByPredicateRaw"
            Logging.traceF(fName, ">>: %s", container)

            local result = List:make()
            local findByIndexRaw = Generics.findElementByIndexRawNOLOG

            for index = 1, elementCount do
                local element = findByIndexRaw(container, index,
                                               elementType, rawSelectionProc,
                                               elementCount)

                if isValidProc(element) then
                    result:append(element)
                end
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end
    -- ============
    -- end Generics
    -- ============

    -- ================
    -- class ConfigData
    -- ================
       -- Provides services for reading configuration settings
       -- from the Reaper project comment section

        -- ------------------
        -- EXPORTED ROUTINES
        -- ------------------

        function ConfigData.get (project, desiredKey)
            -- Returns settings for <desiredKey> in project
            -- configuration data for <project> or nil if nothing is
            -- found

            local fName = "Reaper.ConfigData.get"
            Logging.traceF(fName,
                           ">>: project = %s, key = '%s'",
                           project, desiredKey)

            local result
            local description = project:description()
            local lineList = String.split(description, String.newline)
           
            for _, line in lineList:iterator() do
                local separatorPosition = String.find(line, "=")
                Logging.traceF(fName,
                               "--: line = '%s', sepPos = %s",
                               line, separatorPosition)

                if separatorPosition ~= nil then
                    local key
                    key = String.slice(line, 1, separatorPosition - 1)
                    key = String.trim(key)
                    
                    if key == desiredKey then
                        result = String.slice(line, separatorPosition + 1)
                        result = String.trim(result)

                        if String.findPattern(result, "'.*'")
                            or String.findPattern(result, "\".*\"") then
                            -- string is quoted => remove quotes
                            result = String.slice(result, 2,
                                                  String.length(result) - 1)
                        end
                    end
                end
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

    -- =====================
    -- end ConfigData
    -- =====================


    -- ====================
    -- class Effect
    -- ====================
        -- This class provides services for effects associated to
        -- a track or an enclosing container.

        -- ------------------
        -- PRIVATE FEATURES
        -- ------------------

        function Effect:_configurationParameterNOLOG (parameterName)
            -- Returns value of configuration parameter named
            -- <parameterName> for current effect

            local reaperTrack, reaperFXIndex =
                self:internalRepresentation()

            local isOkay, result =
                reaper.TrackFX_GetNamedConfigParm(reaperTrack,
                                                  reaperFXIndex,
                                                  parameterName)
            return result
        end

        -- ------------------

        function Effect:_isContainerNOLOG ()
            -- Tells whether current effect is a container

            local reaperTrack, reaperFXIndex =
                self:internalRepresentation()
            local result = false
            -- local _, result =
            --     reaper.TrackFX_GetNamedConfigParm(reaperTrack,
            --                                       reaperFXIndex,
            --                                       "fx_name")
            return result
        end

        -- ------------------

        function Effect:_nameNOLOG ()
            -- Returns name of current effect

            local result =
                self:_configurationParameterNOLOG("renamed_name")

            if result == "" then
                result = self:_configurationParameterNOLOG("fx_name")
            end
            
            return result
        end

        -- ------------------

        function Effect:_parameterCountNOLOG ()
            -- Returns count of all parameters of current effect

            local reaperTrack, reaperFXIndex =
                self:internalRepresentation()
            return reaper.TrackFX_GetNumParams(reaperTrack, reaperFXIndex)
        end

        -- ------------------

        function Effect:_parameterListNOLOG ()
            -- Returns list of all parameters of current effect

            local parameterCreationProc =
                function (effect, parameterIndex)
                    return EffectParameter:make(effect, parameterIndex)
                end
            local result = Generics.makeList(self, EffectParameter,
                                             parameterCreationProc,
                                             self:_parameterCountNOLOG())
            return result
        end

        -- ------------------
        -- EXPORTED FEATURES
        -- ------------------

        function Effect.make (cls, track, index)
            -- Returns effect with number <index> associated with
            -- <track>

            local fName = "Reaper.Effect.make"
            Logging.traceF(fName, ">>: track = %s, index = %d",
                           track, index)

            local result = cls:makeInstance()
            result._index = index
            result._track = track

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- attributes
        -- ··········

        function Effect:activePreset ()
            -- Returns name of preset for current effect if no
            -- changes have been applied

            local fName = "Reaper.Effect.activePreset"
            Logging.traceF(fName, ">>: %s", self)

            local reaperTrack, reaperFXIndex =
                self:internalRepresentation()
            local isOkay, result = reaper.TrackFX_GetPreset(reaperTrack,
                                                            reaperFXIndex)
            result = iif(not isOkay, "", result)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Effect:effectList ()
            -- Returns the list of contained effects when current
            -- effect is a container

            local fName = "Reaper.Effect.effectList"
            Logging.traceF(fName, ">>: %s", self)

            local isContainer = self:_isContainerNOLOG()
            local result = List:make()

            -- if isContainer then
            -- end
            
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Effect:identification ()
            -- Returns unique identification of current effect

            local fName = "Reaper.Effect.identification"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_configurationParameterNOLOG("fx_ident")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Effect:isContainer ()
            -- Tells whether current effect is a container

            local fName = "Reaper.Effect.isContainer"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_isContainerNOLOG()
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Effect:isEnabled ()
            -- Tells whether current effect is enabled

            local fName = "Reaper.Effect.isEnabled"
            Logging.traceF(fName, ">>: %s", self)

            local reaperTrack, reaperFXIndex =
                self:internalRepresentation()
            local result = reaper.TrackFX_GetEnabled(reaperTrack,
                                                     reaperFXIndex)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Effect:kind ()
            -- Returns kind of current effect

            local fName = "Reaper.Effect.kind"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_configurationParameterNOLOG("fx_type")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Effect:name ()
            -- Returns name of current effect

            local fName = "Reaper.Effect.name"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_nameNOLOG()
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Effect:parameterByName (name)
            -- Returns parameter of current effect named <name> or nil
            -- if not found

            local fName = "Reaper.Effect.parameterByName"
            Logging.traceF(fName, ">>: effect = %s, parameterName = %s",
                           self, name)
            assert(not self:_isContainerNOLOG(),
                   "parameters not available for container effect")

            local parameterList = self:_parameterListNOLOG()
            local result

            for _, effectParameter in parameterList:iterator() do
                if effectParameter:_nameNOLOG() == name then
                    result = effectParameter
                    break
                end
            end
            
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Effect:parameterCount ()
            -- Returns count of all parameters of current effect

            local fName = "Reaper.Effect.parameterCount"
            Logging.traceF(fName, ">>: %s", self)
            assert(not self:_isContainerNOLOG(),
                   "parameters not available for container effect")
            local result = self:_parameterCountNOLOG()
            Logging.traceF(fName, "<<: %d", result)
            return result
        end

        -- ------------------

        function Effect:parameterList ()
            -- Returns list of all parameters of current effect

            local fName = "Reaper.Effect.parameterList"
            Logging.traceF(fName, ">>: %s", self)
            assert(not self:_isContainerNOLOG(),
                   "parameters not available for container effect")
            local result = self:_parameterListNOLOG()
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Effect:parent ()
            -- Returns parent object associated with current effect:
            -- either track in case of a top level effect or enclosing
            -- container object

            local fName = "Reaper.Effect.parent"
            Logging.traceF(fName, ">>: %s", self)
            local result = self._track
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ················
        -- attribute change
        -- ················

        function Effect:setEnabled (isEnabled)
            -- Sets whether current effect is enabled by <isEnabled>

            local fName = "Reaper.Effect.setEnabled"
            Logging.traceF(fName, ">>: effect = %s, isEnabled = %s",
                           self, isEnabled)

            local reaperTrack, reaperFXIndex =
                self:internalRepresentation()
            reaper.TrackFX_SetEnabled(reaperTrack, reaperFXIndex,
                                      isEnabled)

            Logging.traceF(fName, "<<")
            return result
        end

        -- ------------------

        function Effect:setName (name)
            -- Sets name of current effect to <name>

            local fName = "Reaper.Effect.setName"
            Logging.traceF(fName, ">>: effect = %s, name = %s",
                           self, name)

            local reaperTrack, reaperFXIndex =
                self:internalRepresentation()
            reaper.TrackFX_SetNamedConfigParm(reaperTrack,
                                              reaperFXIndex,
                                              "renamed_name",
                                              name)

            Logging.traceF(fName, "<<")
            return result
        end

        -- ··········
        -- conversion
        -- ··········

        function Effect:__tostring ()
            -- Returns a simple string representation of effect

            local trackName = self._track:_nameNOLOG()
            return String.format("Effect(track = '%s',"
                                 .. " index = %d,"
                                 .. " name = '%s')",
                                 trackName, self._index,
                                 self:_nameNOLOG())
        end

        -- ------------------

        function Effect:internalRepresentation ()
            -- Returns reaper representation of effect as a pair of
            -- reaper track and index

            return self._track:internalRepresentation(),
                   self._index - 1
        end

    -- =====================
    -- end Effect
    -- =====================


    -- ======================
    -- class EffectParameter
    -- ======================
        -- This class provides services for effect parameters
        -- associated to a track effect.

        -- ------------------
        -- PRIVATE FEATURES
        -- ------------------

        function EffectParameter:_nameNOLOG ()
            -- Returns name of current effect parameter

            local reaperTrack, reaperFXIndex, reaperParameterIndex =
                self:internalRepresentation()
            local _, result =
                reaper.TrackFX_GetParamName(reaperTrack,
                                            reaperFXIndex,
                                            reaperParameterIndex)
            return result
        end

        -- ------------------
        -- EXPORTED FEATURES
        -- ------------------

        function EffectParameter.make (cls, effect, index)
            -- Returns effect parameter with number <index> associated
            -- with <effect>

            local fName = "Reaper.EffectParameter.make"
            Logging.traceF(fName, ">>: effect = %s, index = %d",
                           effect, index)

            local result = cls:makeInstance()
            result._index  = index
            result._effect = effect

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- attributes
        -- ··········

        function EffectParameter:name ()
            -- Returns name of current effect parameter

            local fName = "Reaper.EffectParameter.name"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_nameNOLOG()
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function EffectParameter:effect ()
            -- Returns effect associated with current effect parameter

            local fName = "Reaper.EffectParameter.effect"
            Logging.traceF(fName, ">>: %s", self)
            local result = self._effect
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function EffectParameter:value ()
            -- Returns value of current effect parameter

            local fName = "Reaper.EffectParameter.value"
            Logging.traceF(fName, ">>: effectParameter = %s", self)

            local reaperTrack, reaperFXIndex, reaperParameterIndex =
                self:internalRepresentation()
            local _, result = 
                reaper.TrackFX_GetFormattedParamValue(reaperTrack,
                                                      reaperFXIndex,
                                                      reaperParameterIndex)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ················
        -- attribute change
        -- ················

        function EffectParameter:setValue (value)
            -- Sets value of current effect parameter to <value>

            local fName = "Reaper.EffectParameter.setValue"
            Logging.traceF(fName, ">>: effectParameter = %s, value = %s",
                           self, value)

            local reaperTrack, reaperFXIndex, reaperParameterIndex =
                self:internalRepresentation()
            -- reaper.TrackFX_SetEnabled(reaperTrack, reaperFXIndex - 1,
            --                           parameterIndex - 1)

            Logging.traceF(fName, "<<")
            return result
        end

        -- ··········
        -- conversion
        -- ··········

        function EffectParameter:__tostring ()
            -- Returns a simple string representation of effect

            return String.format("EffectParameter(effect = '%s',"
                                 .. " parameterIndex = %d,"
                                 .. " name = '%s')",
                                 self._effect, self._index,
                                 self:_nameNOLOG())
        end

        -- ------------------

        function EffectParameter:internalRepresentation ()
            -- Returns reaper representation of effect as a pair of
            -- reaper track and index

            local reaperTrack, reaperFXIndex =
                self._effect:internalRepresentation()
            return reaperTrack, reaperFXIndex, self._index - 1
        end

    -- =====================
    -- end EffectParameter
    -- =====================


    -- =======================
    -- class MediaItem
    -- =======================
        -- This class provides services for media items within a
        -- track.

        -- ------------------
        -- PRIVATE FEATURES
        -- ------------------

        function MediaItem._make (cls, peerObject)
            -- Constructs a wrapper project from <peerObject>

            local fName = "Reaper.MediaItem._make"
            Logging.traceF(fName, ">>")
            local result = cls:makeInstance(peerObject)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:_getParameter (parameterName)
            -- Returns parameter given by <parameterName> for media
            -- item

            local fName = "Reaper.MediaItem._getParameter"
            Logging.traceF(fName, ">>: %s, parameterName = %s",
                           self, parameterName)
            local reaperMediaItem = self._peerObject
            local result = reaper.GetMediaItemInfo_Value(reaperMediaItem,
                                                         parameterName)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:_setParameter (parameterName, value)
            -- Sets parameter given by <parameterName> for media item
            -- to <value> and returns whether action was successful

            local fName = "Reaper.MediaItem._setParameter"
            Logging.traceF(fName, ">>: %s, parameterName = %s, value = %s",
                           self, parameterName, value)
            local reaperMediaItem = self._peerObject
            local result = reaper.SetMediaItemInfo_Value(reaperMediaItem,
                                                         parameterName, value)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:_takeByIndexNOLOG (index)
            -- Returns take with <index> in media item

            local reaperTake =
                      reaper.GetMediaItemTake(self._peerObject, index - 1)
            return Take:_make(reaperTake)
        end

        -- ------------------

        function MediaItem:_takeCountNOLOG ()
            -- Returns count of all takes in media item

            return reaper.CountTakes(self._peerObject)
        end

        -- ------------------

        function MediaItem:_trackNOLOG ()
            -- Returns track for media item

            local reaperTrack = reaper.GetMediaItem_Track(self._peerObject)
            return Track:_make(reaperTrack)
        end

        -- ------------------
        -- EXPORTED ROUTINES
        -- ------------------

        -- ············
        -- construction
        -- ············

        function MediaItem.make (cls, track)
            -- Creates media item in <track>

            local fName = "Reaper.MediaItem.make"
            Logging.traceF(fName, ">>: %s", track)

            local reaperTrack = track._peerObject
            local reaperMediaItem = reaper.AddMediaItemToTrack(reaperTrack)
            -- add a dummy first take to media item
            reaper.AddTakeToMediaItem(reaperMediaItem)
            local result = MediaItem:_make(reaperMediaItem)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- attributes
        -- ··········

        function MediaItem:color ()
            -- Returns color of media item

            local fName = "Reaper.MediaItem.color"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("I_CUSTOMCOLOR")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:endPosition ()
            -- Returns end position of media item

            local fName = "Reaper.MediaItem.endPosition"
            Logging.traceF(fName, ">>: %s", self)
            local result = (self:_getParameter("D_POSITION")
                            + self:_getParameter("D_LENGTH"))
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:isLocked ()
            -- Tells whether media item is locked

            local fName = "Reaper.MediaItem.isLocked"
            Logging.traceF(fName, ">>: %s", self)
            local result = (self:_getParameter("C_LOCK") ~= 0)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:startPosition ()
            -- Returns start position of media item

            local fName = "Reaper.MediaItem.startPosition"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("D_POSITION")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:timeBase ()
            -- Returns time base of media item

            local fName = "Reaper.MediaItem.timeBase"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("C_BEATATTACHMODE")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ················
        -- attribute change
        -- ················

        function MediaItem:setColor (color)
            -- Sets color of media item to <color> and returns
            -- whether action was successful

            local fName = "Reaper.MediaItem.setColor"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_setParameter("I_CUSTOMCOLOR", color)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:setEndPosition (endPosition)
            -- Sets end position of media item to <endPosition>
            -- and returns whether action was successful

            local fName = "Reaper.MediaItem.setEndPosition"
            Logging.traceF(fName, ">>: item = %s, endPosition = %s",
                          self, endPosition)
            local position = self:_getParameter("D_POSITION")
            local length = math.max(endPosition - position, 0)
            local result = self:_setParameter("D_LENGTH", length)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:setLocked (isEnabled)
            -- Sets locking state of media item to <isEnabled> and
            -- returns whether action was successful

            local fName = "Reaper.MediaItem.setLocked"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_setParameter("C_LOCK", boolToInt(isEnabled))
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:setStartPosition (startPosition)
            -- Sets start position of media item to <startPosition>
            -- and returns whether action was successful

            local fName = "Reaper.MediaItem.setStartPosition"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_setParameter("D_POSITION", startPosition)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:setTimeBase (timeBase)
            -- Sets time base of media item to <timeBase> and returns
            -- whether action was successful

            local fName = "Reaper.MediaItem.setTimeBase"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_setParameter("C_BEATATTACHMODE", timeBase)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- relations
        -- ··········

        function MediaItem:activeTake ()
            -- Returns active take of media item, if any

            local fName = "Reaper.MediaItem.activeTake"
            Logging.traceF(fName, ">>: %s", self)
            local reaperTake = reaper.GetActiveTake(self._peerObject)
            local result = Take:_make(reaperTake)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:track ()
            -- Returns track for media item

            local fName = "Reaper.MediaItem.track"
            Logging.traceF(fName, ">>: %s", self)
            local reaperTrack = reaper.GetMediaItem_Track(self._peerObject)
            local result = Track:_make(reaperTrack)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:setTrack (track)
            -- Sets parent track of media item to <track> and returns
            -- whether move has succeeded

            local fName = "Reaper.MediaItem.setTrack"
            Logging.log(fName)
            Logging.traceF(fName,
                           ">>: item = %s, track = %s",
                           self, track)
            local reaperTrack = track._peerObject
            local isSuccessful =
                reaper.MoveMediaItemToTrack(self._peerObject, reaperTrack)
            Logging.traceF(fName, "<<: %s", isSuccessful)
            return isSuccessful
        end

        -- ------------------

        function MediaItem:takeCount ()
            -- Returns count of all takes in media item

            local fName = "Reaper.MediaItem.takeCount"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_takeCountNOLOG()
            Logging.traceF(fName, "<<: %d", result)
            return result
        end

        -- ------------------

        function MediaItem:takeByIndex (index)
            -- Returns take with <index> in media item

            local fName = "Reaper.MediaItem.takeByIndex"
            Logging.traceF(fName, ">>: %s, index = %d", self, index)
            local result = self:_takeByIndexNOLOG(index)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaItem:takeList ()
            -- Returns list of all takes in media item

            local fName = "Reaper.MediaItem.takeList"
            Logging.traceF(fName, ">>: %s", self)

            local result = List:make()

            for i = 1, self:_takeCountNOLOG() do
                local take = self:_takeByIndexNOLOG(i)
                result:append(take)
            end

            Logging.traceF(fName, "<<: %s", result:count())
            return result
        end

        -- ··········
        -- conversion
        -- ··········

        function MediaItem:__tostring ()
            -- Returns a simple string representation of media item

            local name
            local reaperMediaItem = self._peerObject

            if reaper.CountTakes(reaperMediaItem) == 0 then
                name = "???"
            else
                local reaperTake = reaper.GetMediaItemTake(reaperMediaItem, 0)
                _, name = reaper.GetSetMediaItemTakeInfo_String(reaperTake,
                                                                "P_NAME", "",
                                                                false)
            end

            return String.format("MediaItem('%s')", name)
        end

        -- ···········
        -- destruction
        -- ···········

        function MediaItem:delete ()
            -- Deletes media item

            local fName = "Reaper.MediaItem.delete"
            Logging.traceF(fName, ">>: %s", self)
            local track = self:_trackNOLOG()
            reaper.DeleteTrackMediaItem(track._peerObject, self._peerObject)
            Logging.traceF(fName, "<<")
        end

    -- ====================
    -- end MediaItem
    -- ====================


    -- =========================
    -- class MediaSource
    -- =========================
        -- This class provides services for media sources of takes.
        -- A media source of a take is either a PCM wave file or a
        -- MIDI event list.  Note that a media source does not have
        -- a direct peer object in reaper, it is represented by take
        -- and associated pcm source (if any).

        -- ------------------
        -- PRIVATE FEATURES
        -- --------------------

        function MediaSource:convertMeasureToTime (measure)
            -- Converts <measure> in project to time value

            local fName = "Reaper.MediaSource._convertMeasureToTime"
            Logging.traceF(fName, ">>: %d", measure)
            local st = measure .. ".1.00"
            Logging.traceF(fName, "--: st=%s", st)
            local time = reaper.parse_timestr_pos(st, 2)
            Logging.traceF(fName, "<<: %f", time)
            return time
        end

        -- --------------------

        function MediaSource:convertTimeToMeasure (time)
            -- Converts <time> in project to measure value

            local fName = "Reaper.MediaSource._convertTimeToMeasure"
            Logging.traceF(fName, ">>: %f", time)
            local st = ""
            st = reaper.format_timestr_pos(time, st, 2)
            local timeList = String.split(st, ".")
            local measure = tonumber(timeList:first())
            Logging.traceF(fName, "<<: p=%s, m=%d", st, measure)
            return measure
        end

        -- ------------------
        -- EXPORTED ROUTINES
        -- ------------------

        -- ············
        -- construction
        -- ············

        function MediaSource.make (cls, take)
            -- Returns media source associated with <take>

            local fName = "Reaper.MediaSource.make"
            Logging.traceF(fName, ">>: %s", take)
            local pcmSource =
                reaper.GetMediaItemTake_Source(take._peerObject)
            local result = cls:makeInstance()
            result.name      = take:name()
            result.take      = take
            result.pcmSource = pcmSource

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- attributes
        -- ··········

        function MediaSource:duration ()
            -- Tells the duration in seconds for a PCM source and in
            -- quarter notes for a MIDI source

            local fName = "Reaper.MediaSource.duration"
            Logging.traceF(fName, ">>: %s", self)
            local duration, isQuarterNotes =
                      reaper.GetMediaSourceLength(self.pcmSource)
            Logging.traceF(fName, "<<: duration = %f, isQuarterNotes = %s",
                           duration, isQuarterNotes)
            return duration, isQuarterNotes
        end

        -- ------------------

        function MediaSource:isMIDI ()
            -- Tells whether media source is MIDI or PCM wave

            local fName = "Reaper.MediaSource.isMIDI"
            Logging.traceF(fName, ">>: %s", self)
            local result = self.take:isMIDI()
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MediaSource:measureBarTickList ()
            -- Returns a list of MIDI ticks for the measure bars in
            -- media source (from begin to end of the media source);
            -- the measure division is affected by the take associated
            -- with the media source

            local fName = "Reaper.MediaSource.measureBarTickList"
            Logging.traceF(fName, ">>: %s", self)

            local tickToTimeProc = reaper.MIDI_GetProjTimeFromPPQPos
            local qnToTickProc   = reaper.MIDI_GetPPQPosFromProjQN
            local timeToTickProc =
                      function (take, time)
                          local reaperTake = take._peerObject
                          return reaper.MIDI_GetPPQPosFromProjTime(reaperTake,
                                                                   time)
                      end
            local tickToQNProc   =
                      function (take, ticks)
                          local reaperTake = take._peerObject
                          return reaper.MIDI_GetProjQNFromPPQPos(reaperTake,
                                                                 ticks)
                      end
            local qnToTimeProc =
                      function (take, timeInQN)
                          local reaperTake = take._peerObject
                          local tickTime = qnToTickProc(reaperTake, timeInQN)
                          return tickToTimeProc(reaperTake, tickTime)
                      end

            local take = self.take
            local startTime = take:startPosition() - take:mediaSourceOffset()
            local endTime
            local initialMidiTicks
            local duration, isQuarterNotes = self:duration()

            if not isQuarterNotes then
                endTime = startTime + duration
            else
                initialMidiTicks = timeToTickProc(take, startTime)
                local startTimeInQN =
                          round(tickToQNProc(take, initialMidiTicks), 3)
                local endTimeInQN = round(startTimeInQN + duration, 3)
                Logging.traceF(fName,
                               "--: startTimeInQN = %s, endTimeInQN = %s",
                               startTimeInQN, endTimeInQN)
                startTime = qnToTimeProc(take, startTimeInQN)
                endTime   = qnToTimeProc(take, endTimeInQN)
            end

            Logging.traceF(fName,
                           "--: startTime = %f, endTime = %f",
                           startTime, endTime)

            local firstMeasure = MediaSource:convertTimeToMeasure(startTime)
            local lastMeasure  = MediaSource:convertTimeToMeasure(endTime)
            initialMidiTicks = timeToTickProc(take, startTime)
            local measureBarTickList = List:make()

            Logging.traceF(fName,
                           "--: first = %d, last = %d",
                           firstMeasure, lastMeasure)

            for measure = firstMeasure, lastMeasure do
                local time = MediaSource:convertMeasureToTime(measure)
                local midiTicks = timeToTickProc(take, time)
                local relativeMeasure = measure - firstMeasure + 1
                local relativeMidiTicks =
                    math.floor(midiTicks - initialMidiTicks)
                measureBarTickList:set(relativeMeasure, relativeMidiTicks)
                Logging.traceF(fName,
                               "--: %f -> %f",
                               relativeMeasure, relativeMidiTicks)
            end

            Logging.traceF(fName, "<<: %s", measureBarTickList)
            return measureBarTickList
        end

        -- --------------------

        function MediaSource:midiNoteCount ()
            -- Returns count of all MIDI notes in media source

            local fName = "Reaper.MediaSource.midiNoteCount"
            Logging.traceF(fName, ">>: %s", self)
            local result = reaper.MIDI_CountEvts(self.take._peerObject)
            Logging.traceF(fName, "<<: %d", result)
            return result
        end

        -- ------------------

        function MediaSource:midiNoteByIndex (index)
            -- Returns MIDI note with <index> in media source

            local reaperTake = self.take._peerObject
            local isOkay, _, _, startPosition, endPosition,
                  _, pitch, velocity = reaper.MIDI_GetNote(reaperTake,
                                                           index - 1)
            local result = MidiNote:make(pitch, velocity,
                                         startPosition, endPosition)
            return result
        end

        -- ------------------

        function MediaSource:midiNoteList ()
            -- Returns list of all MIDI notes in media source

            local fName = "Reaper.MediaSource.midiNoteList"
            Logging.traceF(fName, ">>: %s", self)

            local result = List:make()

            for i = 1, self:midiNoteCount() do
                result:set(i, self:midiNoteByIndex(i))
            end

            Logging.traceF(fName, "<<: %d", result:count())
            return result
        end

        -- ··········
        -- conversion
        -- ··········

        function MediaSource:__tostring ()
            -- Returns a simple string representation of media source

            return String.format("MediaSource('%s')", self.name)
        end

    -- ===============
    -- end MediaSource
    -- ===============


    -- ===============
    -- class MidiEvent
    -- ===============
        -- The routines in this class support MIDI events in a Reaper
        -- take.

        -- ············
        -- construction
        -- ············

        function MidiEvent.makeControlEvent (cls, take, eventIndex)
            -- Constructs a midi take event from <take> and
            -- <eventIndex>

            local fName = "Reaper.MidiEvent.makeControlEvent"
            Logging.traceF(fName,
                           ">>: take = %s, index = %s",
                           take, eventIndex)

            local _, isSelected, isMuted, startPosition,
                  channelMessage, channel, channelMsg1,
                  channelMsg2 = reaper.MIDI_GetCC(take._peerObject,
                                                  eventIndex - 1)

            local result = cls:makeInstance()
            result.kind           = MidiEventKind.controlCode
            result.isSelected     = isSelected
            result.isMuted        = isMuted
            result.startPosition  = startPosition
            result.channel        = channel + 1

            -- control event specific attributes
            result.channelMessage = channelMessage
            result.messagePart1   = channelMsg1
            result.messagePart2   = channelMsg2

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function MidiEvent.makeNoteEvent (cls, take, eventIndex)
            -- Constructs a midi note event from <take> and
            -- <eventIndex>

            local fName = "Reaper.MidiEvent.makeNoteEvent"
            Logging.traceF(fName,
                           ">>: take = %s, index = %s",
                           take, eventIndex)

            local _, isSelected, isMuted, startPosition, endPosition,
                  channel, pitch, velocity =
                      reaper.MIDI_GetNote(take._peerObject, eventIndex - 1)

            local result = cls:makeInstance()
            result.kind           = MidiEventKind.note
            result.isSelected     = isSelected
            result.isMuted        = isMuted
            result.startPosition  = startPosition
            result.channel        = channel + 1

            -- note specific attributes
            result.pitch          = pitch
            result.velocity       = velocity
            result.endPosition    = endPosition

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- conversion
        -- ··········

        function MidiEvent:__tostring ()
            -- Returns a simple string representation of midi event

            local template = ("kind = %s, isSelected = %s, isMuted = %s,"
                              .. " startPosition = %s, channel = %s,")
            st = String.format(template,
                               self.kind, self.isSelected, self.isMuted,
                               self.startPosition, self.channel)

            -- extend the result by kind-specific data
            if self.kind == MidiEventKind.controlCode then
                template = (" channelMessage = %s, messagePart1 = %s,"
                            .. " messagePart2 = %s")
                st = st .. String.format(template,
                                         self.channelMessage,
                                         self.messagePart1,
                                         self.messagePart2)
            elseif self.kind == MidiEventKind.note then
                template = (" endPosition = %s, pitch = %s,"
                            .. " velocity = %s")
                st = st .. String.format(template,
                                         self.endPosition,
                                         self.pitch, self.velocity)
            end
             
            return "MidiEvent(" .. st .. ")"
        end

    -- =============
    -- end MidiEvent
    -- =============


    -- ===================
    -- class MidiEventList
    -- ===================
        -- The routines in this class provide lists of MIDI events in
        -- a Reaper take.

        -- ············
        -- construction
        -- ············

        function MidiEventList.make (cls, take, eventKind)
            -- Constructs a new midi event list and remembers
            -- enclosing <take> and <eventKind> of elements in list

            local fName = "Reaper.MidiEventList.make"
            Logging.traceF(fName,
                           ">>: take = %s, eventKind = %s",
                           take, eventKind)

            local result = List.make(cls)
            result._take      = take
            result._eventKind = eventKind

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ················
        -- attribute change
        -- ················

        function MidiEventList:deleteEvent (eventIndex)
            -- Deletes event at <eventIndex> from event list wrapper
            -- and from underlying take event list

            local fName = "Reaper.MidiEventList.deleteEvent"
            Logging.traceF(fName, ">>: eventIndex = %s", eventIndex)

            local errorMessage = "bad event with index " .. eventIndex
            assert(1 <= eventIndex and eventIndex <= self:count(),
                   errorMessage)

            local reaperTake = self._take._peerObject

            if self._eventKind == MidiEventKind.note then
                reaper.MIDI_DeleteNote(reaperTake, eventIndex - 1)
            elseif self._eventKind == MidiEventKind.controlCode then
                reaper.MIDI_DeleteCC(reaperTake, eventIndex - 1)
            end

            self:remove(eventIndex)

            Logging.traceF(fName, "<<")
        end

        -- ··········
        -- conversion
        -- ··········

        function MidiEventList:__tostring ()
            -- Returns a simple string representation of midi event
            -- list

            local st = String.format("take = %s, kind = %s, list = %s",
                                     self._take, self._eventKind,
                                     List.__tostring(self))
            return "MidiEventList(" .. st .. ")"
        end

    -- =================
    -- end MidiEventList
    -- =================

    -- =============
    -- class Project
    -- =============

        -- ------------------
        -- PRIVATE ROUTINES
        -- ------------------

        function Project._make (cls, peerObject)
            -- Constructs a wrapper project from <peerObject>

            local fName = "Reaper.Project._make"
            Logging.traceF(fName, ">>")

            local result = cls:makeInstance(peerObject)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Project:_regionByIndexNOLOG (index)
            -- Returns region with <index> in project

            local selectionProc =
                function (project, index)
                    local reaperProject = project._peerObject
                    local _, _, _, _, _, regionIdentification =
                        reaper.EnumProjectMarkers2(reaperProject, index - 1)
                    return Region:_make({project, regionIdentification})
            end
            local regionCount = self:_regionCountNOLOG()
            local result =
                      Generics.findElementByIndexNOLOG(self, index,
                                                       Region,
                                                       selectionProc,
                                                       regionCount)
            return result
        end

        -- ------------------

        function Project:_regionCountNOLOG ()
            -- Returns count of all regions in project

            local _, markerCount, regionCount =
                reaper.CountProjectMarkers(self._peerObject)
            return markerCount + regionCount
        end

        -- ------------------

        function Project:_selectedMediaItemByIndexNOLOG (index)
            -- Returns selected media item with <index> in project

            local rawSelectionProc = reaper.GetSelectedMediaItem
            local count = self:_selectedMediaItemCountNOLOG()
            local result =
                Generics.findElementByIndexRawNOLOG(self, index,
                                                    MediaItem,
                                                    rawSelectionProc,
                                                    count)
            return result
        end

        -- ------------------

        function Project:_selectedMediaItemCountNOLOG ()
            -- Returns count of all selected media items in project

            return reaper.CountSelectedMediaItems(self._peerObject)
        end

        -- ------------------

        function Project:trackByIndexNOLOG (index)
            -- Returns track with <index> in project without logging

            local result =
                      Generics.findElementByIndexRaw(self, index,
                                                     Track,
                                                     reaper.GetTrack,
                                                     self:trackCount())
            return result
        end

        -- ------------------
        -- EXPORTED ROUTINES
        -- ------------------

        -- ············
        -- construction
        -- ············

        function Project.current ()
            -- Returns current project

            local fName = "Reaper.Project.current"
            Logging.traceF(fName, ">>")
            local result = Project:_make(0)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- attributes
        -- ··········

        function Project:cursorPosition ()
            -- Returns the edit cursor position in project

            local fName = "Reaper.Project.cursorPosition"
            Logging.traceF(fName, ">>: %s", self)
            local result = reaper.GetCursorPositionEx(self._peerObject)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Project:description ()
            -- Returns the description of project with lines separated
            -- by newlines

            local fName = "Reaper.Project.description"
            Logging.traceF(fName, ">>: %s", self)

            local reaperProject = self._peerObject
            local result =
                reaper.GetSetProjectNotes(reaperProject, false, "")
            result = String.globalReplace(result, "\13\10", String.newline)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Project:path ()
            -- Returns the file path of project

            local fName = "Reaper.Project.path"
            Logging.traceF(fName, ">>: %s", self)

            local reaperProject = self._peerObject
            local result
            result = reaper.GetProjectPath(reaperProject, result)
            result = String.globalReplace(result, "\\", "/")

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Project:timeOffset ()
            -- Returns the time offset within project

            local fName = "Reaper.Project.timeOffset"
            Logging.traceF(fName, ">>: %s", self)
            local result = reaper.GetProjectTimeOffset(self._peerObject,
                                                       false)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ················
        -- attribute change
        -- ················

        function Project:setCursorPosition (cursorPosition)
            -- Sets the edit cursor position to <cursorPosition>

            local fName = "Reaper.Project.setCursorPosition"
            Logging.traceF(fName,
                           ">>: self = %s, cursorPosition = %s",
                           self, cursorPosition)
            reaper.SetEditCurPos2(self._peerObject, cursorPosition,
                                  false, false)
            Logging.traceF(fName, "<<")
        end

        -- ··········
        -- conversion
        -- ··········

        function Project:__tostring ()
            -- Returns a simple string representation of project

            return String.format("Project(%d)", self._peerObject)
        end

        -- ·······
        -- regions
        -- ·······

        function Project:regionByIndex (index)
            -- Returns region with <index> in project

            local fName = "Reaper.Project.regionByIndex"
            Logging.traceF(fName, ">>: %s, %d", self, index)
            local result = self:_regionByIndexNOLOG(index)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Project:regionCount ()
            -- Returns count of all regions in project

            local fName = "Reaper.Project.regionCount"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_regionCountNOLOG()
            Logging.traceF(fName, "<<: %d", result)
            return result
        end

        -- ------------------

        function Project:regionList ()
            -- Returns list of all regions in project

            local fName = "Reaper.Project.regionList"
            Logging.traceF(fName, ">>: %s", self)

            local result = Generics.makeList(self, Region,
                                             self._regionByIndexNOLOG,
                                             self:_regionCountNOLOG())
            Logging.traceF(fName, "<<")
            return result
        end

        -- ....................
        -- selected media items
        -- ....................

        function Project:selectedMediaItemByIndex (index)
            -- Returns selected media item with <index> in project

            local fName = "Reaper.Project.selectedMediaItemByIndex"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_selectedMediaItemByIndexNOLOG(index)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Project:selectedMediaItemCount ()
            -- Returns count of all selected media items in <project>

            local fName = "Reaper.Project.selectedMediaItemCount"
            Logging.traceF(fName, ">>: %s", self)

            local elementCountProc =
                      function (project)
                          local reaperProject = project._peerObject
                          return reaper.CountSelectedMediaItems(reaperProject)
                      end
            local result = Generics.elementCountNew(self, elementCountProc)

            Logging.traceF(fName, "<<: %d", result)
            return result
        end

        -- ------------------

        function Project:selectedMediaItemList ()
            -- Returns list of selected media items in project

            local fName = "Reaper.Project.selectedMediaItemList"
            Logging.traceF(fName, ">>: %s", self)
            local count = self:_selectedMediaItemCountNOLOG()
            local result =
                      Generics.makeList(self, MediaItem,
                                        self._selectedMediaItemByIndexNOLOG,
                                        count)
            Logging.traceF(fName, "<<")
            return result
        end

        -- ······
        -- tracks
        -- ······

        function Project:makeTrack (index)
            -- Creates new track in <project>; if <index> is set, it
            -- gives the index of the newly created track, otherwise
            -- it is added at the end

            local fName = "Reaper.Project.makeTrack"
            Logging.traceF(fName, ">>: project = %s, index = %s",
                           self, index)

            local maximumIndex = self:trackCount() + 1
            index = iif(index == nil, maximumIndex, index)

            assert(1 <= index and index <= maximumIndex,
                   "bad index for track creation: " .. index)
            reaper.InsertTrackAtIndex(index - 1, false)
            local reaperTrack =
                reaper.GetTrack(self._peerObject, index - 1)
            local result = Track:_make(reaperTrack)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Project:insertMediaFileAfterTrackIndex (fileName,
                                                         trackIndex,
                                                         startTime)
            -- Inserts media file given by <fileName> into new track
            -- after <trackIndex>, where first track has index 1;
            -- <startTime> gives the start position for insertion, if
            -- nil the current cursor position is used

            local fName = "Reaper.Project.insertMediaAfterTrackIndex"
            Logging.traceF(fName,
                           ">>: self = %s, index = %s, startTime = %s",
                           self, trackIndex, startTime)

            local oldCursorPosition

            if startTime ~= nil then
                -- save edit cursor position and set cursor to
                -- <startTime>
                oldCursorPosition = self:cursorPosition()
                self:setCursorPosition(startTime)
            end

            local track = self:trackByIndex(trackIndex)
            track:setOnlySelected()
            local result = (reaper.InsertMedia(fileName, 1) > 0)
            local newTrackCount = self:trackCount()

            if startTime ~= nil then
                -- restore edit cursor position
                self:setCursorPosition(oldCursorPosition)
            end

            Logging.traceF(fName,
                           "<<: result = %s, newTrackCount = %s",
                           result, newTrackCount)
            return result
        end

        -- ------------------

        function Project:trackByIndex (index)
            -- Returns track with <index> in project

            local fName = "Reaper.Project.trackByIndex"
            Logging.traceF(fName,
                           ">>: self = %s, index = %s", self, index)
            local result = Project:trackByIndexNOLOG(index)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Project:trackByName (trackName)
            -- Returns track named <trackName> in project

            local fName = "Reaper.Project.trackByName"
            Logging.traceF(fName,
                           ">>: self = %s, name = %s", self, trackName)

            local result
            local count = self:trackCount()
            
            for i = 1, count do
                local track = Project:trackByIndexNOLOG(i)

                if track:name() == trackName then
                    result = track
                    break
                end
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Project:trackCount ()
            -- Returns count of all tracks in project

            local fName = "Reaper.Project.trackCount"
            Logging.traceF(fName, ">>: %s", self)
            local result = reaper.CountTracks(self._peerObject)
            Logging.traceF(fName, "<<: %d", result)
            return result
        end

        -- ------------------

        function Project:trackList ()
            -- Returns list of all tracks in project

            local fName = "Reaper.Project.trackList"
            Logging.traceF(fName, ">>: %s", self)
            local result = Generics.makeList(self, Track,
                                             self.trackByIndex,
                                             self:trackCount())
            Logging.traceF(fName, "<<")
            return result
        end

    -- ===========
    -- end Project
    -- ===========


    -- ============
    -- class Region
    -- ============
        -- A region is a named range on the timeline within a project.
        -- A region can also be a marker; then end position and start
        -- position coincide.  Note that there is no direct peer
        -- object in reaper: a region is characterized by project and
        -- its identification.

        -- ------------------
        -- PRIVATE ROUTINES
        -- ------------------

        function Region._make (cls, dataPair)
            -- Constructs a wrapper region from <dataPair> consisting
            -- of <project> and <identification>

            local fName = "Reaper.Region._make"
            project        = dataPair[1]
            identification = dataPair[2]
            Logging.traceF(fName,
                           ">>: project = %s, identification = %s",
                           project, identification)

            local result = cls:makeInstance()
            result._project        = project
            result._identification = identification

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Region:_descriptor ()
            -- Returns a descriptor with data for the region

            local fName = "Reaper.Region._descriptor"
            Logging.traceF(fName, ">>: %s", self)

            local project        = self._project
            local identification = self._identification

            -- find correct marker in list of markers
            local regionDescriptor

            for regionIndex = 1, project:regionCount() do
                regionDescriptor =
                    Region:_getDescriptorAtIndex(project, regionIndex)

                if regionDescriptor.identification == identification then
                    break
                end
            end

            local st = String.format("--%s: no region with identification %s",
                                     fName, identification)
            assert(regionDescriptor.identification == identification, st)

            Logging.traceF(fName, "<<: %s", regionDescriptor)
            return regionDescriptor
        end

        -- --------------------

        function Region:_descriptorToString ()
            -- Returns string representation of region descriptor

            local st = ("RegionDescriptor("
                        .. "project = %s, identification = %s,"
                        .. " name = %s, isRegion = %s,"
                        .. " startPosition = %s, endPosition = %s,"
                        .. " color = %s"
                        .. ")")
            return String.format(st,
                                 self.project, self.identification,
                                 self.name, self.isRegion,
                                 self.startPosition, self.endPosition,
                                 self.color)
        end

        -- --------------------

        function Region:_getDescriptorAtIndex (project, regionIndex)
            -- Returns a descriptor with data for the region in
            -- <project> at physical index <regionIndex>

            local fName = "Region._getDescriptorAtIndex"
            Logging.traceF(fName, ">>: project = %s, regionIndex = %d",
                           project, regionIndex)

            local regionCount = project:regionCount()
            local st = String.format("--%s: physical region index"
                                     .. " out of range (1, %d): %d",
                                     fName, regionCount, regionIndex)
            assert(1 <= regionIndex and regionIndex <= regionCount, st)

            local reaperProject = project._peerObject
            local _, isRegion, startPosition, endPosition, name, number,
                  color = reaper.EnumProjectMarkers3(reaperProject,
                                                     regionIndex - 1)
            local result = {
                      project = project,
                      identification = number,
                      isRegion = isRegion,
                      startPosition = startPosition,
                      endPosition = endPosition,
                      name = name,
                      color = color }
            setmetatable(result,
                         { __tostring = Region._descriptorToString})

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Region:_update (regionDescriptor)
            -- Updates region in Reaper by data in <regionDescriptor>
            -- tuple

            local fName = "Region._update"
            Logging.traceF(fName, ">>: %s", regionDescriptor)
            reaper.SetProjectMarker3(regionDescriptor.project,
                                     regionDescriptor.identification,
                                     regionDescriptor.isRegion,
                                     regionDescriptor.startPosition,
                                     regionDescriptor.endPosition,
                                     regionDescriptor.name,
                                     regionDescriptor.color)
            Logging.traceF(fName, "<<")
        end

        -- ------------------
        -- EXPORTED ROUTINES
        -- --------------------

        -- ············
        -- construction
        -- ············

        function Region.make (cls, project)
            -- Creates new region in <project>; a region is just
            -- represented by a pair of project and index

            local fName = "Reaper.Region.make"
            Logging.traceF(fName, ">>: %s", project)

            local identification = reaper.AddProjectMarker(project, true,
                                                           0, 1, "", -1)
            local result = Region:_make({project, identification})
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- attributes
        -- ··········

        function Region:project ()
            -- Gets project of region

            local fName = "Reaper.Region.project"
            Logging.traceF(fName, ">>: %s", self)
            local result = self._project
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Region:identification ()
            -- Gets identification of region

            local fName = "Reaper.Region.identification"
            Logging.traceF(fName, ">>: %s", self)
            local result = self._identification
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Region:isRegion ()
            -- Tells whether <self> is a region (or a marker)

            local fName = "Reaper.Region.isRegion"
            Logging.traceF(fName, ">>: %s", self)
            local regionDescriptor = self:_descriptor()
            local result = regionDescriptor.isRegion
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Region:startPosition ()
            -- Gets start position of region

            local fName = "Reaper.Region.startPosition"
            Logging.traceF(fName, ">>: %s", self)
            local regionDescriptor = self:_descriptor()
            local result = regionDescriptor.startPosition
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Region:endPosition ()
            -- Gets end position of region

            local fName = "Reaper.Region.endPosition"
            Logging.traceF(fName, ">>: %s", self)
            local regionDescriptor = self:_descriptor()
            local result = regionDescriptor.endPosition
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Region:name ()
            -- Gets name of region

            local fName = "Reaper.Region.name"
            Logging.traceF(fName, ">>: %s", self)
            local regionDescriptor = self:_descriptor()
            local result = regionDescriptor.name
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Region:color ()
            -- Gets color of region

            local fName = "Reaper.Region.color"
            Logging.traceF(fName, ">>: %s", self)
            local regionDescriptor = self:_descriptor()
            local result = regionDescriptor.color
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ················
        -- attribute change
        -- ················

        function Region:setAsRegion (isRegion)
            -- Sets whether <self> is a region (or a marker)

            local fName = "Reaper.Region.setAsRegion"
            Logging.traceF(fName, ">>: region = %s, isRegion = %s",
                           self, isRegion)
            local regionDescriptor = self:_descriptor()
            regionDescriptor.isRegion = isRegion
            Region:_update(regionDescriptor)
            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function Region:setStartPosition (startPosition)
            -- Sets start position of region to <startPosition>

            local fName = "Reaper.Region.setStartPosition"
            Logging.traceF(fName, ">>: region = %s, startPosition = %s",
                           self, startPosition)
            local regionDescriptor = self:_descriptor()
            regionDescriptor.startPosition = startPosition
            Region:_update(regionDescriptor)
            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function Region:setEndPosition (endPosition)
            -- Sets end position of region to <endPosition>

            local fName = "Reaper.Region.setEndPosition"
            Logging.traceF(fName, ">>: region = %s, endPosition = %s",
                           self, endPosition)
            local regionDescriptor = self:_descriptor()
            regionDescriptor.endPosition = endPosition
            Region:_update(regionDescriptor)

            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function Region:setName (name)
            -- Sets name of region to <name>

            local fName = "Reaper.Region.setName"
            Logging.traceF(fName, ">>: region = %s, name = %s",
                           self, name)
            local regionDescriptor = self:_descriptor()
            regionDescriptor.name = name
            Region:_update(regionDescriptor)
            Logging.traceF(fName, "<<")
        end

        -- --------------------

        function Region:setColor (color)
            -- Sets color of region to <color>

            local fName = "Reaper.Region.setColor"
            Logging.traceF(fName, ">>: region = %s, color = %d",
                          _self, color)
            local regionDescriptor = self:_descriptor()
            regionDescriptor.color = color
            Region:_update(regionDescriptor)
            Logging.traceF(fName, "<<")
        end

        -- ··········
        -- conversion
        -- ··········

        function Region:__tostring ()
            -- Returns a simple string representation of region

            return String.format("Region(%s.%s)",
                                 self._project, self._identification)
        end

        -- ···········
        -- destruction
        -- ···········

        function Region:delete ()
            -- Deletes region

            local fName = "Reaper.Region.delete"
            Logging.traceF(fName, ">>: %s", self)
            local regionDescriptor = self:_descriptor()
            local reaperProject = regionDescriptor.project._peerObject
            reaper.DeleteProjectMarker(reaperProject,
                                       regionDescriptor.identification,
                                       regionDescriptor.isRegion)
            Logging.traceF(fName, "<<")
        end

    -- ==========
    -- end Region
    -- ==========

    -- ==========
    -- class Take
    -- ==========

        -- --------------------
        -- PRIVATE FEATURES
        -- --------------------

        function Take._make (cls, peerObject)
            -- Constructs a wrapper take from <peerObject>

            local fName = "Reaper.Take._make"
            Logging.traceF(fName, ">>")

            local result = cls:makeInstance(peerObject)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Take:_getSetData (parameterName, isSetOperation,
                                   newValue)
            -- Gets or sets information in take specified by
            -- <parameterName>; <isSetOperation> tells whether the
            -- parameter is changed, in that case <newValue> is the
            -- value to be written

            local fName = "Reaper.Take._getSetData"
            Logging.traceF(fName,
                           ">>: %s, parameter = %s,"
                           .. " isSet = %s, value = %s",
                           self, parameterName, isSetOperation,
                           newValue)

            local isStringParameter = (parameterName == "P_NAME")
            local reaperTake = self._peerObject
            local proc
            local result

            if isStringParameter then
                local newValue = iif(isSetOperation, newValue, "")
                proc = reaper.GetSetMediaItemTakeInfo_String
                _, result = proc(reaperTake, parameterName,
                                 newValue, isSetOperation)
            elseif isSetOperation then
                proc = reaper.SetMediaItemTakeInfo_Value
                result = proc(reaperTake, parameterName, newValue)
            else
                proc = reaper.GetMediaItemTakeInfo_Value
                result = proc(reaperTake, parameterName)
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------
        -- EXPORTED ROUTINES
        -- --------------------

        -- ··········
        -- attributes
        -- ··········

        function Take:isMIDI ()
            -- Tells whether take contains MIDI data

            local fName = "Reaper.Take.isMIDI"
            Logging.traceF(fName, ">>: %s", self)
            local result = reaper.TakeIsMIDI(self._peerObject)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Take:mediaSourceOffset ()
            -- Returns (positive) offset time in seconds of associated
            -- media source for take

            local fName = "Reaper.Take.mediaSourceOffset"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getSetData("D_STARTOFFS", false)
            Logging.traceF(fName, "<<: %f", result)
            return result
        end

        -- ------------------

        function Take:name ()
            -- Returns name of take

            local fName = "Reaper.Take.name"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getSetData("P_NAME", false)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- --------------------

        function Take:midiEventList (eventKind)
            -- Returns list of all midi events in take of given
            -- <eventKind>

            local fName = "Reaper.Take.midiEventList"
            Logging.traceF(fName,
                           ">>: self = %s, eventKind = %s",
                           self, eventKind)

            local reaperTake = self._peerObject
            local _, noteEventCount, ccEventCount, textEventCount =
                      reaper.MIDI_CountEvts(reaperTake)
            local result = MidiEventList:make(self, eventKind)

            if eventKind == MidiEventKind.note then
                for i = 1, noteEventCount do
                    local midiNoteEvent = MidiEvent:makeNoteEvent(self, i)
                    result:append(midiNoteEvent)
                end
            end

            if eventKind == MidiEventKind.controlCode then
                for i = 1, ccEventCount do
                    local midiCCEvent = MidiEvent:makeControlEvent(self, i)
                    result:append(midiCCEvent)
                end
            end

            Logging.traceF(fName, "<<: %d events", result:count())
            return result
        end

        -- --------------------

        function Take:midiResolution ()
            -- Returns the ticks per quarter note in take

            local fName = "Reaper.Take.midiResolution"
            Logging.traceF(fName, ">>: %s", self)

            local reaperTake = self._peerObject
            local quarterNotesToMidiTicks =
                reaper.MIDI_GetPPQPosFromProjQN
            local result = (quarterNotesToMidiTicks(reaperTake, 1)
                            - quarterNotesToMidiTicks(reaperTake, 0))

            Logging.traceF(fName, "<<: %d", result)
            return result
        end

        -- ------------------

        function Take:parent ()
            -- Returns parent media item of take

            local fName = "Reaper.Take.parent"
            Logging.traceF(fName, ">>: %s", self)
            local reaperMediaItem =
                reaper.GetMediaItemTake_Item(self._peerObject)
            local result = MediaItem:_make(reaperMediaItem)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Take:setMediaStartOffset (startOffset)
            -- Sets start time of associated media to <startOffset>

            local fName = "Reaper.Take.setMediaStartOffset"
            Logging.traceF(fName,
                           ">>: self = %s, startOffset = %s",
                           self, startOffset)
            self:_getSetData("D_STARTOFFS", true, startOffset)
            Logging.traceF(fName, "<<")
        end

        -- ------------------

        function Take:setMidiEvent (index, midiEvent)
            -- Writes <midiEvent> to event list at <index>

            local fName = "Reaper.Take.setMidiEvent"
            Logging.traceF(fName,
                           ">>: self = %s, index = %s, event = %s",
                           self, index, midiEvent)

            local reaperTake = self._peerObject

            if midiEvent.kind == MidiEventKind.note then
                reaper.MIDI_SetNote(reaperTake, index - 1,
                                    midiEvent.isSelected,
                                    midiEvent.isMuted,
                                    midiEvent.startPosition,
                                    midiEvent.endPosition,
                                    midiEvent.channel - 1,
                                    midiEvent.pitch,
                                    midiEvent.velocity,
                                    true)
            elseif midiEvent.kind == MidiEventKind.controlCode then
                reaper.MIDI_SetCC(reaperTake, index - 1,
                                  midiEvent.isSelected,
                                  midiEvent.isMuted,
                                  midiEvent.startPosition,
                                  midiEvent.channelMessage,
                                  midiEvent.channel - 1,
                                  midiEvent.message1,
                                  midiEvent.message2,
                                  true)
            end

            Logging.traceF(fName, "<<")
        end

        -- ------------------

        function Take:startPosition ()
            -- Returns start position of take

            local fName = "Reaper.Take.startPosition"
            Logging.traceF(fName, ">>: %s", self)
            local parentMediaItem = self:parent()
            local result = parentMediaItem:startPosition()
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Take:endPosition ()
            -- Returns end position of take

            local fName = "Reaper.Take.endPosition"
            Logging.traceF(fName, ">>: %s", self)
            local parentMediaItem = self:parent()
            local result = parentMediaItem:endPosition()
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ················
        -- attribute change
        -- ················

        function Take:setName (name)
            -- Sets name of take to <name>

            local fName = "Reaper.Take.setName"
            Logging.traceF(fName, ">>: take = %s, name = %s",
                           self, name)
            self:_getSetData("P_NAME", true, name)
            Logging.traceF(fName, "<<")
        end

        -- ··········
        -- relations
        -- ··········

        function Take:mediaSource ()
            -- Returns associated media source for take

            local fName = "Reaper.Take.mediaSource"
            Logging.traceF(fName, ">>: %s", self)
            local result = MediaSource:make(self)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- conversion
        -- ··········

        function Take:__tostring ()
            -- Returns a simple string representation of take

            local reaperTake = self._peerObject
            local _, takeName =
                      reaper.GetSetMediaItemTakeInfo_String(reaperTake,
                                                            "P_NAME", "",
                                                            false)
            return String.format("Take('%s')", takeName)
        end

    -- ========
    -- end Take
    -- ========

    -- ===========
    -- class Track
    -- ===========

        -- --------------------
        -- PRIVATE FEATURES
        -- --------------------

        function Track._make (cls, peerObject)
            -- Constructs a wrapper track from <peerObject>

            local fName = "Reaper.Track._make"
            Logging.traceF(fName, ">>")

            local result = cls:makeInstance(peerObject)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Track:effectCountNOLOG ()
            -- Returns count of all effects in track

            return reaper.TrackFX_GetCount(self._peerObject)
        end

        -- ------------------

        function Track:_getSetData (parameterName, isSetOperation,
                                    newValue)
            -- Gets or sets information in track specified by
            -- <parameterName>; <isSetOperation> tells whether the
            -- parameter is changed, in that case <newValue> is the
            -- value to be written

            local reaperTrack = self._peerObject
            local isStringParameter = String.hasPrefix(parameterName,
                                                       "P_")
            local _, result

            if isStringParameter then
                newValue = iif(isSetOperation, newValue, "")
                _, result =
                    reaper.GetSetMediaTrackInfo_String(reaperTrack,
                                                       parameterName,
                                                       newValue,
                                                       isSetOperation)
            elseif isSetOperation then
                result = reaper.SetMediaTrackInfo_Value(reaperTrack,
                                                        parameterName,
                                                        newValue)
            else
                result = reaper.GetMediaTrackInfo_Value(reaperTrack,
                                                        parameterName)
            end

            return result
        end

        -- --------------------

        function Track:mediaItemByIndexNOLOG (index)
            -- Returns media item with <index> in track

            local mediaItemCount = self:mediaItemCountNOLOG()
            return Generics.findElementByIndexRawNOLOG
                                (self, index, MediaItem,
                                 reaper.GetTrackMediaItem,
                                 mediaItemCount)
        end

        -- ------------------

        function Track:mediaItemCountNOLOG ()
            -- Returns count of all media items in track

            return reaper.CountTrackMediaItems(self._peerObject)
        end

        -- ------------------

        function Track:_nameNOLOG ()
            -- Returns name of track

            return self:_getSetData("P_NAME", false)
        end

        -- ------------------
        -- EXPORTED ROUTINES
        -- --------------------

        -- ············
        -- construction
        -- ············

        function Track.make (cls, project, index)
            -- Constructs a new track in <project> at <index>

            local fName = "Reaper.Track.make"
            Logging.traceF(fName, ">>: project = %s, index = %s",
                           project, index)

            index = index - 1
            reaper.InsertTrackAtIndex(index, false)
            local reaperTrack =  reaper.GetTrack(project, index)
            local result = Track:_make(reaperTrack)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- attributes
        -- ··········

        function Track:identification ()
            -- Returns track identification

            return reaper.GetTrackGUID(self._peerObject)
        end

        -- ------------------

        function Track:isSendingToParent ()
            -- Returns information whether track audio is sent to
            -- parent

            local fName = "Reaper.Track.isSendingToParent"
            Logging.traceF(fName, ">>: %s", self)
            local result = (Track:_getSetData("B_MAINSEND") ~= 0)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Track:mediaItemByIndex (index)
            -- Returns media item with <index> in track

            local fName = "Reaper.Track.mediaItemByIndex"
            Logging.traceF(fName, ">>: %s, index = %d", self, index)
            local result =
                Generics.findElementByIndexRaw(self, index,
                                               MediaItem,
                                               reaper.GetTrackMediaItem,
                                               self:mediaItemCount())
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Track:mediaItemCount ()
            -- Returns count of all media items in track

            local fName = "Reaper.Track.mediaItemCount"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:mediaItemCountNOLOG()
            Logging.traceF(fName, "<<: %d", result)
            return result
        end

        -- ------------------

        function Track:mediaItemList ()
            -- Returns list of all media items in track

            local fName = "Reaper.Track.mediaItemList"
            Logging.traceF(fName, ">>: %s", self)
            local result = Generics.makeList(self, MediaItem,
                                             self.mediaItemByIndexNOLOG,
                                             self:mediaItemCount())
            Logging.traceF(fName, "<<: %d", result:count())
            return result
        end

        -- ------------------

        function Track:name ()
            -- Returns name of track

            local fName = "Reaper.Track.name"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_nameNOLOG()
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Track:pan ()
            -- Returns pan of track

            local fName = "Reaper.Track.pan"
            Logging.traceF(fName, ">>: %s", self)
            local result = Track:_getSetData("D_PAN")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function Track:volume ()
            -- Returns volume of track

            local fName = "Reaper.Track.volume"
            Logging.traceF(fName, ">>: %s", self)
            local result = Track:_getSetData("D_VOL")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ················
        -- attribute change
        -- ················

        function Track:setName (name)
            -- Sets name of track to <name>

            local fName = "Reaper.Track.setName"
            Logging.traceF(fName, ">>: track = %s, name = %s",
                           self, name)
            self:_getSetData("P_NAME", true, name)
            Logging.traceF(fName, "<<")
        end

        -- ------------------

        function Track:setSelected (isSelected)
            -- Sets track to selected or unselected depending on
            -- <isSelected>

            local fName = "Reaper.Track.setSelected"
            Logging.traceF(fName, ">>: track = %s, isSelected = %s",
                           self, isSelected)
            local value = iif(isSelected, 1, 0)
            self:_getSetData("I_SELECTED", true, value)
            Logging.traceF(fName, "<<")
        end

        -- ------------------

        function Track:setSendingToParent (isSending)
            -- Set information whether track audio is sent to
            -- parent to <isSending>

            local fName = "Reaper.Track.setSendingToParent"
            Logging.traceF(fName, ">>: track = %s, isSending = %s",
                           self, isSending)
            local value = iif(isSending, 1, 0)
            self:_getSetData("B_MAINSEND", true, value)
            Logging.traceF(fName, "<<")
        end

        -- ------------------

        function Track:setOnlySelected ()
            -- Sets track to be the only selected

            local fName = "Reaper.Track.setOnlySelected"
            Logging.traceF(fName, ">>: track = %s", self)
            reaper.SetOnlyTrackSelected(self._peerObject)
            Logging.traceF(fName, "<<")
        end

        -- ------------------

        function Track:setPan (panPosition)
            -- Sets pan of track to <panPosition>

            local fName = "Reaper.Track.setPan"
            Logging.traceF(fName, ">>: track = %s, pan = %s",
                           self, panPosition)
            self:_getSetData("D_PAN", true, panPosition)
            Logging.traceF(fName, "<<")
        end

        -- ------------------

        function Track:setVolume (volume)
            -- Sets volume of track to <volume>

            local fName = "Reaper.Track.setVolume"
            Logging.traceF(fName, ">>: track = %s, volume = %s",
                           self, volume)
            self:_getSetData("D_VOL", true, volume)
            Logging.traceF(fName, "<<")
        end

        -- ···················
        -- relations to others
        -- ···················

        function Track:connectionList (isOutgoingConnections)
            -- Returns list of incoming (receive) or outgoing (send)
            -- connections

            local fName = "Reaper.Track.connectionList"
            Logging.traceF(fName, ">>: %s", self)

            local result =
                TrackConnection:listAll(self, isOutgoingConnections)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end
        
        -- ------------------

        function Track:effectCount ()
            -- Returns count of effects in current track

            local fName = "Reaper.Track.effectCount"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:effectCountNOLOG()
            Logging.traceF(fName, "<<: %s", result)
            return result
        end
        
        -- ------------------

        function Track:effectList ()
            -- Returns list of effects of current track

            local fName = "Reaper.Track.effectList"
            Logging.traceF(fName, ">>: %s", self)

            local effectCreationProc =
                function (track, effectIndex)
                    return Effect:make(track, effectIndex)
                end

            local result = Generics.makeList(self, Effect,
                                             effectCreationProc,
                                             self:effectCountNOLOG())

            Logging.traceF(fName, "<<: %s", result)
            return result
        end
        
        -- ------------------

        function Track:makeConnection (otherTrack, isCreated)
            -- Makes or reuses a track send-receive-connection to
            -- <otherTrack> where this track acts as the sender; if
            -- <isCreated> is set, such a connection is created anyhow,
            -- otherwise the first existing is reused (if any);
            -- returns resulting track connection object

            local fName = "Reaper.Track.makeConnection"
            Logging.traceF(fName,
                           ">>: track = %s, otherTrack = %s,"
                           .." isCreated = %s",
                           self, otherTrack, isCreated)

            local result = nil

            if not isCreated then
                result = TrackConnection:lookup(self, otherTrack)
            end

            if result == nil or isCreated then
                result = TrackConnection:make(self, otherTrack)
            end

            if result == nil then
                Logging.trace("--: could not make connection")
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end
        
        -- ··········
        -- conversion
        -- ··········

        function Track:__tostring ()
            -- Returns a simple string representation of track

            local identification = self:identification()
            local name = self:_nameNOLOG()
            return String.format("Track(id = '%s', name = '%s')",
                                 self:identification(), self:_nameNOLOG())
        end

        -- ···········
        -- destruction
        -- ···········

        function Track:delete ()
            -- Deletes track

            local fName = "Reaper.Track.delete"
            Logging.traceF(fName, ">>: %s", self)
            reaper.DeleteTrack(self._peerObject)
            Logging.traceF(fName, "<<")
        end

    -- =========
    -- end Track
    -- =========

    -- =====================
    -- class TrackConnection
    -- =====================
        -- A track connection establishes a send-receive connection
        -- between a source and a destination track

        -- --------------------
        -- PRIVATE FEATURES
        -- --------------------

        function TrackConnection._makeNOLOG (cls,
                                             sourceTrack, destinationTrack)
            -- Makes a send-receive connection object from
            -- <sourceTrack> to <destinationTrack>

            local result

            result = cls:makeInstance()
            result._sourceTrack      = sourceTrack
            result._destinationTrack = destinationTrack

            return result
        end

        -- ------------------

        function TrackConnection:_getParameterNOLOG (parameterName)
            -- Returns parameter given by <parameterName> for track
            -- connection without logging

            local result = nil

            if parameterName == "P_DESTTRACK" then
                result = self._destinationTrack
            elseif parameterName == "P_SRCTRACK" then
                result = self._sourceTrack
            else
                local reaperTrack = self._sourceTrack._peerObject
                local sendIndex =
                    TrackConnection:_sendIndex(self._sourceTrack,
                                               self._destinationTrack)
                if sendIndex >= 0 then
                    result = reaper.GetTrackSendInfo_Value(reaperTrack,
                                                           0, sendIndex,
                                                           parameterName)
                    
                    if String.hasPrefix(parameterName, "B_") then
                        result = (result ~= 0)
                    end
                end
            end

            return result
        end

        -- ------------------

        function TrackConnection:_getParameter (parameterName)
            -- Returns parameter given by <parameterName> for track
            -- connection

            local fName = "Reaper.TrackConnection._getParameter"
            Logging.traceF(fName, ">>: %s, parameterName = %s",
                           self, parameterName)
            local result = self:_getParameterNOLOG(parameterName)
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function TrackConnection:_sendIndex (sourceTrack,
                                             destinationTrack)
            -- Returns send index for track connection from
            -- <sourceTrack> to targetTrack> without logging

            local result = -1
            local reaperSourceTrack      = sourceTrack._peerObject
            local reaperDestinationTrack = destinationTrack._peerObject
            local sendCount =
                      reaper.GetTrackNumSends(reaperSourceTrack, 0)

            for sendIndex = 0, sendCount - 1 do
                otherTrack = reaper.GetTrackSendInfo_Value(reaperSourceTrack,
                                                           0, sendIndex,
                                                           "P_DESTTRACK")

                if otherTrack == reaperDestinationTrack then
                    result = sendIndex
                    break
                end
            end

            return result
        end
        
        -- ------------------

        function TrackConnection:_setParameter (parameterName, value)
            -- Sets parameter given by <parameterName> for track
            -- connection to <value> and returns whether action was
            -- successful

            local fName = "Reaper.TrackConnection._setParameter"
            Logging.traceF(fName, ">>: %s, parameterName = %s, value = %s",
                           self, parameterName, value)

            local result = nil
            local reaperTrack = self._sourceTrack._peerObject
            local sendIndex =
                TrackConnection:_sendIndex(self._sourceTrack,
                                           self._destinationTrack)

            if sendIndex >= 0 then
                if String.hasPrefix(parameterName, "B_") then
                    result = iif(result, 1, 0)
                end

                result = reaper.SetTrackSendInfo_Value(reaperTrack,
                                                       0, sendIndex,
                                                       parameterName,
                                                       value)
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------
        -- EXPORTED ROUTINES
        -- ------------------

        function TrackConnection.make (cls,
                                       sourceTrack, destinationTrack)
            -- Makes a new send-receive connection from <sourceTrack> to
            -- <destinationTrack>

            local fName = "Reaper.TrackConnection.make"
            Logging.traceF(fName, ">>: source = %s, destination = %s",
                           sourceTrack, destinationTrack)
            local reaperSourceTrack      = sourceTrack._peerObject
            local reaperDestinationTrack = destinationTrack._peerObject
            local _ = reaper.CreateTrackSend(reaperSourceTrack,
                                             reaperDestinationTrack)
            local result = TrackConnection:_makeNOLOG(sourceTrack,
                                                      destinationTrack)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function TrackConnection.listAll (cls,
                                          track, isOutgoingConnections)
            -- Returns list of incoming (receive) or outgoing (send)
            -- connections for <track> depending on
            -- <isOutgoingConnections>

            local fName = "Reaper.TrackConnection.listAll"
            Logging.traceF(fName,
                           ">>: track = %s, isOutgoingConnections = %s",
                           track, isOutgoingConnections)

            local result = List:make()
            
            local reaperTrack = track._peerObject
            local reaperSendCategory = iif(isOutgoingConnections, 0, -1)
            local parameterName = iif(isOutgoingConnections,
                                      "P_DESTTRACK", "P_SRCTRACK")
            local sendCount = reaper.GetTrackNumSends(reaperTrack,
                                                      reaperSendCategory)
            local connection

            for sendIndex = 0, sendCount - 1 do
                local reaperOtherTrack =
                          reaper.GetTrackSendInfo_Value(reaperTrack,
                                                        reaperSendCategory,
                                                        sendIndex,
                                                        parameterName)
                local otherTrack = Track:makeInstance(reaperOtherTrack)

                if isOutgoingConnections then
                    connection = cls:_makeNOLOG(track, otherTrack)
                else
                    connection = cls:_makeNOLOG(otherTrack, track)
                end

                result:append(connection)
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function TrackConnection.lookup (cls,
                                         sourceTrack, destinationTrack)
            -- Checks whether some send-receive connection from
            -- <sourceTrack> to <destinationTrack> already exists and
            -- returns it or nil (if not)

            local fName = "Reaper.TrackConnection.lookup"
            Logging.traceF(fName, ">>: source = %s, destination = %s",
                           sourceTrack, destinationTrack)

            local result = nil
            local sendIndex =
                      cls:_sendIndex(sourceTrack, destinationTrack)

            if sendIndex >= 0 then
                result = cls:_makeNOLOG(sourceTrack, destinationTrack)
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ··········
        -- attributes
        -- ··········

        function TrackConnection:destinationTrack ()
            -- Returns the destination track of track connection

            local fName = "Reaper.TrackConnection.destinationTrack"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("P_DESTTRACK")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function TrackConnection:isInverted ()
            -- Returns whether track connection has inverted phase

            local fName = "Reaper.TrackConnection.isInverted"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("B_PHASE")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function TrackConnection:isMono ()
            -- Returns whether track connection is in mono

            local fName = "Reaper.TrackConnection.isMono"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("B_MONO")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function TrackConnection:isMuted ()
            -- Returns whether track connection is muted

            local fName = "Reaper.TrackConnection.isMuted"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("B_MUTE")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function TrackConnection:midiFlags ()
            -- Returns the MIDI flags of track connection

            local fName = "Reaper.TrackConnection.midiFlags"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("I_MIDIFLAGS")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function TrackConnection:pan ()
            -- Returns the pan position of track connection

            local fName = "Reaper.TrackConnection.pan"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("D_PAN")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function TrackConnection:sendMode ()
            -- Returns the send mode of track connection

            local fName = "Reaper.TrackConnection.sendMode"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("I_SENDMODE")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function TrackConnection:sourceTrack ()
            -- Returns the source track of track connection

            local fName = "Reaper.TrackConnection.sourceTrack"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("P_SRCTRACK")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end
            
        -- ------------------

        function TrackConnection:volume ()
            -- Returns the volume of track connection

            local fName = "Reaper.TrackConnection.volume"
            Logging.traceF(fName, ">>: %s", self)
            local result = self:_getParameter("D_VOL")
            Logging.traceF(fName, "<<: %s", result)
            return result
        end
            
        -- ················
        -- attribute change
        -- ················

        function TrackConnection:setInverted (isInverted)
            -- Sets whether track connection has inverted phase to
            -- <isInverted>

            local fName = "Reaper.TrackConnection.setInverted"
            Logging.traceF(fName, ">>: %s, isInverted = %s",
                           self, isInverted)
            local value = iif(isInverted, 1, 0)
            local result = self:_setParameter("B_PHASE", value)
            Logging.traceF(fName, "<<")
            return result
        end

        -- ------------------

        function TrackConnection:setMidiFlags (value)
            -- Sets the MIDI flags of track connection to <value>

            local fName = "Reaper.TrackConnection.setMidiFlags"
            Logging.traceF(fName, ">>: %s, value = %s", self, value)
            local result = self:_setParameter("I_MIDIFLAGS", value)
            Logging.traceF(fName, "<<")
            return result
        end

        -- ------------------

        function TrackConnection:setMono (isMono)
            -- Sets whether track connection is in mono to <isMono>

            local fName = "Reaper.TrackConnection.setMono"
            Logging.traceF(fName, ">>: %s, value = %s", self, isMono)
            local value = iif(isMono, 1, 0)
            local result = self:_setParameter("B_MONO", value)
            Logging.traceF(fName, "<<")
            return result
        end

        -- ------------------

        function TrackConnection:setMuted (isMuted)
            -- Sets whether track connection is muted to <isMuted>

            local fName = "Reaper.TrackConnection.setMuted"
            Logging.traceF(fName, ">>: %s, value = %s", self, isMuted)
            local value = iif(isMuted, 1, 0)
            local result = self:_setParameter("B_MUTE", value)
            Logging.traceF(fName, "<<")
            return result
        end

        -- ------------------

        function TrackConnection:setPan (panPosition)
            -- Sets the pan position of track connection to
            -- <panPosition>

            local fName = "Reaper.TrackConnection.setPan"
            Logging.traceF(fName, ">>: %s, value = %s",
                           self, panPosition)
            local result = self:_setParameter("D_PAN", panPosition)
            Logging.traceF(fName, "<<")
            return result
        end

        -- ------------------

        function TrackConnection:setSendMode (sendMode)
            -- Sets the send mode of track connection to <sendMode>

            local fName = "Reaper.TrackConnection.setSendMode"
            Logging.traceF(fName, ">>: %s, value = %s", self, sendMode)
            local result = self:_setParameter("I_SENDMODE", sendMode)
            Logging.traceF(fName, "<<")
            return result
        end

        -- ------------------

        function TrackConnection:setVolume (volume)
            -- Sets the volume of track connection to <volume>

            local fName = "Reaper.TrackConnection.setVolume"
            Logging.traceF(fName, ">>: %s, value = %s", self, volume)
            local result = self:_setParameter("D_VOL", volume)
            Logging.traceF(fName, "<<")
            return result
        end
            
        -- ··········
        -- conversion
        -- ··········

        function TrackConnection:__tostring ()
            -- Returns a simple string representation of a track
            -- connection

            local sendMode = self:_getParameterNOLOG("I_SENDMODE")
            local sendModeAsString =
                      TrackSendModeKind.__tostring(sendMode)

            local template = ("TrackConnection("
                              .. "sourceTrack = %s,"
                              .. " destinationTrack = %s,"
                              .. " isMuted = %s,"
                              .. " isInverted = %s,"
                              .. " isMono = %s,"
                              .. " volume = %s,"
                              .. " pan = %s,"
                              .. " sendMode = %s,"
                              .. " midiFlags = %x"
                              .. ")")

            return String.format(template,
                                 self._sourceTrack,
                                 self._destinationTrack,
                                 self:_getParameterNOLOG("B_MUTE"),
                                 self:_getParameterNOLOG("B_PHASE"),
                                 self:_getParameterNOLOG("B_MONO"),
                                 self:_getParameterNOLOG("D_VOL"),
                                 self:_getParameterNOLOG("D_PAN"),
                                 sendModeAsString,
                                 self:_getParameterNOLOG("I_MIDIFLAGS"))
        end

    -- ===================
    -- end TrackConnection
    -- ===================

    -- ========
    -- class UI
    -- ========

        local function UI_showMessageBox (message, title, messageBoxKind)
            -- Shows message box with <message>, <title> and
            -- <messageBoxKind>

            Logging.trace(">>: message = %s, title = %s, kind = %d",
                          message, title, messageBoxKind)
            local result = reaper.MB(message, title, messageBoxKind)
            Logging.trace("<<: %d", result)
            return result
        end

        -- ------------------

        local function UI_updateTimeline ()
            -- Updates timeline UI presentation with regions and
            -- markers
            
            Logging.trace(">>")
            reaper.UpdateTimeline()
            Logging.trace("<<")
        end

    -- ======
    -- end UI
    -- ======

    -- ==========================
    -- class UI_MixerControlPanel
    -- ==========================

        -- Represents a MixerControlPanel associated with a track; it
        -- can be found by the track index and then layout name and color
        -- can be set

        -- --------------------
        -- PRIVATE FEATURES
        -- --------------------

        function UI_MixerControlPanel._make (cls, peerObject)
            -- Constructs a wrapper mixer control panel from
            -- <peerObject>

            local fName = "Reaper.UI.MixerControlPanel._make"
            Logging.traceF(fName, ">>: %s", peerObject)

            local result = cls:makeInstance(peerObject)

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------
        -- EXPORTED ROUTINES
        -- --------------------

        function UI_MixerControlPanel.findByTrack (track)
            -- Returns mixer control panel for given <track>

            local fName = "Reaper.UI.MixerControlPanel.findByTrack"
            Logging.traceF(fName, ">>: track = %s", track)

            local result
            
            if track == nil then
                result = nil
            else
                -- make the underlying Reaper track the peer object of
                -- mixer control panel
                result = UI_MixerControlPanel:_make(track._peerObject)
            end

            Logging.traceF(fName, "<<: %s", result)
            return result
        end

        -- ------------------

        function UI_MixerControlPanel:setLayout (layoutName)
            -- Sets the layout of the mixer control panel to
            -- <layoutName>; does not check whether this name is
            -- valid

            local fName = "Reaper.UI.MixerControlPanel.setLayout"
            Logging.traceF(fName, ">>: layoutName = %s", layoutName)

            local reaperTrack = self._peerObject
            reaper.GetSetMediaTrackInfo_String(reaperTrack,
                                               "P_MCP_LAYOUT",
                                               layoutName,
                                               true)
            
            Logging.traceF(fName, "<<")
        end

        -- ------------------

        function UI_MixerControlPanel:setColor (color)
            -- Sets the color of the mixer control panel to
            -- <color>; does not check whether this color is valid

            local fName = "Reaper.UI.MixerControlPanel.setColor"
            Logging.traceF(fName, ">>: color = %d", color)

            local reaperTrack = self._peerObject
            reaper.SetTrackColor(reaperTrack, color)

            Logging.traceF(fName, "<<")
        end

        -- ··········
        -- conversion
        -- ··········

        function UI_MixerControlPanel:__tostring ()
            -- Returns a simple string representation of media source

            local reaperTrack = self._peerObject
            local parameterName = "P_NAME"
            local _, trackName =
                 reaper.GetSetMediaTrackInfo_String(reaperTrack,
                                                    parameterName,
                                                    "",
                                                    false)
            return String.format("UI_MixerControlPanel('%s')", trackName)
        end

    -- ========================
    -- end UI_MixerControlPanel
    -- ========================

    -- ========================
    -- MODULE EXPORT DEFINITION
    -- ========================

    Reaper = {
        ConfigData  = { get = ConfigData.get },
        MediaItem   = { make = MediaItem.make },
        MediaSource = { make = MediaSource.make },
        MidiEventKind = MidiEventKind,
        MidiEventList = MidiEventList,
        Project     = { current = Project.current },
        Region = {
            make   = Region.make,
            delete = Region.delete
        },
        Take = { make = Take.make },
        TimeBaseKind = TimeBaseKind,
        Track = { make = Track.make },
        TrackSendModeKind = TrackSendModeKind,
        UI = {
            MessageBoxKind = MessageBoxKind,
            MessageBoxAnswerKind = MessageBoxAnswerKind,
            showMessageBox = UI_showMessageBox,
            updateTimeline = UI_updateTimeline,
            MixerControlPanel = {
                findByTrack = UI_MixerControlPanel.findByTrack
            }
        }
    }

-- ==========
-- end Reaper
-- ==========
