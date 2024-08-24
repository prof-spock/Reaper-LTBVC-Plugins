-- Base - provides primitive functions missing from Lua
--        like conditional expressions
--
-- author: Dr. Thomas Tensi, 2019-08

-- ====================
-- IMPORTS
-- ====================

require("string")

-- ===========
-- module Base
-- ===========
    -- This module provides primitive functions missing from Lua
    -- like conditional expressions

    -- ====================
    -- EXPORTED FEATURES
    -- ====================

    infinity = 999999

    -- --------------------

    function iif (condition, trueValue, falseValue)
        -- Returns <trueValue> when <condition> is true, otherwise
        -- <falseValue>

        local result

        if condition then
            result = trueValue
        else
            result = falseValue
        end

        return result
    end

    -- --------------------

    function iif2 (conditionA, trueValueA,
                   conditionB, trueValueB,
                   falseValue)
        -- Returns <trueValueA> when <conditionA> holds, <trueValueB>
        -- when <conditionBA> holds, otherwise <falseValue>

        local result

        if conditionA then
            result = trueValueA
        elseif conditionB then
            result = trueValueB
        else
            result = falseValue
        end

        return result
    end

    -- --------------------

    function boolToInt (b)
        -- Returns 1 when <b> is true and 0 otherwise

        return iif(b, 1, 0)
    end

    -- --------------------

    function isInRange (a, low, high)
        -- Tells whether <a> is between <low> and <high> (boundaries
        -- included)

        return (a >= low and a <= high)
    end

    -- --------------------

    function round (d, digitCount)
        -- Rounds <d> to <digitCount> digits after decimal point;
        -- default for <digitCount> is 0

        digitCount = digitCount or 0
        local factor = 1
        for i = 1, digitCount do  factor = 10 * factor  end
        local result = math.floor(d * factor + 0.5) / factor
        return result
    end

    -- --------------------

    function toInt (d)
        -- Returns integer representation of <d>

        return math.floor(d)
    end

-- ========
-- end Base
-- ========
