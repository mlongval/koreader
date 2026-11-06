--[[--
The device menu: one drop-down for the Kobo apps (Launcher, Notan, Chess…),
so the light, Wi-Fi, Dev mode, sleep and the rest are at hand without
leaving the app for KOReader's own menu. It looks like KOReader's top menu
(a TouchMenu with one tab) and opens with a swipe down from the top edge.

    local ok, DeviceMenu = pcall(require, "kobo_devicemenu")
    -- in the app's swipe handler:
    if ok and DeviceMenu.isTopSwipe(ges) then
        DeviceMenu.show{
            title = _("Notan"),
            items = { { text = _("Refresh"), callback = ... }, ... },  -- the app's own, first
            close_app = function() ... end,   -- for "Home": the app closes first
        }
        return true
    end

Lives in mykobo.koplugin (Kobo fork of KOReader); plugins' folders are on
the Lua path once loaded, so any plugin can require it.

@module kobo_devicemenu
--]]

local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Event = require("ui/event")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template
local Screen = Device.screen

local DeviceMenu = {}

-- A swipe down that starts this close to the top (fraction of the height).
DeviceMenu.TOP_ZONE = 0.1

local function currentUI()
    return require("apps/reader/readerui").instance or require("apps/filemanager/filemanager").instance
end

local function broadcast(name, ...)
    UIManager:broadcastEvent(Event:new(name, ...))
end

local function devMode()
    return (G_reader_settings:readSetting("kobo_devmode_until") or 0) > os.time()
end

--- Is this gesture the swipe down from the top edge that opens the menu?
function DeviceMenu.isTopSwipe(ges)
    return ges and ges.ges == "swipe" and ges.direction == "south"
        and ges.pos and ges.pos.y <= Screen:getHeight() * DeviceMenu.TOP_ZONE
end

-- "Notan · 14:42 · 82%"
local function label(title)
    local parts = { title or _("Kobo") }
    table.insert(parts, require("datetime").secondsToHour(os.time(),
        G_reader_settings:isTrue("twelve_hour_clock")))
    if Device:hasBattery() then
        local powerd = Device:getPowerDevice()
        table.insert(parts, powerd:getCapacity() .. "%" .. (powerd:isCharging() and " +" or ""))
    end
    return table.concat(parts, " · ")
end

function DeviceMenu.items(opts)
    local ui = currentUI()
    local items = {}
    for __, it in ipairs(opts.items or {}) do table.insert(items, it) end
    if #items > 0 then items[#items].separator = true end

    if Device:hasFrontlight() then
        table.insert(items, {
            text = _("Light"),
            checked_func = function() return Device:getPowerDevice():isFrontlightOn() end,
            callback = function() broadcast("ToggleFrontlight") end,
            hold_callback = function() broadcast("ShowFlDialog") end,
        })
        table.insert(items, {
            text = _("Brightness and warmth…"),
            callback = function() broadcast("ShowFlDialog") end,
        })
    end
    table.insert(items, {
        text = _("Night mode"),
        checked_func = function() return G_reader_settings:isTrue("night_mode") end,
        callback = function() broadcast("ToggleNightMode") end,
        separator = true,
    })

    if Device:hasWifiToggle() then
        table.insert(items, {
            text = _("Wi-Fi"),
            checked_func = function() return NetworkMgr:isWifiOn() end,
            callback = function()
                if NetworkMgr:isWifiOn() then NetworkMgr:toggleWifiOff() else NetworkMgr:toggleWifiOn() end
            end,
        })
    end
    if ui and ui.tailscale then
        table.insert(items, {
            text = _("Network panel…"),
            callback = function() broadcast("ShowNetworkPanel") end,
        })
    end
    if ui and ui.kobohub then
        table.insert(items, {
            text = _("Check KoboHub now"),
            callback = function() broadcast("KoboHubCheckNow") end,
        })
    end
    if ui and ui.mykobo then
        table.insert(items, {
            text_func = function()
                if devMode() then
                    return T(_("Dev mode (until %1)"),
                        os.date("%H:%M", G_reader_settings:readSetting("kobo_devmode_until")))
                end
                return _("Dev mode")
            end,
            checked_func = devMode,
            callback = function() broadcast("ToggleDevMode") end,
        })
    end
    items[#items].separator = true

    if ui and ui.launcher and opts.close_app then
        table.insert(items, {
            text = _("Home"),
            callback = function()
                opts.close_app()
                broadcast("LauncherShow")
            end,
        })
    end
    if Device:canSuspend() then
        table.insert(items, {
            text = _("Sleep"),
            callback = function() UIManager:nextTick(function() UIManager:suspend() end) end,
        })
    end
    if Device:canRestart() then
        table.insert(items, {
            text = _("Restart KOReader"),
            callback = function() broadcast("Restart") end,
        })
    end
    if Device:canReboot() then
        table.insert(items, {
            text = _("Reboot"),
            keep_menu_open = true, -- the question comes over the menu; No goes back to it
            callback = function() UIManager:askForReboot() end,
        })
    end
    if Device:canPowerOff() then
        table.insert(items, {
            text = _("Shut down"),
            keep_menu_open = true,
            callback = function() UIManager:askForPowerOff() end,
        })
    end
    if Device:isKobo() then
        table.insert(items, {
            text = _("Leave KOReader for the Kobo software"),
            callback = function()
                UIManager:show(ConfirmBox:new{
                    text = _("Leave KOReader and go back to the Kobo software?"),
                    ok_text = _("Leave"),
                    ok_callback = function() broadcast("Exit") end,
                })
            end,
        })
    end
    return items
end

--- Show the menu. opts: title, items (the app's own), close_app.
function DeviceMenu.show(opts)
    opts = opts or {}
    local TouchMenu = require("ui/widget/touchmenu")
    local container = CenterContainer:new{ ignore = "height", dimen = Screen:getSize() }
    local tab = DeviceMenu.items(opts)
    tab.icon = "appbar.menu"
    tab.label_func = function() return label(opts.title) end
    local menu = TouchMenu:new{
        width = Screen:getWidth(),
        tab_item_table = { tab },
        show_parent = container,
    }
    menu.close_callback = function()
        UIManager:close(container)
        if opts.on_close then opts.on_close() end
    end
    container[1] = menu
    UIManager:show(container, "ui") -- (with no refresh type the e-ink screen may not change)
    return container
end

return DeviceMenu
