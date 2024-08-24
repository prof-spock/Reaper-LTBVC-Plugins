-- ReaperGraphics - object-oriented wrapper around the Reaper Graphics
--                  API functions plus some extensions
-- 
-- author: Dr. Thomas Tensi, 2019-2023

-- =======
-- IMPORTS
-- =======

require("math")
-- require("reaper")

require("Base")
require("Logging")

-- -----------------------------
-- class and module declarations
-- -----------------------------

ReaperGraphics = {}
ReaperGraphics.Font      = Class:make("ReaperGraphics.Font")
ReaperGraphics.Point     = Class:make("ReaperGraphics.Point")
ReaperGraphics.Rectangle = Class:make("ReaperGraphics.Rectangle")
ReaperGraphics.Size      = Class:make("ReaperGraphics.Size")

ReaperGraphics.Alignment = {}
ReaperGraphics.Color     = {}
ReaperGraphics.Dialog    = Class:make("ReaperGraphics.Dialog")
ReaperGraphics.Mouse     = {}

-- ===============================
-- module ReaperGraphics.Alignment
-- ===============================
    -- This class represents the alignments of text in the graphics
    -- module.

    ReaperGraphics.Alignment.hLeft     = 1
    ReaperGraphics.Alignment.hCentered = 2
    ReaperGraphics.Alignment.hRight    = 3
    ReaperGraphics.Alignment.vTop      = 4
    ReaperGraphics.Alignment.vCentered = 5
    ReaperGraphics.Alignment.vBottom   = 6

-- ============================
-- end ReaperGraphics.Alignment
-- ============================


-- ===========================
-- module ReaperGraphics.Color
-- ===========================
    -- This class represents the BGR colors in the graphics module.

    ReaperGraphics.Color.black     = 0x000000
    ReaperGraphics.Color.red       = 0x0000FF
    ReaperGraphics.Color.green     = 0x00FF00
    ReaperGraphics.Color.yellow    = 0x00FFFF
    ReaperGraphics.Color.blue      = 0xFF0000
    ReaperGraphics.Color.magenta   = 0xFF00FF
    ReaperGraphics.Color.cyan      = 0xFFFF00
    ReaperGraphics.Color.white     = 0xFFFFFF

    ReaperGraphics.Color.darkGray  = 0x404040
    ReaperGraphics.Color.gray      = 0x808080
    ReaperGraphics.Color.lightGray = 0xC0C0C0

-- ========================
-- end ReaperGraphics.Color
-- ========================


