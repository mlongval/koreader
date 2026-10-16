--[[--
Kobo fork: the folders of the current folder as a strip of labelled
buttons under the file browser's title bar, instead of tiles in the grid.
Books keep the grid; folders are for going somewhere.

Tap a folder to open it, hold it for the usual folder dialog. If the
folders need more than MAX_ROWS rows, the last button lists the rest.

@module frontend.apps.filemanager.filemanagerfolderstrip
--]]

local Button = require("ui/widget/button")
local ButtonDialog = require("ui/widget/buttondialog")
local Device = require("device")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local T = require("ffi/util").template
local _ = require("gettext")
local Screen = Device.screen

local MAX_ROWS = 3
local FOLDER = "\u{F114}"

local FolderStrip = {}

local function label(chooser, item)
    local name = item.text:gsub("/$", "")
    local sub_dirs, files = chooser:getList(item.path)
    return T("%1 %2  %3", FOLDER, name, #sub_dirs + #files)
end

--- The strip widget for these folder items, or nil if there are none.
-- on_tap(item) and on_hold(item) are called with the folder item.
function FolderStrip.new(chooser, dirs, width, show_parent, on_tap, on_hold)
    if #dirs == 0 then return end
    local gap = Screen:scaleBySize(10)
    local side = Size.padding.large
    local max_w = width - 2 * side

    local function button(text, callback, hold_callback)
        return Button:new{
            text = text,
            text_font_size = 20,
            text_font_bold = false,
            max_width = max_w,
            padding_h = Screen:scaleBySize(12),
            padding_v = Screen:scaleBySize(6),
            radius = Size.radius.button,
            callback = callback,
            hold_callback = hold_callback,
            show_parent = show_parent,
        }
    end

    local rows = { {} }
    local row_w = 0
    local more_dirs
    for i, item in ipairs(dirs) do
        local b = button(label(chooser, item),
            function() on_tap(item) end,
            function() on_hold(item) end)
        local w = b:getSize().w
        if row_w > 0 and row_w + gap + w > max_w then
            if #rows == MAX_ROWS then
                -- no room: the last button of the last row becomes "N more"
                more_dirs = {}
                local last = table.remove(rows[#rows])
                last:free()
                for j = i - 1, #dirs do table.insert(more_dirs, dirs[j]) end
                b:free()
                break
            end
            table.insert(rows, {})
            row_w = 0
        end
        table.insert(rows[#rows], b)
        row_w = row_w + (row_w > 0 and gap or 0) + w
    end
    if more_dirs then
        local dialog
        local function showMore()
            local buttons = {}
            for __, item in ipairs(more_dirs) do
                table.insert(buttons, {{
                    text = label(chooser, item),
                    align = "left",
                    callback = function()
                        UIManager:close(dialog)
                        on_tap(item)
                    end,
                }})
            end
            dialog = ButtonDialog:new{ buttons = buttons }
            UIManager:show(dialog)
        end
        table.insert(rows[#rows], button(T(_("%1 more…"), #more_dirs), showMore))
    end

    local strip = VerticalGroup:new{ align = "left" }
    for i, row in ipairs(rows) do
        local group = HorizontalGroup:new{ HorizontalSpan:new{ width = side } }
        for j, b in ipairs(row) do
            if j > 1 then table.insert(group, HorizontalSpan:new{ width = gap }) end
            table.insert(group, b)
        end
        table.insert(strip, group)
        table.insert(strip, VerticalSpan:new{ width = gap })
    end
    return strip
end

return FolderStrip
