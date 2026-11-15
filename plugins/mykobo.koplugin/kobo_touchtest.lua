--[[--
Touch test: is the touch screen off? A cross shows in five places in turn;
tap the centre of each. Then it says how far the taps landed from the
crosses, on average (left/right, up/down, in pixels and millimetres), and
offers to correct every tap by that much, everywhere (or to remove a
correction made before).

The correction is applied to each gesture's position after KOReader has
turned it into screen coordinates (the gesture detector's last step), so it
is the same in every app and in every rotation: "down" is always towards
the bottom of the screen as you hold the Kobo. Setting: kobo_touch_offset
{ x = …, y = … } (pixels added to a tap).

@module mykobo.kobo_touchtest
--]]

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template
local Screen = Device.screen

local SETTING = "kobo_touch_offset"

local M = {}

--- The correction now in use: x, y (pixels added to every tap).
function M.offset()
    local o = G_reader_settings:readSetting(SETTING)
    if type(o) == "table" then return o.x or 0, o.y or 0 end
    return 0, 0
end

local hooked = false
--- Install the correction (once per run); it reads the setting each time.
-- It wraps the gesture detector's last step (adjustGesCoordinate, which
-- turns positions into the current rotation's screen coordinates), so the
-- correction is in screen terms whatever the rotation.
function M.install()
    if hooked then return end
    local gd = Device.input and Device.input.gesture_detector
    if not gd or not gd.adjustGesCoordinate then return end
    hooked = true
    local orig = gd.adjustGesCoordinate
    gd.adjustGesCoordinate = function(this, ges)
        local g = orig(this, ges)
        local dx, dy = M.offset()
        if (dx ~= 0 or dy ~= 0) and g and g.pos then
            g.pos.x = g.pos.x + dx
            g.pos.y = g.pos.y + dy
        end
        return g
    end
end

local Test = InputContainer:extend{
    covers_fullscreen = true,
    name = "kobo_touch_test",
}

function Test:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    local w, h = self.dimen.w, self.dimen.h
    -- five places: the middle and near the four corners (away from the edges,
    -- where the device menu and the light drag listen)
    self.targets = {
        { x = math.floor(w / 2), y = math.floor(h / 2) },
        { x = math.floor(w * 0.25), y = math.floor(h * 0.25) },
        { x = math.floor(w * 0.75), y = math.floor(h * 0.25) },
        { x = math.floor(w * 0.25), y = math.floor(h * 0.72) },
        { x = math.floor(w * 0.75), y = math.floor(h * 0.72) },
    }
    self.taps = {}
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
    }
end