-- ===========================
-- class ReaperGraphics.Dialog
-- ===========================
    -- This class represents a graphics dialog window.

    -- --------------------
    -- creation
    -- --------------------

    function ReaperGraphics.Dialog.make (cls, title, rectangle)
        -- Creates or updates window with <title> and bounding rectangle
        -- <rectangle>

        local fName = "ReaperGraphics.Dialog.make"
        Logging.traceF(fName,
                       ">>: title = '%s', rectangle = %s",
                       title, rectangle)

        local result = ReaperGraphics.Dialog:makeInstance()
        local r = rectangle:clampedToIntegerCoordinates()
        gfx.init(title, r.width, r.height, false, r.x, r.y)
        Logging.trace("<<")
        return result
    end

    -- --------------------
    -- complex change
    -- --------------------

    function ReaperGraphics.Dialog:update ()
        -- Updates the Reaper dialog

        local fName = "ReaperGraphics.Dialog.update"
        Logging.traceF(fName, ">>")
        gfx.update()
        Logging.traceF(fName, "<<")
    end

    -- --------------------
    -- change
    -- --------------------

    function ReaperGraphics.Dialog:drawEllipse (boundingBox, isFilled)
        -- Draws ellipse in <boundingBox> in foreground color; if
        -- <isFilled> is set, the rectangle ist filled

        local fName = "ReaperGraphics.Dialog.drawEllipse"
        Logging.traceF(fName, ">>: boundingBox = %s, isFilled = %s",
                       boundingBox, isFilled)

        local x, y, width, height =
            boundingBox:clampedToIntegerCoordinates():unpack()
        local radius = round(iif(width > height, height, width) / 2)

        if not isFilled then
            gfx.roundrect(x, y, width, height, radius)
        else
            gfx.triangle(x + radius,         y,
                         x + width - radius, y,
                         x + width,          y + radius,
                         x + width,          y + height - radius,
                         x + width - radius, y + height,
                         x + radius,         y + height,
                         x,                  y + height - radius,
                         x,                  y + radius,
                         x + radius,         y)
        end

        Logging.traceF(fName, "<<")
    end

    -- --------------------

    function ReaperGraphics.Dialog:drawLine (x1, y1, x2, y2)
        -- Draws line from (<x1>, <y1>) to (<x2>, <y2>)

        local fName = "ReaperGraphics.Dialog.drawLine"
        Logging.traceF(fName,
                       ">>: x1 = %s, y1 = %s, x1 = %s, y1 = %s",
                       x1, y1, x2, y2)
        gfx.line(round(x1), round(y1), round(x2), round(y2))
        Logging.traceF(fName, "<<")
    end

    -- --------------------

    function ReaperGraphics.Dialog:drawRectangle (rectangle,
                                                  isFilled)
        -- Draws <rectangle> in foreground color; if <isFilled> is
        -- set, the rectangle ist filled

        local fName = "ReaperGraphics.Dialog.drawRectangle"
        Logging.traceF(fName, ">>: rectangle = %s, isFilled = %s",
                       rectangle, isFilled)

        local r = rectangle:clampedToIntegerCoordinates()
        gfx.rect(r.x, r.y, r.width, r.height, isFilled)

        Logging.traceF(fName, "<<")
    end

    -- --------------------

    function ReaperGraphics.Dialog:drawString (x, y, st,
                                               hAlignment, vAlignment)
        -- Draws string <st> at (<x>, <y>); aligns st horizontally by
        -- <hAlignment> and vertically by <vAlignment>

        local fName = "ReaperGraphics.Dialog.drawString"
        Logging.traceF(fName,
                       ">>: x = %s, y = %s, st = '%s',"
                       .. " hAlignment = %s,  vAlignment = %s",
                       x, y, st, hAlignment, vAlignment)

        -- set default values
        hAlignment = hAlignment or ReaperGraphics.Alignment.hLeft
        vAlignment = vAlignment or ReaperGraphics.Alignment.vBottom

        local size = ReaperGraphics.Font.current:stringSize(st)

        gfx.x =
            round(x - iif2(hAlignment == ReaperGraphics.Alignment.hRight,
                           size.width,
                           hAlignment == ReaperGraphics.Alignment.hCentered,
                           size.width / 2, 0))
        gfx.y =
            round(y - iif2(vAlignment == ReaperGraphics.Alignment.vTop,
                           size.height,
                           vAlignment == ReaperGraphics.Alignment.vCentered,
                           size.height / 2, 0))
        gfx.drawstr(st)

        Logging.traceF(fName, "<<")
    end

-- =========================
-- end ReaperGraphics.Dialog
-- =========================


