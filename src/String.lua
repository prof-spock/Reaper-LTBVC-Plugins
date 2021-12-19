-- String - provides some utility functions for strings
-- 
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

require("string")  -- the Lua internal string module
require("List")

-- ==================

-- --------------------
-- MODULE DECLARATION
-- --------------------

String = {}

-- =============
-- module String
-- =============
    -- This module provides some utility functions for strings.

    -- --------------------
    -- EXPORTED FEATURES
    -- --------------------

    String.newline = "\n"

    -- --------------------

    function String.find (st, substring)
        -- Tells the first and last position where <st> contains
        -- <substring>, otherwise returns nil

        return string.find(st, substring, 1, true)
    end

    -- --------------------

    function String.findPattern (st, pattern)
        -- Tells the first and last position where <st> contains
        -- <pattern>, otherwise returns nil

        return string.find(st, pattern)
    end

    -- --------------------

    function String.format (template, ...)
        -- Returns string produced by applying <template> to the
        -- additional parameters

        return string.format(template, ...)
    end

    -- --------------------

    function String.globalReplace (st, pattern, replacement)
        -- Replaces all occurences of <pattern> in <st> by
        -- <replacement>

        return string.gsub(st, pattern, replacement)
    end

    -- --------------------

    function String.hasPrefix (st, prefix)
        -- Tells whether <st> has <prefix> or not

        local prefixLength = String.length(prefix)
        return (String.slice(st, 1, prefixLength) == prefix)
    end

    -- --------------------

    function String.hasSuffix (st, suffix)
        -- Tells whether <st> has <suffix> or not

        local suffixLength = String.length(suffix)
        return (String.slice(st, -suffixLength) == suffix)
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

        return string.len(st)
    end

    -- --------------------

    function String.replicate (st, count)
        -- Returns <st> repeated <count> times

        return string.rep(st, count)
    end

    -- --------------------

    function String.slice (st, startPosition, endPosition)
        -- Returns substring of <st> starting at <startPosition> and
        -- ending at <endPosition>; if <endPosition> is missing, it is
        -- assumed to be the length of the string

        return string.sub(st, startPosition, endPosition)
    end

    -- --------------------

    function String.split (st, separator)
        -- Splits string <st> at <separator> into parts of a list
        -- and returns it

        local separatorLength = String.length(separator)
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

        return string.lower(st)
    end

    -- --------------------

    function String.toUppercase (st)
        -- Returns uppercased version of <st>

        return string.upper(st)
    end

    -- --------------------

    function String.trim (st)
        -- Returns <st> with leading and trailing blanks removed

        while String.hasPrefix(st, " ") do
            st = String.slice(st, 2)
        end

        while String.hasSuffix(st, " ") do
            st = String.slice(st, 1, String.length(st) - 1)
        end

        return st
    end

-- ==========
-- end String
-- ==========