function Test:paintTo(bb, x, y)
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    local i = #self.taps + 1
    local function text(s, ty, face)
        local tb = TextBoxWidget:new{
            text = s, face = face or Font:getFace("infofont"), width = self.dimen.w - 2 * Size.padding.large * 2,
            alignment = "center",
        }
        tb:paintTo(bb, x + Size.padding.large * 2, y + ty)
        local th = tb:getSize().h
        tb:free()
        return th
    end
    if self.result then
        local ty = math.floor(self.dimen.h * 0.12)
        ty = ty + text(_("Touch test"), ty, Font:getFace("tfont")) + Size.padding.large * 2
        text(self.result, ty)
        if self.buttons then
            self.buttons:paintTo(bb, x + math.floor((self.dimen.w - self.buttons:getSize().w) / 2),
                y + self.dimen.h - self.buttons:getSize().h - Size.padding.large * 4)
        end
        return
    end
    local t = self.targets[i]
    text(T(_("Touch test: tap the centre of the cross (%1 of %2), the way you normally tap."), i, #self.targets),
        math.floor(self.dimen.h * 0.05))
    local arm, lw = Screen:scaleBySize(40), math.max(2, Screen:scaleBySize(2))
    bb:paintRect(x + t.x - arm, y + t.y - math.floor(lw / 2), 2 * arm, lw, Blitbuffer.COLOR_BLACK)
    bb:paintRect(x + t.x - math.floor(lw / 2), y + t.y - arm, lw, 2 * arm, Blitbuffer.COLOR_BLACK)
    local r = Screen:scaleBySize(6)
    bb:paintRect(x + t.x - r, y + t.y - r, 2 * r, 2 * r, Blitbuffer.COLOR_BLACK)
end

function Test:onTap(_, ges)
    if self.result then
        -- taps on the buttons are theirs
        if self.buttons and self.buttons.dimen and ges.pos:intersectWith(self.buttons.dimen) then return false end
        return true
    end
    local i = #self.taps + 1
    local t = self.targets[i]
    -- what the tap would be without the correction now in use
    local cx, cy = M.offset()
    self.taps[i] = { dx = ges.pos.x - cx - t.x, dy = ges.pos.y - cy - t.y }
    if #self.taps == #self.targets then
        self:finish()
    end
    UIManager:setDirty(self, "ui")
    return true
end

function Test:finish()
    local sx, sy = 0, 0
    for __, d in ipairs(self.taps) do sx, sy = sx + d.dx, sy + d.dy end
    local n = #self.taps
    local mx, my = math.floor(sx / n + 0.5), math.floor(sy / n + 0.5)
    local spread = 0
    for __, d in ipairs(self.taps) do
        spread = math.max(spread, math.abs(d.dy - my), math.abs(d.dx - mx))
    end
    local mm = function(px) return string.format("%.1f", px * 25.4 / (Device:getDeviceScreenDPI() or 227)) end
    local function dir(v, pos, neg)
        if v == 0 then return _("exactly on target") end
        return T("%1 px (%2 mm) %3", math.abs(v), mm(math.abs(v)), v > 0 and pos or neg)
    end
    local cx, cy = M.offset()
    -- where the taps arrive in the apps now (with the correction in use)
    local ax, ay = mx + cx, my + cy
    local off = math.abs(ay) >= 6 or math.abs(ax) >= 6
    local lines = {
        T(_("Your finger landed, on average:\n• up/down: %1\n• left/right: %2"),
            dir(my, _("below the cross"), _("above the cross")),
            dir(mx, _("right of the cross"), _("left of the cross"))),
        T(_("The taps varied by up to %1 px from that average."), spread),
    }
    if cx ~= 0 or cy ~= 0 then
        lines[#lines + 1] = T(_("With the correction in use (%1 px across, %2 px down), taps arrive in the apps:\n• up/down: %3\n• left/right: %4"),
            cx, cy, dir(ay, _("below the cross"), _("above the cross")),
            dir(ax, _("right of the cross"), _("left of the cross")))
    end
    if off then
        lines[#lines + 1] = _("Correct moves every tap, everywhere, so that it lands where you aim. It can be removed here any time.")
    else
        lines[#lines + 1] = _("Taps arrive where you aim (within normal finger accuracy): nothing to correct.")
    end
    self.result = table.concat(lines, "\n\n")
    local row = {}
    if off then
        row[#row + 1] = { text = _("Correct"), callback = function()
            G_reader_settings:saveSetting(SETTING, { x = 0 - mx, y = 0 - my })
            G_reader_settings:flush()
            M.install()
            self:close(_("Taps are corrected now. Run the test again to check."))
        end }
    end
    if cx ~= 0 or cy ~= 0 then
        row[#row + 1] = { text = _("Remove correction"), callback = function()
            G_reader_settings:delSetting(SETTING)
            G_reader_settings:flush()
            self:close(_("No correction now: taps are as the screen reports them."))
        end }
    end
    row[#row + 1] = { text = _("Again"), callback = function()
        self.taps, self.result, self.buttons = {}, nil, nil
        self[1] = nil
        UIManager:setDirty(self, "full")
    end }
    row[#row + 1] = { text = _("Close"), callback = function() self:close() end }
    self.buttons = ButtonTable:new{
        width = math.floor(self.dimen.w * 0.9),
        buttons = { row },
        zero_sep = true,
        show_parent = self,
    }
    -- a child, so its buttons get the taps (it is painted by paintTo above)
    self[1] = self.buttons
    UIManager:setDirty(self, "full")
end

function Test:close(message)
    UIManager:close(self, "full")
    if message then
        UIManager:show(require("ui/widget/infomessage"):new{ text = message, timeout = 3 })
    end
end

function M.show()
    UIManager:show(Test:new{}, "full")
end

return M
