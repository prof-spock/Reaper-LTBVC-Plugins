-- ConfigurationFile - provides reading from a configuration file containing
--                     comments and assignment to variables
-- 
-- author: Dr. Thomas Tensi, 2022-06

-- ====================
-- IMPORTS
-- ====================

require("Base")
require("Class")
require("Map")
require("OperatingSystem")
require("Set")
require("String")

-- ====================

-- --------------------
-- CLASS DECLARATIONS
-- --------------------

ConfigurationFile = Class:make("ConfigurationFile")
local _Token      = Class:make("_Token")
local _TokenList  = Class:makeVariant("_TokenList", List)

-- ====================

function _reprOfStringToValueMap (stringMap)
    -- Returns string representation for a string to value map
    -- <stringMap>

    local entrySeparator = "#"
    local entryTemplate = "%s: %s"
    local keyList = stringMap:keySet()
    local result = ""
    
    for _, key in keyList:iterator() do
        local value = stringMap:at(key)
        result = (result ..
                  iif(result == "", "", entrySeparator)
                  .. String.format(entryTemplate, key, value))
    end
    
    result = "{" .. result .. "}";
    return result
end

-- =============
-- module _Token
-- =============
    -- This module provides services for a simple token within table
    -- definition string parser

    _Token.Kind_number        = "number"
    _Token.Kind_string        = "string"
    _Token.Kind_operator      = "operator"
    _Token.Kind_realNumber    = "real"
    _Token.Kind_integerNumber = "integer"

    -- --------------------
    -- EXPORTED FEATURES
    -- --------------------

    -- ············
    -- construction
    -- ············

    function _Token.make (cls, start, text, kind, value)
        -- Initializes token with start position, token text, token
        -- kind and value

        local result = cls:makeInstance()
        result.start = start
        result.text  = text
        result.kind  = kind
        result.value = value
        return result
    end
        
    -- ·····················
    -- string representation
    -- ·····················

    function _Token:__tostring ()
        -- Returns string representation of token

        local st = ("_Token("
                    .. "start = " .. self.start
                    .. ", text = '" .. self.text
                    .. "', kind = " .. self.kind
                    .. "', value = " .. self.value
                    .. ")")
        return st
    end

-- ==========
-- end _Token
-- ==========


