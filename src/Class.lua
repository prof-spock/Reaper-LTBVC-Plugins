-- Class - provides services for classes; those are emulated
--         by protoype elements as described in the Lua Reference
--         Manual
-- 
-- author: Dr. Thomas Tensi, 2019-08

-- ------------------
-- CLASS DECLARATIONS 
-- ------------------

Class = {}
ClassWithPeer = {}

-- ===========
-- class Class
-- ===========
    -- This class is a metaclass for all classes.  Those are emulated
    -- by protoype elements as described in the Lua Reference Manual.

    -- --------------------
    -- PRIVATE FUNCTIONS
    -- --------------------

    local function _Class_makeInstance (cls)
        -- Returns new instance of <cls>

        local result = {}
        setmetatable(result, cls)
        return result
    end

    -- --------------------
    -- EXPORTED FUNCTIONS
    -- --------------------

    function Class.make (cls, className)
        -- Makes a new class named <className>, prepares its methods
        -- and returns it

        local result = _Class_makeInstance(Class)
        result.__name = className
        result.__index = result
        result.makeInstance = _Class_makeInstance
        return result
    end

    -- --------------------

    function Class.makeVariant (cls, className, ancestorClass)
        -- Makes a new class named <className> as a variant of
        -- <ancestorClass>, prepares its methods and returns it

        local result = Class:make(className)

        -- copy all methods of <ancestorClass>
        for key, value in pairs(ancestorClass) do
            if key ~= "__name" and key ~= "__index" then
                result[key] = value
            end
        end

        return result
    end

    -- --------------------

    function Class:__tostring ()
        -- Returns string representation of a class with name and all
        -- table fields

        local st = String.format("name = %s", self.__name)

        for key, value in pairs(self) do
            if key ~= "__name" then
                local valueType = type(value)

                if valueType == "function" then
                    local fInfo = debug.getinfo(value)
                    valueType = ("FUNC"
                                 .. "(npars = " .. fInfo.nparams
                                 .. ", line = " .. fInfo.linedefined
                                 .. ")")
                end

                st = st .. ", (" .. valueType .. ") " .. key
            end
        end

        return "Class(" .. st .. ")"
    end

-- =========
-- end Class
-- =========

-- ===================
-- class ClassWithPeer
-- ===================
    -- This class is a metaclass for classes wrapping a single peer
    -- element bases on prototype classes as described in the Lua
    -- Reference Manual.

    -- --------------------
    -- PRIVATE FUNCTIONS
    -- --------------------

    function ClassWithPeer._makeInstance (cls, peerObject)
        -- Returns instance of <cls> wrapping <peerObject>; either
        -- returns a new object or an existing object when
        -- <peerObject> is already wrapped

        -- check whether <peerObject> is already there
        mapEntry = cls._peerObjectToWrapperMap[peerObject]

        if mapEntry ~= nil then
            result, count = mapEntry.object, mapEntry.count
        else
            -- make new element
            result = {}
            result._class = cls
            result._peerObject = peerObject
            setmetatable(result, cls)
            count = 0
        end

        cls._peerObjectToWrapperMap[peerObject] = { object = result,
                                                    count  = count + 1 }
        return result
    end

    -- --------------------

    function ClassWithPeer:_freeInstance ()
        -- Frees <self> and reduces reference count by one

        -- check whether some entry exists in reference table
        local cls = self._class
        local mapEntry = cls._peerObjectToWrapperMap[self._peerObject]

        if mapEntry ~= nil then
            -- there is an entry in the reference table, decrease by
            -- one
            local object, count = mapEntry.object, mapEntry.count
            count = count - 1

            if count == 0 then
                mapEntry = nil
            else
                mapEntry = { object = object, count  = count }
            end

            cls._peerObjectToWrapperMap[peerObject] = mapEntry
        end
    end

    -- --------------------
    -- EXPORTED FUNCTIONS
    -- --------------------

    function ClassWithPeer.make (cls, className)
        -- Makes a new class named <className> where each instance has
        -- some peer object, prepares its methods and returns it;
        -- there is a reference count logic used such that instances
        -- are reused

        result = {}
        result.__name = className
        result.__index = result
        result.__gc = ClassWithPeer._freeInstance
        result.makeInstance = ClassWithPeer._makeInstance
        result.internalRepresentation = ClassWithPeer.internalRepresentation
        result._peerObjectToWrapperMap = {}
        return result
    end

    -- --------------------

    function ClassWithPeer:internalRepresentation ()
        -- Returns the associated peer object as the internal
        -- representation of the given object

        return self._peerObject
    end

-- =================
-- end ClassWithPeer
-- =================
