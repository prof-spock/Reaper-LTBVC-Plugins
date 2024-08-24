-- Logging - provides some primitive form of logging to the
--           console or to some log file
--
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

require("debug")
require("io")

require("Base")
require("List")
require("String")

-- ====================

-- --------------------
-- MODULE DECLARATION 
-- --------------------

Logging = {}

-- ==============
-- module Logging
-- ==============
    -- This module provides some primitive form of logging to the
    -- console or to some log file.

    -- --------------------
    -- local features
    -- --------------------

    Logging._fileIsKeptOpen = false
    Logging._fileIsOpen     = false
    Logging._fileName       = ""
    Logging._isEnabled      = false
    Logging._logfile        = nil

    -- buffers log data before log file is opened, otherwise a
    -- write-through will be done
    Logging._buffer         = List:make()

    -- --------------------

    function Logging._callingFunctionName (format)
        -- Derives function name from format information and checks
        -- whether the calling function is a helper function that
        -- should not be logged itself and set <stackLevel>
        -- accordingly

        -- check whether <format> starts with trace prefix
        local pattern = "#?[<>%-][<>%-]"
        local startPosition, endPosition =
                  String.findPattern(format, pattern)
        local patternIsFound = (startPosition == 1)
        local isHelperFunction = (endPosition == 3)
        local functionName

        if patternIsFound then
            -- check whether the calling function is a helper function that
            -- should not be logged itself and set <stackLevel>
            -- accordingly: if we are in a non-helper, there is this
            -- _callingFunctionName frame and the
            -- _callingFunctionNameOnStackLevel on the stack,
            -- otherwise it is additionally the helper function
            local stackLevel = iif(isHelperFunction, 2, 1)
            functionName =
                Logging._callingFunctionNameOnStackLevel(stackLevel)
        end

        return functionName
    end

    -- --------------------

    function Logging._callingFunctionNameOnStackLevel (level)
        -- Returns name of function on stack level <level> where 0
        -- signifies current function, 1 the caller etc.

        local debugInfo
        local result

        -- adapt level to take care of additional functions on stack:
        -- 0 = debug.getinfo, 1 = _callingFunctionNameOnStackLevel,
        -- 2 = trace, ...
        debugInfo = debug.getinfo(level + 3, "Sn")

        if debugInfo ~= nil then
            local functionName = debugInfo.name
            functionName = iif(functionName == nil, "???", functionName)
            local fileName = String.globalReplace(debugInfo.short_src,
                                                  ".*[/\\]", "")
            local moduleName = String.globalReplace(fileName,
                                                    "%.[^%.]+", "")
            result = moduleName .. "." .. functionName
        end

        result = iif(result == nil, "???", result)
        return result
    end

    -- --------------------

    function Logging._closeFileConditionally ()
        -- Closes log file if open

        if Logging._fileIsOpen then
            Logging._file:close()
        end
    end

    -- --------------------

    function Logging._openOrCreateFile (isNew)
        -- Creates or reopens logging file depending on value of
        -- <isNew>

        if Logging._fileName == "" or Logging._fileName == "STDERR" then
            Logging._file = nil
        else
            local mode = iif(isNew, "w", "a")
            Logging._file = io.open(Logging._fileName, mode)
        end

        Logging._fileIsOpen = (Logging._file ~= nil)
    end
  
    -- --------------------

    function Logging._writeLine (st)
        -- Reopens logging file and writes single line <st>

        if Logging._isEnabled then
            st = st .. '\n'
            
            if Logging._fileName == "" then
                -- no output file => put line into buffer
                Logging._buffer:append(st)
            else
                if not Logging._fileIsKeptOpen then
                    Logging._openOrCreateFile(false)
                end

                if Logging._file == nil then
                    -- output file cannot be accessed => put line into
                    -- buffer
                    Logging._buffer:append(st)
                else
                    Logging._writeStringDirectly(st)
                end

                if not Logging._fileIsKeptOpen then
                    Logging._file:close()
                end
            end
        end
    end

    -- --------------------

    function Logging._writeStringDirectly (st)
        -- Writes <st> to logging file

        Logging._file:write(st)
        Logging._file:flush()
    end

    -- ====================
    -- EXPORTED FEATURES
    -- ====================

    function Logging.initialize (cls)
        -- Starts logging

        cls._fileName       = ""
        cls._fileIsOpen     = false
        cls._isEnabled      = true
        cls._buffer:clear()

        header = "START LOGGING -*- coding:latin-1 -*-"
        cls._writeLine(header)
    end

    -- --------------------

    function Logging.finalize (fileName)
        -- Closes log file if necessary

        local footer = "END LOGGING"
        Logging._writeLine(footer)
        Logging._closeFileConditionally()
        Logging._isEnabled = false
    end

    -- --------------------
    -- --------------------

    function Logging.setEnabled (_isEnabled)
        -- Sets logging either active or inactive

        Logging._isEnabled = _isEnabled
    end

    -- --------------------

    function Logging.setFileName (fileName, isKeptOpen)
        -- Sets file name for logging to <fileName>; if <isKeptOpen>
        -- is set, the logging file is not closed after each log entry

        if Logging._fileName == fileName then
            Logging._writeLine(String.format("logging file %s"
                                          .. " already open => skip",
                                          fileName))
        else
            Logging._fileName       = fileName
            Logging._fileIsKeptOpen = iif(fileIsKeptOpen == nil,
                                       true, fileIsKeptOpen)
            Logging._openOrCreateFile(true)

            if Logging._file == nil then
                Logging._fileName = ""
            else
                for i, line in Logging._buffer:iterator() do
                    Logging._writeStringDirectly(line)
                end

                Logging._buffer:clear()
            end

            if not Logging._fileIsKeptOpen then
                Logging._file:close()
            end
        end
    end

    -- --------------------

    function Logging.show (message)
        -- Shows <message> in Reaper message window

        reaper.ShowConsoleMsg(message .. "\n")
    end

    -- --------------------

    function Logging.showFormatted (format, ...)
        -- Shows message to log file characterized by <format> and
        -- additional parameters in Reaper message window

        Logging.show(String.format(format, ...))
    end

    -- --------------------

    function Logging.log (message)
        -- Logs <message> to log file

        Logging._writeLine(message)
    end

    -- --------------------

    function Logging.logFormatted (format, ...)
        -- Logs message to log file characterized by <format> and
        -- additional parameters

        Logging.log(String.format(format, ...))
    end

    -- --------------------

    function Logging.trace (format, ...)
        -- Issues a trace message to log file characterized by
        -- <format> and additional parameters; parses format for
        -- leadin string (">>", "<<", "--") and adds name of calling
        -- function

        local functionName = Logging._callingFunctionName(format)
        Logging.traceF(functionName, format, ...)
    end

    -- --------------------

    function Logging.traceError (format, ...)
        -- issues a trace error message to log file characterized by
        -- <format> and additional parameters; inserts "--" prefix to
        -- format and adds name of calling function

        local functionName =
            Logging._callingFunctionName("--: " .. format)
        Logging.traceErrorF(functionName, format, ...)
    end

    -- --------------------

    function Logging.traceErrorF (functionName, format, ...)
        -- Issues a trace error message to log file characterized by
        -- <format> and additional parameters; inserts "--" prefix to
        -- format and adds <functionName> of calling function; to be
        -- used when derived function name is not specific enough

        local message = "--: ERROR - " .. format
        Logging.traceF(functionName, message, ...)
    end

    -- --------------------

    function Logging.traceF (functionName, format, ...)
        -- Logs message to log file characterized by <format> and
        -- additional parameters; parses format for leadin string
        -- (">>", "<<", "--") and adds <functionName> of calling
        -- function; to be used when derived function name is not
        -- specific enough

        local message

        -- check whether <format> starts with trace prefix
        local pattern = "#?[<>%-][<>%-]"
        local startPosition, endPosition = String.findPattern(format, pattern)
        local patternIsFound = (startPosition == 1)
        local isHelperFunction = (endPosition == 3)

        if patternIsFound then
            local stackLevel
            local prefix = String.slice(format, endPosition - 1, endPosition)
            format = prefix .. "%s" .. String.slice(format, endPosition + 1)
        end

        if functionName == nil then
            message = String.format(format, ...)
        else
            message = String.format(format, functionName, ...)
        end

        Logging.log(message)
    end

-- ===========
-- end Logging
-- ===========
