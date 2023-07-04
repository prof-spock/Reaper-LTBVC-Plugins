-- adjustSoXEffectNamesInAllTracks -- changes descriptions of SoX
--                                    effects in effects lists of all
--                                    tracks
--
--
-- by Dr. TT, 2023

local _, scriptPath = reaper.get_action_context()
local scriptDirectory = scriptPath:match('^.+[\\//]')
package.path = scriptDirectory .. "?.lua"
package.path = ("C:/Programme_LOKAL/Multimedia/MIDI/Reaper"
                .. "/Scripts/DrTT-LTBVC_(Lua)/PluginsForLTBVC"
                .. "/?.lua")

-- =======
-- IMPORTS
-- =======

require("SoXEffectNamesAdjuster")
require("OperatingSystem")
require("Reaper")

-- =======================

local _programName = "adjustSoXEffectNamesInAllTracks"

-- =======================

function _initialize ()
    Logging:initialize()
    local directoryPath =
        OperatingSystem.selectDirectory("/tmp", "REAPERLOGS",
                                        "TEMP", "TMP")

    if directoryPath ~= nil then
        Logging.setFileName(directoryPath
                            .. "/reaper_" .. _programName
                            .. ".log")
    end
end

-- --------------------

function _finalize ()
    Logging.finalize()
end

-- =======================

function main ()
    Logging.trace(">>")

    local project = Reaper.Project.current()
    local trackList = project:trackList()
    local effectNameString = SoXEffectNamesAdjuster_normalize(trackList)

    Logging.show(effectNameString)
    Logging.trace("<<")
end

-- =======================

_initialize()
main()
_finalize()
