--[[--
Kobo fork: the parts of the top menu that are the same in the reader and
the file browser.

  - the Menu tab (at the left edge): word label, light state, hold = light
  - the Settings tab: word label, network state, hold = network panel
  - menu items: Light, File browser (reader), My Kobo, Tools

The network panel itself is the tailscale plugin's (ShowNetworkPanel);
Dev mode is the mykobo plugin's.
]]

local Device = require("device")
local Event = require("ui/event")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local KoboMenu = {}

local function lightOn()
    return Device:hasFrontlight() and Device:getPowerDevice():isFrontlightOn()
end

function KoboMenu.devMode()
    return (G_reader_settings:readSetting("kobo_devmode_until") or 0) > os.time()
end

-- "", " ◦" (Wi-Fi), " ●" (Wi-Fi and Tailscale), then " DEV" in Dev mode.
local function networkMark(ui)
    local mark = ""
    local ts = ui and ui.tailscale
    if ts and ts.isRunning and ts:isRunning() then
        mark = " ●"
    elseif NetworkMgr:isWifiOn() then
        mark = " ◦"
    end
    if KoboMenu.devMode() then mark = mark .. " DEV" end
    return mark
end

-- close: function closing the menu.
function KoboMenu.tabs(close, ui)
    return {
        main = {
            icon = "appbar.menu",
            label_func = function()
                return lightOn() and _("Menu") .. " ☀" or _("Menu")
            end,
            hold_callback = function()
                close()
                UIManager:broadcastEvent(Event:new("ToggleFrontlight"))
            end,
        },
        setting = {
            icon = "appbar.settings",
            label_func = function() return _("Settings") .. networkMark(ui) end,
            hold_callback = function()
                close()
                UIManager:broadcastEvent(Event:new("ShowNetworkPanel"))
            end,
        },
        search = { icon = "appbar.search", label = _("Search") },
        navi = { icon = "appbar.navigation", label = _("Book") },
        typeset = { icon = "appbar.typeset", label = _("Style") },
        filemanager_settings = { icon = "appbar.filebrowser", label = _("Folder") },
    }
end

function KoboMenu.addItems(menu_items)
    if Device:hasFrontlight() then
        menu_items.light_toggle = {
            text_func = function()
                return lightOn() and _("Light: on") or _("Light: off")
            end,
            help_text = _("Long-press for brightness and warmth. Holding the Menu tab also turns the light on or off."),
            checked_func = lightOn,
            callback = function(touchmenu_instance)
                UIManager:broadcastEvent(Event:new("ToggleFrontlight"))
                touchmenu_instance:updateItems()
            end,
            hold_callback = function()
                UIManager:broadcastEvent(Event:new("ShowFlDialog"))
            end,
        }
    end
    menu_items.my_kobo = { text = _("My Kobo") }
end

return KoboMenu