-- ==========================
-- class ReaperGraphics.Font
-- ==========================
    -- This module represents a simple font in the graphics module


    ReaperGraphics.Font.current = nil

    -- --------------------
    -- creation
    -- --------------------

    function ReaperGraphics.Font.make (cls, identification,
                                       fontFamily, fontSize, attributes)
        -- Creates a font with <identification> and <fontFamily>,
        -- <fontSize> and <attributes> as its characteristics
        
        local fName = "ReaperGraphics.Font.make"
        Logging.traceF(fName,
                       ">>: identification = %d,"
                       .. "fontFamily = '%s', fontSize = %s,"
                       .. " attributes = '%s'",
                       identification, fontFamily, fontSize, attributes)

        local result = ReaperGraphics.Font:makeInstance()
        result.identification = identification
        gfx.setfont(identification, fontFamily,
                    round(fontSize), attributes)

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------
    -- state change
    -- --------------------

    function ReaperGraphics.Font:activate ()
        -- Make current font the active one

        local fName = "ReaperGraphics.Font.activate"
        Logging.traceF(fName, ">>: self = %s", self)
        gfx.setfont(self.identification)
        ReaperGraphics.Font.current = self

        Logging.traceF(fName, "<<")
    end

    -- --------------------
    -- measurement
    -- --------------------

    function ReaperGraphics.Font:stringSize (st)
        -- Returns size of <st> in current font

        local fName = "ReaperGraphics.Font.stringSize"
        Logging.traceF(fName, ">>: '%s'", st)
        gfx.setfont(self.identification)
        local result = ReaperGraphics.Size:make(gfx.measurestr(st))
        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------
    -- type conversion
    -- --------------------

    function ReaperGraphics.Font:__tostring ()
        -- Returns the string representation of a point

        local result
        local template = "ReaperGraphics.Font(identification = %d)"
        result = string.format(template, self.identification)
        return result
    end

-- ========================
-- end ReaperGraphics.Font
-- ========================

    
-- ==========================
-- class ReaperGraphics.Point
-- ==========================
    -- This module provides a 2D point with x and y coordinate

    -- --------------------
    -- creation
    -- --------------------

    function ReaperGraphics.Point.make (cls, x, y)
        -- creates a point with <x> and <y> coordinates
        
        local fName = "ReaperGraphics.Point.make"
        Logging.traceF(fName, ">>: x = %s, y = %s", x, y)

        -- set default values
        x = x or 0
        y = y or 0
        
        local result = ReaperGraphics.Point:makeInstance()
        result.x = x
        result.y = y

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------
    -- change
    -- --------------------

    function ReaperGraphics.Point:increment (size)
        -- Adds <size> to current point

        local fName = "ReaperGraphics.Point.increment"
        Logging.traceF(fName, ">>: %s", size)
        self.x, self.y = self.x + size.width, self.y + size.height
        Logging.traceF(fName, "<<")
    end

    -- --------------------

    function ReaperGraphics.Point:plus (size)
        -- Returns result of addition of <size> to current point

        return ReaperGraphics.Point:make(self.x + size.width,
                                         self.y + size.height)
    end

    -- --------------------

    function ReaperGraphics.Point:set (x, y)
        -- Sets current point to (<x>, <y>)

        local fName = "ReaperGraphics.Point.set"
        Logging.traceF(fName, ">>: x = %s, y = %s", x, y)
        self.x, self.y = x, y
        Logging.traceF(fName, "<<")
    end

    -- --------------------
    -- type conversion
    -- --------------------

    function ReaperGraphics.Point:unpack ()
        -- Returns the tuple representation of a point

        return self.x, self.y
    end

    -- --------------------

    function ReaperGraphics.Point:__tostring ()
        -- Returns the string representation of a point

        local result
        local template = "ReaperGraphics.Point(x = %s, y = %s)"
        result = string.format(template, self.x, self.y)
        return result
    end

