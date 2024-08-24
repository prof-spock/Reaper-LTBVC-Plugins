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

    function OperatingSystem.baseName (fileName, extensionIsShown)
        -- Returns <fileName> without leading path; if
        -- <extensionIsShown> is set, also the extension is
        -- returned

        local fName = "OperatingSystem.baseName"
        extensionIsShown = iif(extensionIsShown == nil,
                               true, extensionIsShown)
        cls = OperatingSystem
        Logging.traceF(fName, ">>: fileName = '%s', extensionIsShown = %s",
                       fileName, extensionIsShown)

        local nameList = String.split(fileName, cls.pathSeparator)
        local shortFileName = nameList:at(nameList:count())
        local result = shortFileName

        if not extensionIsShown then
            local partList = String.split(result, ".")
            partList:removeLast()
            result = String.join(partList, ".")
        end
        
        Logging.traceF(fName, "<<: '%s'", result)
        return result
    end

    -- --------------------

    function OperatingSystem.dirName (filePath)
        -- Returns directory of <filePath>

        local cls = OperatingSystem
        Logging.trace(">>: '%s'", filePath)

        local separator = cls.pathSeparator
        filePath = filePath:gsub("[\\/]", separator)
        local nameList = String.split(filePath, separator)
        nameList:removeLast()
        local result = String.join(nameList, separator)

        Logging.trace("<<: '%s'", result)
        return result
    end

    -- --------------------

    function OperatingSystem.getEnvironmentVariable (name)
        -- Reads environment variable <name> and returns its value;
        -- returns nil on failure

        local fName = "OperatingSystem.getEnvironmentVariable"
        Logging.traceF(fName, ">>: '%s'", name)
        local result = OperatingSystem._getEnvironmentVariableNOLOG(name)
        Logging.traceF(fName, "<<: '%s'", result)
        return result
    end

    -- --------------------

    function OperatingSystem.hasDirectory (directoryName, isWritable)
        -- Tells whether directory specified by <directoryName> exists
        -- in file system; if <isWritable> is set, then it is also
        -- required that the directory is writable

        local fName = "OperatingSystem.hasDirectory"
        Logging.traceF(fName,
                       ">>: directory = '%s', isWritable = %s",
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

        local fName = "OperatingSystem.hasFile"
        Logging.traceF(fName, ">>: '%s'", fileName)

        local result, errorText = OperatingSystem._fileExistsNOLOG(fileName)

        if errorText ~= nil then
            Logging.traceF(fName, "--: error = %s", errorText)
        end
        
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function OperatingSystem.homeDirectoryPath ()
        -- Returns home directory path

        local cls = OperatingSystem
        Logging.trace(">>")

        result = cls.getEnvironmentVariable("HOMEPATH")
        result = result or cls.getEnvironmentVariable("HOME")
        result = result or ""

        Logging.trace("<<: '%s'", result)
        return result
    end

    -- --------------------

    function OperatingSystem.isAbsolutePath (fileName)
        -- Tells whether file or directory specified by <fileName> is an
        -- absolute path in the operating system

        local fName = "OperatingSystem.isAbsolutePath"
        Logging.traceF(fName, ">>: fileName = '%s'", fileName)

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

    OperatingSystem.pathSeparator = "/"
    -- the path separator between the parts in a file path
    
    -- --------------------

    function OperatingSystem.selectDirectory (defaultDirectoryName, ...)
        -- Traverses all optional arguments in <...> giving directory
        -- environment variables and checks whether they specify valid
        -- writable directories; returns first matching directory, if
        -- all fail, <defaultDirectoryName> is returned when writable

        local fName = "OperatingSystem.selectDirectory"
        Logging.traceF(fName, ">>: '%s'", defaultDirectoryName)

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

        Logging.traceF(fName, "<<: '%s'", result)
        return result
    end

-- ===================
-- end OperatingSystem
-- ===================