-- ========================
-- module ConfigurationFile
-- ========================

    -- This nodule provides services for reading a configuration file
    -- with key - value assignments.  The parsing process calculates a
    -- map from name to value where the values may be booleans,
    -- integers, reals or strings."""

    -- --------------------
    -- LOCAL FEATURES
    -- --------------------

    function ConfigurationFile._adaptConfigurationValue (cls, value)
        -- Takes string <value> and constructs either a boolean, a
        -- numeric value or a sanitized string.

        local fName = "ConfigurationFile._adaptConfigurationValue"
        Logging.traceF(fName, ">>: %s", value)

        local uppercasedValue = String.toUppercase(value)
        local result

        if cls._validBooleanValueNameSet:contains(uppercasedValue) then
            result = cls._trueBooleanValueNameSet:contains(uppercasedValue)
        elseif (value:find(cls._integerRegExp)
                or value:find(cls._hexIntegerRegExp)) then
            result = tonumber(value)
        elseif value:find(cls._realRegExp) then
            result = tonumber(value)
        else
            result = value
        end
            
        Logging.traceF(fName, "<<: %s", result)
        return result
    end
        
    -- --------------------

    function ConfigurationFile._combineFragmentedString (cls, st)
        -- Combines - possibly fragmented - external representation of
        -- a string given by <st> into a sanitized string.

        local fName = "ConfigurationFile._combineFragmentedString"
        Logging.traceF(fName, ">>: %s", st)

        local ParseState_inLimbo   = 0
        local ParseState_inOther   = 1
        local ParseState_inString  = 2
        local ParseState_inLiteral = 3
        local ParseState_inEscape  = 4

        local parseState = ParseState_inLimbo
        local result = ""

        for i = 1, String.length(st) do
            -- process finite state automaton with five states based
            -- on next character in string
            -- Logging.trace("--: (%d) character: %r", parseState, ch)

            local ch = st:sub(i, i)
        
            if parseState == ParseState_inLimbo then
                if ch == cls._doubleQuoteCharacter then
                    parseState = ParseState_inString
                elseif not ch:find(cls._whiteSpaceCharRegExp) then
                    parseState = ParseState_inLiteral
                    result = result .. ch
                end
            elseif parseState == ParseState_inString then
                if ch == cls._doubleQuoteCharacter then
                    parseState = ParseState_inLimbo
                else
                    result = result .. ch
                    parseState = iif(ch == cls._escapeCharacter,
                                     ParseState_inEscape, parseState)
                end
            elseif parseState == ParseState_inLiteral then
                result = result .. ch

                if ch:find(cls._whiteSpaceCharRegExp) then
                    parseState = ParseState_inLimbo
                end
            elseif parseState == ParseState_inEscape then
                result = result .. ch
                parseState = ParseState_inString
            else
                Assertion.check(false,
                                String.format("bad parse state - %s",
                                              parseState))
            end
        end

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function ConfigurationFile:_expandVariables (st)
        -- Expands all variables embedded in <st>

        local fName = "ConfigurationFile._expandVariables"
        Logging.traceF(fName, ">>: %s", st)

        local cls = ConfigurationFile

        -- collect identifiers embedded in value and replace them by
        -- their value
        local ParseState_inLimbo      = 0
        local ParseState_inString     = 1
        local ParseState_inEscape     = 2
        local ParseState_inIdentifier = 3
        local parseStateToString =
            Map:makeFromPairArray({ 0, "-", 1, "S",
                                    2, cls._escapeCharacter, 3, "I" })

        local parseState = ParseState_inLimbo
        local result = ""
        local identifier = ""
        local fsaTrace = ""

        for i = 1, String.length(st) do
            -- process finite state automaton with three states based
            -- on next character in string

            local ch = st:sub(i, i)
            fsaTrace = (fsaTrace
                        .. iif(fsaTrace == "", "", " ")
                        .. String.format("[%s] %s",
                                         parseStateToString[parseState], ch))

            if parseState == ParseState_inLimbo then
                if ch:find(cls._identifierCharRegExp) then
                    identifier = ch
                    parseState = ParseState_inIdentifier
                else
                    result = result .. ch

                    if ch == cls._doubleQuoteCharacter then
                        parseState = ParseState_inString
                    end
                end
            elseif parseState == ParseState_inString then
                result = result .. ch

                if ch == cls._doubleQuoteCharacter then
                    parseState = ParseState_inLimbo
                elseif ch == cls._escapeCharacter then
                    parseState = ParseState_inEscape
                end
            elseif parseState == ParseState_inEscape then
                result = result .. ch
                parseState = ParseState_inString
            elseif parseState == ParseState_inIdentifier then
                if ch:find(cls._identifierCharRegExp) then
                    identifier = identifier .. ch
                else
                    identifierValue = self:_findIdentifierValue(identifier)
                    result = result .. identifierValue .. ch
                    parseState = iif(ch == cls._doubleQuoteCharacter,
                                     ParseState_inString, ParseState_inLimbo)
                end
            end
        end
            
        if parseState == ParseState_inIdentifier then
            identifierValue = self:_findIdentifierValue(identifier)
            result = result .. identifierValue
        end
            
        Logging.traceF(fName, "--: accumulatedFSATrace = %s", fsaTrace)
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function ConfigurationFile:_findIdentifierValue (identifier)
        -- Returns string representation of associated identifier
        -- value for <identifier>; if not found in current key to
        -- value map, the identifier itself is returned"""

        local fName = "ConfigurationFile._findIdentifierValue"
        Logging.traceF(fName, ">>: %s", identifier)

        local cls = ConfigurationFile

        if not self._keyToValueMap:hasKey(identifier) then
            -- leave identifier as is (it might be some value name
            -- like wahr or false
            Logging.traceErrorF(fName, "no expansion found")
            result = identifier
        else
            result = self._keyToValueMap:at(identifier)

            if not String.isString(result) then
                result = tostring(result)
            else
                result = (cls._doubleQuoteCharacter
                          .. result
                          .. cls._doubleQuoteCharacter)
            end
        end

        Logging.traceF(fName, "<<: expanded %s into %s",
                       identifier, result)
        return result
    end

    -- --------------------

    function ConfigurationFile:_lookupFileName (enclosingDirectoryName,
                                                originalFileName)
        -- Returns file name in search paths based on
        -- <originalFileName>

        local fName = "ConfigurationFile._lookupFileName"
        Logging.traceF(fName, ">>: directory = %s, file = %s",
                       enclosingDirectoryName, originalFileName)

        local cls = ConfigurationFile
        local result = nil
        local separator = OperatingSystem.pathSeparator
        local simpleFileName = OperatingSystem.baseName(originalFileName)
        local searchPathList = cls._searchPathList:clone()
        searchPathList:append(enclosingDirectoryName)

        for _, directoryName in searchPathList:iterator() do
            local fileName =
                iif(directoryName == ".",
                    originalFileName,
                    directoryName .. separator .. simpleFileName)
            local isFound = OperatingSystem.hasFile(fileName)
            Logging.traceF(fName, "--: %s -> found = %s",
                           fileName, isFound)

            if isFound then
                result = fileName
                break
            end
        end

        Logging.traceF(fName, "<<: %s", result)
        return result
    end
    
    -- --------------------

    function ConfigurationFile:_mergeContinuationLines (lineList)
        -- Merges continuation lines in <lineList> into single
        -- cumulated line and replaces continuations by empty lines
        -- (to preserve line numbers); the continuation logic is
        -- simple: a new identifier definition line (starting with an
        -- identifier and an equals sign) starts a new logical line
        -- unconditionally, otherwise physical lines are collected and
        -- combined with the previous logical line; embedded comment
        -- lines are skipped and an empty (whitespace only) physical
        -- line stops the collection process (unless followed by a
        -- continuation character)

        local cls = ConfigurationFile
        local fName = "ConfigurationFile._mergeContinuationLines"
        Logging.traceF(fName, ">>")

        local cumulatedLine = ""
        local markerLength = String.length(cls._continuationMarker)

        for i = 1, lineList:count() do
            local originalLine = lineList:at(i)
            local currentLine = String.trim(originalLine)
            Logging.traceF(fName, "--: '%s'", currentLine)
            lineList:set(i, "")

            if String.hasPrefix(currentLine, cls._continuationMarker) then
                -- strip off obsolete continuation marker
                local remainingLength = String.length(st) - markerLength
                currentLine = String.rTrim(String.slice(1, remainingLength))
            end

            if currentLine:find(cls._identifierLineRegExp) then
                -- this is a new definition

                if cumulatedLine > "" then
                    lineList:set(i - 1, cumulatedLine)
                end

                cumulatedLine = currentLine
                loggingFormat = "--: new definition %d (%s)"
            elseif String.hasPrefix(currentLine, cls._commentMarker) then
                -- skip comment
                loggingFormat = "--: skipped comment %d (%s)"
            elseif originalLine == "" then
                if cumulatedLine == "" then
                    loggingFormat = "--: empty line %d (%s)"
                else
                    lineList:set(i - 1, cumulatedLine)
                    loggingFormat =
                        "--: empty line ended previous definition %d (%s)"
                end

                cumulatedLine = ""
            else
                -- this is not an empty line and it does not start with a
                -- definition sequence or an import
                cumulatedLine = cumulatedLine .. " " .. currentLine
                loggingFormat = "--: collected continuation %d (%s)"
            end

            Logging.traceF(fName, loggingFormat, i, currentLine)
        end

        if cumulatedLine > "" then
            lineList:set(lineList:count(), cumulatedLine)
            Logging.traceF(fName, "--: final line (%s)", currentLine)
        end

        Logging.traceF(fName, "<<")
    end

    -- --------------------

    function ConfigurationFile:_mustHave (token, kindSet, valueSet)
        -- Ensures that <token> is of a kind in <kindSet>; if
        -- <valueSet> is not None, token value is also checked

        local fName = "ConfigurationFile._mustHave"
        Logging.traceF(fName,
                       ">>: token = %s, kindSet = %s, valueSet = %s",
                       token, kindSet, valueSet)

        local errorPosition, errorMessage = -1, ""

        if not kindSet:contains(token.kind) then
            errorPosition = token.start
            errorMessage  =
                String.format("expected kind from %s, found %s",
                              kindSet, token.kind)
        elseif (valueSet ~= nil
                and not valueSet:contains(token.value)) then
            errorPosition = token.start
            errorMessage  =
                String.format("expected value from %s, found %s",
                              valueSet, token.value)
        end

        local result = { errorPosition, errorMessage }
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------
    
    function ConfigurationFile:_parseConfiguration (lineList)
        -- Parses configuration file data given by <lineList> and
        -- updates key to value and key to string value map."""

        local fName = "ConfigurationFile._parseConfiguration"
        Logging.traceF(fName, ">>: %s", lineList:count())

        local cls = ConfigurationFile
        cls:_mergeContinuationLines(lineList)

        for lineNumber = 1, lineList:count() do
            -- remove leading and trailing white space from line
            local currentLine = String.trim(lineList:at(lineNumber))
            Logging.traceF(fName, "--: (%d) '%s'", lineNumber, currentLine)

            if (String.hasPrefix(currentLine, cls._commentMarker)
                or currentLine == "") then
                -- this is an empty line or comment line => skip it
            else
                local position, _, key, value =
                    currentLine:find(cls._keyValueRegExp)

                if position == nil then
                    Logging.traceErrorF(fName,
                                        "bad line %d without"
                                        .. " key-value-pair",
                                        lineNumber)
                else
                    Logging.traceF(fName, "--: %s -> %s", key, value)
                    value = self:_expandVariables(value)
                    value = cls:_combineFragmentedString(value)
                    self._keyToStringValueMap:set(key, value)
                    Logging.traceF(fName, "--: string value %s -> %s",
                                   key, value)
                    value = cls:_adaptConfigurationValue(value)
                    self._keyToValueMap:set(key, value)
                    Logging.traceF(fName, "--: adapted value %s -> %s",
                                   key, value)
                end
            end
        end

        Logging.traceF(fName, "<<: %s", self._keyToValueMap)
    end

    -- --------------------

    function ConfigurationFile:_readFile (directoryName, fileName,
                                          lineList, visitedFileNameSet)
        -- Appends lines of configuration file with <fileName> to
        -- <lineList> with leading and trailing whitespace stripped;
        -- also handles embedded imports of files (relative to
        -- <directoryName>; <visitedFileNameSet> tells which files
        -- have already been visited

        local fName = "ConfigurationFile._readFile"
        Logging.traceF(fName,
                       ">>: fileName = %s, directory = %s,"
                       .. " visitedFiles = %s",
                       fileName, directoryName, visitedFileNameSet)

        local cls = ConfigurationFile
        local errorMessage = ""
        local isOkay = true
        local originalFileName = fileName
        local fileName = self:_lookupFileName(directoryName,
                                              originalFileName)

        if fileName == nil then
            isOkay = false
            errorMessage = String.format("cannot find %s",
                                         originalFileName)
        elseif visitedFileNameSet:contains(fileName) then
            Logging.traceF(fName, "--: file already included %s",
                           originalFileName)
        else
            visitedFileNameSet:include(fileName)
            local directoryName = OperatingSystem.dirName(fileName)
            local configFileLineList = List:make()

            for currentLine in io.lines(fileName) do
                configFileLineList:append(currentLine)
            end

            for _, currentLine in configFileLineList:iterator() do
                currentLine = String.trim(currentLine)
                local isImportLine =
                    String.hasPrefix(currentLine,
                                     cls._importCommandName)

                if isImportLine then
                    local _, importedFileName =
                        String.splitAt(currentLine, '"')
                    currentLine = cls._commentMarker .. " " .. currentLine
                end

                lineList:append(currentLine)

                if isImportLine then
                    local isAbsolutePath =
                        (String.hasPrefix(importedFileName, "/")
                         or String.hasPrefix(importedFileName, "\\")
                         or importedFileName[2] == ":")

                    -- if isAbsolutePath:
                    --     directoryPrefix = ""
                    -- else:
                    --     directoryName = OperatingSystem.dirname(fileName)
                    --     directoryPrefix = iif(directoryName == ".", "",
                    --                           directoryName
                    --                           + iif(directoryName > "",
                    --                                 "/", ""))

                    -- importedFileName = directoryPrefix + importedFileName
                    Logging.traceF(fName, "--: IMPORT %s", importedFileName)

                    isOkay = self:_readFile(directoryName,
                                            importedFileName, lineList,
                                            visitedFileNameSet)
                    if not isOkay then
                        Logging.traceErrorF(fName,
                                            "import failed for %s in %s",
                                            importedFileName,
                                            cls._searchPathList)
                        isOkay = false
                        break
                    end
                end
            end
        end

        Logging.traceF(fName, "<<: %s, %s", isOkay, errorMessage)
        return isOkay, errorMessage
    end
            
    -- --------------------
    -- EXPORTED FEATURES
    -- --------------------

    function ConfigurationFile.initialize (cls)
        -- Initializes class wide variables

        local fName = "ConfigurationFile.initialize"
        Logging.traceF(fName, ">>")

        cls._importCommandName = "INCLUDE"
        cls._trueBooleanValueNameSet = Set:makeFromArray({"TRUE", "WAHR"})
        cls._validBooleanValueNameSet = Set:makeFromArray({"FALSE", "FALSCH"})
        cls._validBooleanValueNameSet:includeAll(cls._trueBooleanValueNameSet)
        cls._commentMarker = "--"
        cls._continuationMarker = "\\"
        cls._realRegExp = "^[%+%-]?%d+%.%d*$"
        cls._integerRegExp = "^[%+%-]?%d+$"
        cls._hexIntegerRegExp = "^0[xX]%x+$"
        cls._keyValueRegExp = "(%S+)%s*=%s*(.*)"
        cls._whiteSpaceCharRegExp = "%s"
        cls._identifierCharRegExp = "[A-Za-z0-9_]"
        cls._identifierLineRegExp = ("^%s*"
                                     .. "[A-Za-z_][A-Za-z0-9_]*"
                                     .. "%s*=")
        cls._escapeCharacter = "\\"
        cls._doubleQuoteCharacter = '"'
        cls._searchPathList = List:makeFromArray({"."})

        -- error messages
        cls._errorMsg_badOpeningCharacter = "expected either { or ["

        Logging.traceF(fName, "<<")
    end

    -- --------------------

    function ConfigurationFile.setSearchPaths (cls, searchPathList)
        -- Sets list of search paths to <searchPathList>.

        Logging.trace(">>: %s", searchPathList)

        Logging.trace("--")
        cls._searchPathList = searchPathList:clone()
        cls._searchPathList:prepend(".")

        Logging.trace("<<")
    end

    -- --------------------

    function ConfigurationFile.make (cls, fileName)
        -- Parses configuration file given by <fileName> and sets
        -- internal key to value map.

        local fName = "ConfigurationFile.make"
        Logging.traceF(fName, ">>: %s", fileName)
        local result = cls:makeInstance()

        result._keyToValueMap       = Map:make()
        result._keyToStringValueMap = Map:make()
        local visitedFileNameSet = Set:make()
        local lineList = List:make()
        local isOkay = result:_readFile("", fileName,
                                        lineList, visitedFileNameSet)
        result:_parseConfiguration(lineList)

        Logging.traceF(fName, "<<: %s",
                      _reprOfStringToValueMap(result._keyToValueMap))
        return result
    end

    -- --------------------

    function ConfigurationFile:asStringMap ()
        -- Returns mapping from all keys in configuration file to
        -- their effective values

        local fName = "ConfigurationFile.asStringMap"
        Logging.traceF(fName, ">>")
        local result = Map:clone(self._keyToValueMap)
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function ConfigurationFile:asDictionary ()
       -- Returns mapping from all keys in configuration file to their
       -- string values as found in the file

        local fName = "ConfigurationFile.asDictionary"
        Logging.traceF(fName, ">>")
        local result = Map:clone(self._keyToStringValueMap)
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function ConfigurationFile:keySet ()
        -- Returns set of all keys in configuration file"""

        local fName = "ConfigurationFile.keySet"
        Logging.traceF(fName, ">>")
        local result = self._keyToValueMap:keySet()
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function ConfigurationFile:value (key, defaultValue)
        -- Returns value for <key> in configuration file; if
        -- <defaultValue> is missing, an error message is logged when
        -- there is no associated value, otherwise <defaultValue> is
        -- returned for a missing entry"""

        local fName = "ConfigurationFile.value"
        defaultValue = iif(defaultValue == nil, missingValue, defaultValue)
        Logging.traceF(fName, ">>: key = %s, defaultValue = %s",
                       key, defaultValue)

        local isMandatory = (defaultValue == missingValue)
        local result = nil

        if self._keyToValueMap:hasKey(key) then
            result = self._keyToValueMap:at(key)

            if String.isString(result) then
                result = result:gsub("\\\"", "\"")
            end
        elseif isMandatory then
            Logging.traceErrorF(fName, "cannot find value for %s", key)
        else
            result = defaultValue
        end

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

-- =====================
-- end ConfigurationFile
-- =====================