-- ========================
-- end ReaperGraphics.Point
-- ========================

    
-- ==============================
-- class ReaperGraphics.Rectangle
-- ==============================
    -- This module provides a 2D rectangle with x and y coordinate and
    -- width and height

    -- --------------------
    -- creation
    -- --------------------

    function ReaperGraphics.Rectangle.make (cls, x, y, width, height)
        -- creates a rectangle with <x> and <y> coordinates and size
        -- <width> and <height>
        
        local fName = "ReaperGraphics.Rectangle.make"
        Logging.traceF(fName, ">>")

        -- set default values
        x      = x or 0
        y      = y or 0
        width  = width or 0
        height = height or 0
        
        local result = ReaperGraphics.Rectangle:makeInstance()
        result.x      = x
        result.y      = y
        result.width  = width
        result.height = height

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------
    -- adjustment
    -- --------------------

    function ReaperGraphics.Rectangle:clampedToIntegerCoordinates ()
        -- Returns rectangle with cell coordinates of <rectangle>
        -- clamped to integer values

        local fName = "ReaperGraphics.Rectangle.clampedToIntegerCoordinates"
        Logging.traceF(fName, ">>: %s", self)
        local result =
            ReaperGraphics.Rectangle:make(round(self.x),
                                          round(self.y),
                                          round(self.width),
                                          round(self.height))
        Logging.traceF(fName, "<<: %s", result)
        return result
    end
    
    -- --------------------
    -- measurement
    -- --------------------

    function ReaperGraphics.Rectangle:cell (point, cellSize)
        -- Returns the cell coordinates of <point> within rectangle
        -- where each cell has size <cellSize>

        local fName = "ReaperGraphics.Rectangle.cell"
        Logging.traceF(fName,
                       ">>: point = %s, cellSize = %s",
                       point, cellSize)

        local cellIndexProc =
            function (v1, v2, d)  return 1 + math.floor((v1 - v2) / d)  end
        local columnIndex = cellIndexProc(point.x, self.x, cellSize.width)
        local rowIndex    = cellIndexProc(point.y, self.y, cellSize.height)

        Logging.traceF(fName, "<<: columnIndex = %d, rowIndex = %d",
                       columnIndex, rowIndex)
        return columnIndex, rowIndex
    end

    -- --------------------

    function ReaperGraphics.Rectangle:contains (point)
        -- Tells whether rectangle contains <point>

        local fName = "ReaperGraphics.Rectangle.contains"
        Logging.traceF(fName, ">>: point = %s", point)

        local x, y = point.x, point.y
        local result = (self.x <= x and x < self.x + self.width
                        and self.y <= y and y < self.y + self.height)

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------
    -- type conversion
    -- --------------------

    function ReaperGraphics.Rectangle:unpack ()
        -- Returns the tuple representation of a rectangle

        return self.x, self.y, self.width, self.height
    end

    -- --------------------

    function ReaperGraphics.Rectangle:__tostring ()
        -- Returns the string representation of a point

        local result
        local template = "ReaperGraphics.Rectangle(x = %s, y = %s,"
                                          .. " width = %s, height = %s)"
        result = string.format(template,
                               self.x, self.y, self.width, self.height)
        return result
    end
    
-- ============================
-- end ReaperGraphics.Rectangle
-- ============================

    
-- =========================
-- class ReaperGraphics.Size
-- =========================
    -- This module provides a 2D size with width and height coordinate

    -- --------------------
    -- creation
    -- --------------------

    function ReaperGraphics.Size.make (cls, width, height)
        -- creates a point with <width> and <height> coordinates
        
        local fName = "ReaperGraphics.Size.make"
        Logging.traceF(fName, ">>")

        -- set default values
        width  = width or 0
        height = height or 0
        
        local result = ReaperGraphics.Size:makeInstance()
        result.width = width
        result.height = height

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------
    -- change
    -- --------------------

    function ReaperGraphics.Size:scaledBy (widthFactor, heightFactor)
        -- Returns size based on current size scaled by
        -- (<widthFactor>, <heightFactor>); if <heightFactor> is nil,
        -- <widthFactor> is used for both dimensions, if both are
        -- missing, zero is assumed

        local fName = "ReaperGraphics.Size.scaledBy"
        Logging.traceF(fName,
                       ">>: widthFactor = %s, heightFactor = %s",
                       widthFactor, heightFactor)

        -- set default values
        widthFactor  = widthFactor or 0
        heightFactor = heightFactor or widthFactor

        local result =
            ReaperGraphics.Size:make(self.width * widthFactor,
                                     self.height * heightFactor)

        Logging.traceF(fName, "<<: %s", result)
        return result
    end

    -- --------------------

    function ReaperGraphics.Size:set (width, height)
        -- Sets current size to (<x>, <y>)

        local fName = "ReaperGraphics.Size.set"
        Logging.traceF(fName, ">>: width = %s, height = %s", width, height)
        self.width, self.height = width, height
        Logging.traceF(fName, "<<")
    end

    -- --------------------
    -- type conversion
    -- --------------------

    function ReaperGraphics.Size:unpack ()
        -- Returns the tuple representation of a size

        return self.width, self.height
    end

    -- --------------------

    function ReaperGraphics.Size:__tostring ()
        -- Returns the string representation of a point

        local result
        local template = "ReaperGraphics.Size(width = %s, height = %s)"
        result = string.format(template, self.width, self.height)
        return result
    end

