-- Set - provides services for sets of elements.
-- 
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

require("List")

-- ====================

-- --------------------
-- CLASS DECLARATION
-- --------------------

Set = Class:make("Set")

-- ==========
-- module Set
-- ==========
    -- This module provides services for sets of elements.

    -- --------------------
    -- EXPORTED FEATURES
    -- --------------------

    function Set.make (cls)
       -- Constructs an empty set

       local result = cls:makeInstance()
       result._data  = {}
       result._count = 0
       return result
    end

    -- --------------------

    function Set:clone ()
        -- Returns shallow clone of set

        local result = Set:make()
        local elementList = self:elementList()

        for i = 1, elementList:count() do
            result:include(elementList:at(i))
        end

        return result
    end

    -- --------------------

    function Set:contains (element)
        -- Tells whether <element> is in set

        -- return iif(self._data[element], true, false)
        return self._data[element]
    end

    -- --------------------

    function Set:count ()
        -- Returns number of elements in set

        return self._count
    end

    -- --------------------

    function Set:elementList ()
        -- Returns all elements of set as a list

        local result = List:make()

        for element, _ in pairs(self._data) do
            result:append(element)
        end

        return result
    end

    -- --------------------

    function Set:exclude (element)
        -- Removes <element> from set (if available)

        if self:contains(element) then
            self._data[element] = nil
            self._count = self._count - 1
        end
    end

    -- --------------------

    function Set:include (element)
        -- Adds <element> to set

        if not self:contains(element) then
            self._data[element] = true
            self._count = self._count + 1
        end
    end

    -- --------------------

    function Set:get ()
        -- Returns some element from set; fails for empty set

        local result = nil

        if not self:isEmpty() then
           _, result = pairs(self._data)[1]
        end

        return result
    end

    -- --------------------

    function Set:isEmpty ()
        -- Tells whether set is empty

        return self:count() == 0
    end

    -- --------------------

    function Set:__tostring ()
        -- Returns string representation of set

        local st = "Set("
        local elementList = self:elementList()

        for i = 1, elementList:count() do
            st = (st .. iif(i == 1, "", ", ")
                  .. tostring(elementList:at(i)))
        end

        st = st .. ")"
        return st
    end

-- ==========
-- end Set
-- ==========
