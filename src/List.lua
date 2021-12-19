-- List - provides services for lists of elements, indexed
--        by consecutive natural numbers starting with 1.  Lists are
--        objects providing the typical list functions (like element
--        access by index, iteration, etc.)
-- 
-- author: Dr. Thomas Tensi, 2019-08

-- =======================
-- IMPORTS
-- =======================

require("Class")

-- =======================

-- --------------------
-- CLASS DECLARATION
-- --------------------

List = Class:make("List")

-- ==========
-- class List
-- ==========
    -- This class provides services for lists of elements, indexed
    -- by consecutive natural numbers starting with 1.  Lists are
    -- objects providing the typical list functions

    -- --------------------
    -- LOCAL FEATURES
    -- --------------------

    function List:_iterator (index)
      -- Provides a stateless list iterator function

        index = index + 1
        local isOff = self:count() < index

        if not isOff then
            local value = self:at(index)
            return index, value
        end
    end
    
    -- --------------------

    function List:_reversedIterator (index)
      -- Provides a stateless reversed list iterator function

        index = index - 1
        local isOff = index == 0

        if not isOff then
            local value = self:at(index)
            return index, value
        end
    end
    
    -- --------------------
    -- EXPORTED FEATURES
    -- --------------------

    -- ············
    -- construction
    -- ············

    function List.make (cls)
       -- Constructs an empty list

       local result = cls:makeInstance()
       result._data = {}
       return result
    end

    -- ·····················
    -- string representation
    -- ·····················

    function List:__tostring ()
        -- Returns string representation of list

        local st = "["

        for i, value in ipairs(self._data) do
            st = st .. iif(i == 1, "", ", ") .. tostring(value)
        end

        st = st .. "]"
        return st
    end

    -- ···········
    -- measurement
    -- ···········

    function List:count ()
        -- Returns number of elements in list

        return rawlen(self._data)
    end

    -- ················
    -- status report
    -- ················

    function List:isEmpty ()
        -- Tells whether list has no elements

        return #(self._data) == 0
    end

    -- --------------------

    function List:find (element)
        -- Tells first position of <element> in list; return 0 when
        -- not found

        local result = 0

        for i = 1, self:count() do
            if self:at(i) == element then
                result = i
                break
            end
        end

        return result
    end

    -- ················
    -- element access
    -- ················

    function List:at (index)
        -- Returns element at <index>

        return self._data[index]
    end

    -- --------------------

    function List:first ()
        -- Returns first element of list

        return self._data[1]
    end

    -- --------------------

    function List:last ()
        -- Returns last element of list

        local lastIndex = #(self._data)
        return self._data[lastIndex]
    end

    -- ················
    -- change
    -- ················

    function List:append (element)
        -- Makes <element> the last in list

        table.insert(self._data, element)
    end

    -- --------------------

    function List:clear ()
        -- Removes all elements from list

        self._data = {}
    end

    -- --------------------

    function List:prepend (element)
        -- Makes <element> the first in list and shifts list
        -- accordingly

        table.insert(self._data, 1, element)
    end

    -- --------------------

    function List:remove (i)
        -- Removes <i>-th entry in list

        table.remove(self._data, i)
    end

    -- --------------------

    function List:removeFirst ()
        -- Removes first entry in list

        self:remove(1)
    end

    -- --------------------

    function List:removeLast ()
        -- Removes last entry in list

        self:remove(#self._data)
    end

    -- --------------------

    function List:set (index, element)
        -- Sets element at <index> to <element>

        self._data[index] = element
    end

    -- ················
    -- filtering
    -- ················

    function List:select (conditionProc)
        -- Returns list of all those elements in list with a fulfilled
        -- <conditionProc>

        local result = List:make()

        for _, element in ipairs(self._data) do
            if conditionProc(element) then
                result:append(element)
            end
        end

        return result
    end

    -- ················
    -- sorting
    -- ················

    function List:sort (comparisonProc)
        -- Sorts list by <comparisonProc> telling whether two elements
        -- are in sort order

        table.sort(self._data, comparisonProc)
    end

    -- ················
    -- iteration
    -- ················

    function List:applyToAll (changeProc)
        -- Changes all elements in list by <changeProc>: if changeProc
        -- returns a value, this is assigned to the element, otherwise
        -- an in-place change is assumed

        for i, value in ipairs(self._data) do
            local newValue = changeProc(value)

            if newValue ~= nil then
                self._data[i] = newValue
            end
        end
    end

    -- --------------------

    function List:filter (filterProc)
        -- Returns list of all elements in list fulfilling
        -- <filterProc>

        local result = List:make()

        for _, element in self:iterator() do
            if filterProc(element) then
                result:append(element)
            end
        end

        return result
    end

    -- --------------------

    function List:iterator ()
        -- Returns a triple of the stateless list iterator, the list
        -- itself and the initial index 0

        return List._iterator, self, 0
    end

    -- --------------------

    function List:reversedIterator ()
        -- Returns a triple of the stateless reversed list iterator,
        -- the list itself and the initial count plus 1

        return List._reversedIterator, self, self:count() + 1
    end

-- ========
-- end List
-- ========
