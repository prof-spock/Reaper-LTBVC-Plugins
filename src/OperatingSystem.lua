-- OperatingSystem --  provides some utility functions from the operating
--                     system e.g. checking for files or directories,
--                     returning a temporary path etc.
--
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

require("io")

require("Base")
require("Logging")

-- ====================

-- --------------------
-- MODULE DECLARATION 
-- --------------------

OperatingSystem = {}

-- ======================
-- module OperatingSystem
-- ======================
    -- Provides some utility functions from the operating
    -- system e.g. checking for files or directories,
    -- returning a temporary path etc.

    -- --------------------
    -- local features
    -- --------------------

    function OperatingSystem._fileExistsNOLOG (fileName)
        -- Tells whether file specified by <fileName> exists in
        -- file system

        local Code_permissionDenied = 13
        local isOkay, errorText, errorCode = os.rename(fileName, fileName)

        if not isOkay then
            if errorCode == Code_permissionDenied then
               isOkay = true
               errorText = ""
            end
        end

        result = isOkay
        return result, errorText
    end

    -- --------------------

    function OperatingSystem._getEnvironmentVariableNOLOG (name)
        -- Reads environment variable <name> and returns its value;
        -- returns nil on failure

        return os.getenv(name)
    end

    -- --------------------
    -- exported features
    -- --------------------

    function OperatingSystem.getEnvironmentVariable (name)
        -- Reads environment variable <name> and returns its value;
        -- returns nil on failure

        local fName = "OperatingSystem.getEnvironmentVariable"
        Logging.traceF(fName, ">>: %s", name)
        local result = OperatingSystem._getEnvironmentVariableNOLOG(name)
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function OperatingSystem.hasDirectory (directoryName, isWritable)
        -- Tells whether directory specified by <directoryName> exists
        -- in file system; if <isWritable> is set, then it is also
        -- required that the directory is writable

        local fName = "OperatingSystem.directoryExists"
        Logging.traceF(fName,
                       ">>: directory = %s, isWritable = %s",
                       directoryName, isWritable)

        local result, errorText =
                  OperatingSystem._fileExistsNOLOG(directoryName .. "/")

        if errorText ~= nil then
            Logging.traceF(fName, "--: error = %s", errorText)
        end
        
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function OperatingSystem.hasFile (fileName)
        -- Tells whether file specified by <fileName> exists in
        -- file system

        local fName = "OperatingSystem.fileExists"
        Logging.traceF(fName, ">>: %s", fileName)

        local result, errorText = OperatingSystem._fileExistsNOLOG(fileName)

        if errorText ~= nil then
            Logging.traceF(fName, "--: error = %s", errorText)
        end
        
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function OperatingSystem.isAbsolutePath (fileName)
        -- Tells whether file or directory specified by <fileName> is an
        -- absolute path in the operating system

        local fName = "OperatingSystem.isAbsolutePath"
        Logging.traceF(fName, ">>: fileName = %s", fileName)

        local windowsPatternMatch =
                  String.findPattern(fileName, "^[A-Za-z]:[/\\]")
        local generalPatternMatch =
                  String.findPattern(fileName, "^[/\\]")
        local result = iif(windowsPatternMatch or generalPatternMatch,
                           true, false)

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function OperatingSystem.selectDirectory (defaultDirectoryName, ...)
        -- Traverses all optional arguments in <...> giving directory
        -- environment variables and checks whether they specify valid
        -- writable directories; returns first matching directory, if
        -- all fail, <defaultDirectoryName> is returned when writable

        local fName = "OperatingSystem.selectDirectory"
        Logging.traceF(fName, ">>: %s", defaultDirectoryName)

        local directoryNameList = List:make()

        -- traverse all environment variables and record associated
        -- directory (if any)
        for _, variableName in ipairs({...}) do
            local directoryName =
                      OperatingSystem.getEnvironmentVariable(variableName)

            if directoryName ~= nil then
                directoryNameList:append(directoryName)
            end
        end

        directoryNameList:append(defaultDirectoryName)
        local result

        for _, directoryName in directoryNameList:iterator() do
            if OperatingSystem.hasDirectory(directoryName) then
                result = directoryName
                break
            end
        end

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

-- ===================
-- end OperatingSystem
-- ===================
