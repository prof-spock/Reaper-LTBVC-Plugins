-- String - provides some utility functions for strings
-- 
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

require("string")  -- the Lua internal string module
require("List")
require("Map")

Logging = {}  -- circular dependency

-- ==================

-- --------------------
-- MODULE DECLARATION
-- --------------------

String = {}

-- =============
-- module String
-- =============
    -- This module provides some utility functions for strings.

    String._quoteCharacterSet = Set:makeFromArray({"\"", "'"})
    String._structureLeadinCharacterSet = Set:makeFromArray({"{", "["})

    -- --------------------

    function String._deserializeToList (st, startPosition, separator)
        -- Splits <st> starting from <startPosition> at <separator>
        -- into list of parts; sublists or submaps are correctly
        -- handled and embedded into the list; returns end position
        -- and resulting list

        Logging.trace(">>: separator = '%s', st = '%s#|#%s'",
                      separator,
                      String.slice(st, 1, startPosition - 1),
                      String.slice(st, startPosition))

        -- do a finite state automaton with "{", "[", " ", "\"" and
        -- "'" as state changing inputs

        local ParseState_beforeList    = 1
        local ParseState_beforeElement = 2
        local ParseState_inElement     = 3
        local ParseState_inString      = 4
        local ParseState_afterElement  = 5
        local ParseState_afterList     = 6

        local currentList = List:make()
        local lastPosition = st:len()
        local listStartCharacter = "["
        local listEndCharacter = "]"
        local elementTerminatorSet =
            Set:makeFromArray({" ", listEndCharacter, separator })
        local position = startPosition
        local parseState = ParseState_beforeList
        local fsaTrace = ""
        local endQuote
        local element

        while position <= lastPosition do
            local ch = String.at(st, position)
            fsaTrace = (fsaTrace
                        .. String.format(" [%d] '%s'", parseState, ch))

            if parseState == ParseState_beforeList then
                if ch == listStartCharacter then
                    parseState = ParseState_beforeElement
                elseif ch == " " then
                    -- pass
                else
                    -- unexpected character => ignore
                    -- pass
                end
            elseif parseState == ParseState_beforeElement then
                if ch == listEndCharacter then
                    break
                elseif ch == " " then
                    -- pass
                elseif ch == separator then
                    -- unexpected separator => ignore
                    -- pass
                elseif String._quoteCharacterSet:contains(ch) then
                    endQuote = ch
                    currentElement = ""
                    parseState = ParseState_inString
                elseif String._structureLeadinCharacterSet:contains(ch) then
                    if ch == "{" then
                        position, currentElement =
                            String._deserializeToMap(st, position, separator)
                    else
                        position, currentElement =
                            String._deserializeToList(st, position, separator)
                    end

                    currentList:append(currentElement)
                    parseState = ParseState_afterElement
                else
                    currentElement = ch
                    parseState = ParseState_inElement
                end
            elseif parseState == ParseState_inElement then
                if not elementTerminatorSet:contains(ch) then
                    currentElement = currentElement .. ch
                else
                    if ch ~= "'" then
                        -- this should be a boolean or a number
                        local isFound, value =
                            String._toBooleanOrNumber(currentElement)
                        currentElement = iif(isFound,
                                             value, currentElement)
                    end

                    currentList:append(currentElement)

                    if ch == listEndCharacter then
                        break
                    else
                        parseState = iif(ch == " ", ParseState_afterElement,
                                         ParseState_beforeElement)
                    end
                end
            elseif parseState == ParseState_inString then
                if ch ~= endQuote then
                    currentElement = currentElement .. ch
                else
                    currentList:append(currentElement)
                    parseState = ParseState_afterElement
                end
            elseif parseState == ParseState_afterElement then
                -- ignore everything except a list end character or a
                -- separator
                if ch == listEndCharacter then
                    break
                elseif ch == separator then
                    parseState = ParseState_beforeElement
                end
            end

            position = position + 1
        end

        Logging.trace("--: fsa = %s", fsaTrace)
        Logging.trace("<<: position = %d, result = %s",
                      position, currentList)
        return position, currentList
    end

    -- --------------------

    function String._deserializeToMap (st, startPosition, separator)
        -- Splits <st> starting from <startPosition> at <separator>
        -- into map of key-value-pairs; sublists or submaps as values
        -- are correctly handled and embedded into the map; returns
        -- end position and resulting map

        Logging.trace(">>: separator = '%s', st = '%s#|#%s'",
                      separator,
                      String.slice(st, 1, startPosition - 1),
                      String.slice(st, startPosition))

        -- do a finite state automaton with "{", "[", " ", "\"" and
        -- "'" as state changing inputs

        local ParseState_beforeMap     =  1
        local ParseState_beforeKey     =  2
        local ParseState_inKey         =  3
        local ParseState_inKeyString   =  4
        local ParseState_afterKey      =  5
        local ParseState_beforeValue   =  6
        local ParseState_inValue       =  7
        local ParseState_inValueString =  8
        local ParseState_afterValue    =  9
        local ParseState_afterMap      = 10

        local table = Map:make()

        local mapStartCharacter = "{"
        local mapEndCharacter = "}"
        local elementTerminatorSet =
            Set:makeFromArray({" ", ":", mapEndCharacter, separator})
        local lastPosition = st:len()
        local position = startPosition
        local parseState = ParseState_beforeMap
        local fsaTrace = ""
        local currentKey = ""
        local endQuote
        local currentElement
        local elementIsUnhandled

        while position <= lastPosition do
            local ch = String.at(st, position)
            fsaTrace = (fsaTrace
                        .. String.format(" [%d] '%s'", parseState, ch))

            if parseState == ParseState_beforeKey then
                currentKey = ""
            end

            if parseState == ParseState_beforeMap then
                if ch == mapStartCharacter then
                    parseState = ParseState_beforeKey
                elseif ch == " " then
                    -- pass
                else
                    -- unexpected character => ignore
                    -- pass
                end
            elseif (parseState == ParseState_beforeKey
                or parseState == ParseState_beforeValue) then
                elementIsUnhandled = true

                if ch == mapEndCharacter then
                    break
                elseif ch == " " then
                    -- pass
                elseif ch == separator then
                    -- unexpected separator => ignore
                    -- pass
                elseif String._quoteCharacterSet:contains(ch) then
                    endQuote = ch
                    currentElement = ""
                    parseState = parseState + 2
                elseif String._structureLeadinCharacterSet:contains(ch) then
                    if ch == "{" then
                        position, currentElement =
                            String._deserializeToMap(st, position, separator)
                    else
                        position, currentElement =
                            String._deserializeToList(st, position, separator)
                    end

                    parseState = parseState + 3
                else
                    currentElement = ch
                    parseState = parseState + 1
                end
            elseif (parseState == ParseState_inKey
                    or parseState == ParseState_inValue) then
                if not elementTerminatorSet:contains(ch) then
                    currentElement = currentElement .. ch
                else
                    if ch ~= "'" then
                        -- this should be a boolean or number
                        local isFound, value =
                            String._toBooleanOrNumber(currentElement)
                        currentElement = iif(isFound,
                                             value, currentElement)
                    end

                    parseState = parseState + 2
                    position = position - iif(ch == " ", 0, 1)
                end
            elseif (parseState == ParseState_inKeyString
                    or parseState == ParseState_inValueString) then
                if ch ~= endQuote then
                    currentElement = currentElement .. ch
                else
                    parseState = parseState + 1
                end
            elseif (parseState == ParseState_afterKey
                    or parseState == ParseState_afterValue) then
                if elementIsUnhandled then
                    elementIsUnhandled = false

                    if parseState == ParseState_afterKey then
                        currentKey = currentElement
                    else
                        table:set(currentKey, currentElement)
                    end
                end

                -- ignore everything except a separator or a colon
                if ch == mapEndCharacter then
                    position = position - 1
                    parseState = ParseState_beforeKey
                elseif ch == separator then
                    parseState = ParseState_beforeKey
                elseif ch == ":" then
                    parseState = ParseState_beforeValue
                end
            end

            position = position + 1
        end

        Logging.trace("--: fsa = %s", fsaTrace)
        Logging.trace("<<: position = %d, table = %s", position, table)
        return position, table
    end

    -- --------------------

    function String._toBooleanOrNumber (value)
        -- Tries to convert <value> to boolean or number and returns
        -- it (or nil on failure)

        local isFound
        local result
        local uppercasedValue = value:upper()

        if uppercasedValue == "TRUE" then
            result = true
            isFound = true
        elseif uppercasedValue == "FALSE" then
            result = false
            isFound = true
        else
            result = tonumber(value)
            isFound = (result ~= nil)
        end

        return isFound, result
    end

    -- --------------------
    -- EXPORTED FEATURES
    -- --------------------

    String.newline = "\n"

    -- --------------------

    function String.at (st, i)
        -- Returns <i>-th character of <st>

        return st:sub(i, i)
    end

    -- --------------------

    function String.captureList (st, pattern)
        -- Returns list of submatches ("captures") when matching <st>
        -- against <pattern> once; returns nil when string does not
        -- match

        local result

        if st:find(pattern) then
            result = List:makeFromArray(table.pack(st:find(pattern)))
            result:removeFirst()
            result:removeFirst()
        end

        Logging.trace("--: %s", result)
        return result
    end

    -- --------------------

    function String.deserialize (st)
        -- Returns structured object by deserializing <st>

        Logging.trace(">>: '%s'", st)

        local result
        local originalString = st
        st = String.trim(st)

        if String.hasPrefix(st, "[") then
            _, result = String._deserializeToList(st, 1, ",")
        elseif String.hasPrefix(st, "{") then
            _, result = String._deserializeToMap(st, 1, ",")
        else
            result = originalString
        end

        Logging.trace("<<: %s", result)
        return result
    end

    -- --------------------

    function String.find (st, substring)
        -- Tells the first and last position where <st> contains
        -- <substring>, otherwise returns nil

        return st:find(substring, 1, true)
    end

    -- --------------------

    function String.findPattern (st, pattern)
        -- Tells the first and last position where <st> contains
        -- <pattern>, otherwise returns nil

        return st:find(pattern)
    end

    -- --------------------

    function String.format (template, ...)
        -- Returns string produced by applying <template> to the
        -- additional parameters

        return template:format(...)
    end

    -- --------------------

    function String.globalReplace (st, pattern, replacement)
        -- Replaces all occurences of <pattern> in <st> by
        -- <replacement>

        return st:gsub(pattern, replacement)
    end

    -- --------------------

    function String.hasPrefix (st, prefix)
        -- Tells whether <st> has <prefix> or not

        local prefixLength = prefix:len()
        return (String.slice(st, 1, prefixLength) == prefix)
    end

    -- --------------------

    function String.hasSuffix (st, suffix)
        -- Tells whether <st> has <suffix> or not

        local suffixLength = suffix:len()
        return (String.slice(st, -suffixLength) == suffix)
    end

    -- --------------------

    function String.isString (st)
        -- Tells whether <st> is a string

        return type(st) == "string"
    end

    -- --------------------

    function String.join (stList, separator)
        -- Returns concatenation of all strings in <stList> separated
        -- by <separator>

        local result = ""

        for i = 1, stList:count() do
            local st = stList:at(i)
            result = result .. iif(i > 1, separator, "") .. st
        end

        return result
    end

    -- --------------------

    function String.length (st)
        -- Returns the length of <st>

        return st:len()
    end

    -- --------------------

    function String.lTrim (st)
        -- Returns <st> with leading blanks removed

        while String.hasPrefix(st, " ") do
            st = String.slice(st, 2)
        end

        return st
    end

    -- --------------------

    function String.replicate (st, count)
        -- Returns <st> repeated <count> times

        return st:rep(count)
    end

    -- --------------------

    function String.rTrim (st)
        -- Returns <st> with trailing blanks removed

        while String.hasSuffix(st, " ") do
            st = String.slice(st, 1, String.length(st) - 1)
        end

        return st
    end

    -- --------------------

    function String.slice (st, startPosition, endPosition)
        -- Returns substring of <st> starting at <startPosition> and
        -- ending at <endPosition>; if <endPosition> is missing, it is
        -- assumed to be the length of the string

        return st:sub(startPosition, endPosition)
    end

    -- --------------------

    function String.split (st, separator)
        -- Splits string <st> at <separator> into parts of a list
        -- and returns it

        local separatorLength = separator:len()
        local partList = List:make()

        while true do
            local separatorPosition = String.find(st, separator)
            if separatorPosition == nil then break end
            local part = String.slice(st, 1, separatorPosition - 1)
            st = String.slice(st, separatorPosition + separatorLength)
            partList:append(part)
        end

        partList:append(st)
        return partList
    end

    -- --------------------

    function String.splitAt (st, separator)
        -- Splits string <st> at first occurence of <separator> into
        -- prefix and suffix

        local separatorLength = String.length(separator)
        local separatorPosition = String.find(st, separator)
        local prefix, suffix

        if separatorPosition == nil then
            prefix, suffix = st, ""
        else
            prefix = String.slice(st, 1, separatorPosition - 1)
            suffix = String.slice(st, separatorPosition + separatorLength)
        end

        return prefix, suffix
    end

    -- --------------------

    function String.toLowercase (st)
        -- Returns lowercased version of <st>

        return st:lower()
    end

    -- --------------------

    function String.toUppercase (st)
        -- Returns uppercased version of <st>

        return st:upper()
    end

    -- --------------------

    function String.trim (st)
        -- Returns <st> with leading and trailing blanks removed

        return String.rTrim(String.lTrim(st))
    end

-- ==========
-- end String
-- ==========