-- ========================
-- end ReaperGraphics.Size
-- ========================

    
-- ===========================
-- module ReaperGraphics.Mouse
-- ===========================

    function ReaperGraphics.Mouse.position ()
        -- returns position of mouse

        local fName = "ReaperGraphics.Mouse.position"
        Logging.traceF(fName, ">>")
        local result = ReaperGraphics.Point:make(gfx.mouse_x, gfx.mouse_y)
        Logging.traceF(fName, "<<: %s", result)
        return result
    end
    
    -- --------------------
            
    function ReaperGraphics.Mouse.status ()
        -- returns status of mouse as a tuple

        local fName = "ReaperGraphics.Mouse.status"
        Logging.traceF(fName, ">>")
        local mouseStatus = gfx.mouse_cap

        local mouseStatusBit =
            function (divisionFactor)
                return math.fmod(mouseStatus // divisionFactor, 2) > 0
            end

        local result = {}
        result.leftMouseButtonIsDown   = mouseStatusBit( 1)
        result.rightMouseButtonIsDown  = mouseStatusBit( 2)
        result.commandKeyIsPressed     = mouseStatusBit( 4)
        result.shiftKeyIsPressed       = mouseStatusBit( 8)
        result.optionKeyIsPressed      = mouseStatusBit(16)
        result.controlKeyIsPressed     = mouseStatusBit(32)
        result.middleMouseButtonIsDown = mouseStatusBit(64)

        Logging.traceF(fName,
                       "<<: "
                       .. "{leftMouseButtonIsDown = %s,"
                       .. " rightMouseButtonIsDown = %s,"
                       .. " commandKeyIsPressed = %s,"
                       .. " shiftKeyIsPressed = %s,"
                       .. " optionKeyIsPressed = %s,"
                       .. " controlKeyIsPressed = %s,"
                       .. " middleMouseButtonIsDown = %s}",
                       result.leftMouseButtonIsDown,
                       result.rightMouseButtonIsDown,
                       result.commandKeyIsPressed,
                       result.shiftKeyIsPressed,
                       result.optionKeyIsPressed,
                       result.controlKeyIsPressed,
                       result.middleMouseButtonIsDown)
        return result
    end
    

-- ========================
-- end ReaperGraphics.Mouse
-- ========================

function ReaperGraphics.setBackgroundColor (bgrColor)
    -- Sets background color to <bgrColor>

    Logging.trace(">>: %d", bgrColor)
    gfx.clear = bgrColor
    Logging.trace("<<")
end

-- --------------------
            
function ReaperGraphics.setColor (bgrColor)
    -- Sets graphics color to <bgrColor>

    Logging.trace(">>: %d", bgrColor)
    local bluePart  = bgrColor // 65536
    local greenPart = math.fmod(bgrColor // 256, 256)
    local redPart   = math.fmod(bgrColor, 256)

    gfx.set(redPart / 256, greenPart / 256, bluePart / 256)
    Logging.trace("<<")
end
