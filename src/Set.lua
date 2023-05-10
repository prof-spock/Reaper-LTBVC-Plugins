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
    -- This module provides services for sets of elements (implemented
    -- as arrays of elements.

    -- --------------------
    -- LOCAL FEATURES
    -- --------------------

    function Set:_elementPosition (element)
        -- Returns index position of <element> in set or nil if not
        -- available

        local result

        for i = 1, self._count do
            if self._data[i] == element then
                result = i
                break
            end
        end

        return result
    end

    -- --------------------

    function Set:_iterator (index)
      -- Provides a stateless set iterator function

        index = index + 1
        local isOff = self._count < index

        if not isOff then
            local value = self._data[index]
            return index, value
        end
    end
    
    -- --------------------
    -- EXPORTED FEATURES
    -- --------------------

    -- ············
    -- construction
    -- ············

    function Set.make (cls)
       -- Constructs an empty set

       local result = cls:makeInstance()
       result._data  = {}
       result._count = 0
       return result
    end

    -- --------------------

    function Set.makeFromArray (cls, array)
        -- Creates a set from a simple value array

       local result = cls:make()

       for i, value in ipairs(array) do
           result:include(value)
       end

       return result
    end

    -- --------------------

    function Set.makeFromIterable (cls, iterable)
        -- Constructs a set from the elements in <iterable>

        local result = cls:make()

        for _, element in iterable:iterator() do
            result:include(element)
        end

        return result
    end

    -- --------------------

    function Set:clone ()
        -- Returns shallow clone of set

        return Set:makeFromArray(self._data)
    end

    -- ·····················
    -- string representation
    -- ·····················

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

    -- ················
    -- status report
    -- ················

    function Set:contains (element)
        -- Tells whether <element> is in set
        return self:_elementPosition(element) ~= nil
    end

    -- --------------------

    function Set:count ()
        -- Returns number of elements in set

        return self._count
    end

    -- --------------------

    function Set:elementList ()
        -- Returns all elements of set as a list

        return List:makeFromArray(self._data)
    end

    -- --------------------

    function Set:get ()
        -- Returns some element from set; fails for empty set

        local result

        if self._count > 0 then
           result = self._data[1]
        end

        return result
    end

    -- --------------------

    function Set:isEmpty ()
        -- Tells whether set is empty

        return self._count == 0
    end

    -- ················
    -- change
    -- ················

    function Set:exclude (element)
        -- Removes <element> from set (if available)

        local position = self:_elementPosition(element)

        if position ~= nil then
            self._data[position] = self._data[self._count]
            self._count = self._count - 1
        end
    end

    -- --------------------

    function Set:include (element)
        -- Adds <element> to set

        if not self:contains(element) then
            self._count = self._count + 1
            self._data[self._count] = element
        end
    end

    -- --------------------

    function Set:includeAll (otherSet)
        -- Adds elements from <otherSet> to current

        for _, element in otherSet:iterator() do
            self:include(element)
        end
    end

    -- ················
    -- iteration
    -- ················

    function Set:iterator ()
        -- Returns a triple of the stateless set iterator, the set
        -- itself and the initial index 0

        return Set._iterator, self, 0
    end

-- ==========
-- end Set
-- ==========
