-- Map - provides services for maps of elements to other elements
-- 
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

require("Set")

-- ====================

-- --------------------
-- CLASS DECLARATION
-- --------------------

Map = Class:make("Map")

-- ==========
-- module Map
-- ==========
    -- This module provides services for maps of elements to other
    -- elements.

    -- --------------------
    -- exported features
    -- --------------------

    -- ············
    -- construction
    -- ············

    function Map.make (cls)
        -- Creates an empty map

       local result = cls:makeInstance()
       result._data = {}
       return result
    end

    -- --------------------

    function Map.makeFromArray (cls, array)
        -- Creates a map from a simple value array

       local result = cls:make()

       for i, value in ipairs(array) do
           result._data[i] = value
       end

       return result
    end

    -- --------------------

    function Map.makeFromPairArray (cls, array)
        -- Creates a map from a simple array with alternating keys and
        -- values

        local result = cls:make()
        local key

        for i, value in ipairs(array) do
            if i % 2 == 1 then
                key = value
            else
                result._data[key] = value
            end
        end

        return result
    end

    -- --------------------

    function Map.makeFromTuple (cls, simpleMap)
        -- Creates a map from a simple map definition

       local result = cls:make()

       for key, value in pairs(simpleMap) do
           result._data[key] = value
       end

       return result
    end

    -- --------------------

    function Map.clone (cls, otherMap)
        -- Creates a shallow clone of <otherMap>

        local result = cls:make()

        for key, value in pairs(otherMap._data) do
            result._data[key] = value
        end

        return result
    end

    -- ·····················
    -- string representation
    -- ·····················

    function Map:__tostring ()
        -- Returns string representation of map

        local st = "Map("
        local isFirst = true

        for key, value in pairs(self._data) do
            local ch = iif(type(key) == "string", "'", "")
            local keyAsString = ch .. tostring(key) .. ch
            ch = iif(type(value) == "string", "'", "")
            local valueAsString = ch .. tostring(value) .. ch
            st = (st .. iif(isFirst, "", ", ")
                  .. keyAsString .. " => " .. valueAsString)
            isFirst = false
        end

        st = st .. ")"
        return st
    end

    -- ··········
    -- measurement
    -- ··········

    function Map:count ()
        -- Returns number of keys in map

        return #(self._data)
    end

    -- --------------------

    function Map:keySet ()
        -- Returns set of all keys in map

        local result = Set:make()

        for key, _ in pairs(self._data) do
            result:include(key)
        end

        return result
    end

    -- --------------------

    function Map:valueSet ()
        -- Returns set of all values in map

        local result = Set:make()

        for _, value in pairs(self._data) do
            result:include(value)
        end

        return result
    end

    -- ················
    -- element access
    -- ················

    function Map:at (element)
        -- Returns value associated with <element> in map

        return self._data[element]
    end

    -- --------------------

    function Map:hasKey (key)
        -- Tells whether <key> occurs as key in map

        return (self._data[key] ~= nil)
    end

    -- ················
    -- change
    -- ················

    function Map:clear ()
        -- Removes all elements in map

        self._data = {}
    end

    -- --------------------

    function Map:remove (element)
        -- Removes value associated with <element> in map

        self._data[element] = nil
    end

    -- --------------------

    function Map:set (element, value)
        -- Sets <element> in map to <value>

        self._data[element] = value
    end

-- =======
-- end Map
-- =======
