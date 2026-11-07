--[[--
The device menu: one drop-down for the whole Kobo system (Home, Books,
Notan, Chess, Solitaire… and KOReader's own Menu tab), so the light, Wi-Fi,
sleep and the rest are the same everywhere. It looks like KOReader's top
menu (a TouchMenu with one tab) and opens with a swipe down from the top
edge.

Order (most used first, the drastic ones last):

    the app's own items
    Light (hold: brightness and warmth) · Night mode
    Wi-Fi · Network… · Check KoboHub · Dev mode
    Home · Go to Kobo
    Sleep · Restart KOReader · Restart Kobo · Shut down Kobo

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

KOReader's Menu tab shows the same items: mykobo registers them as menu
items "kobo_<key>" (DeviceMenu.entries) and the fork's menu order files
place them.

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

-- The left edge, where a drag up or down sets the light (as in the Reader).
DeviceMenu.LEFT_EDGE = 1 / 8

--[[--
The light by a drag, the same in every app as in the Reader: one finger up
or down along the left edge, or two fingers up or down anywhere. KOReader's
own handlers do the work (DeviceListener ChangeFlIntensity). True if handled.
--]]
function DeviceMenu.lightGesture(ges)
    if not (ges and Device:hasFrontlight()) then return false end
    local dir = ges.direction
    if dir ~= "north" and dir ~= "south" then return false end
    local edge = ges.ges == "swipe" and ges.pos and ges.pos.x <= Screen:getWidth() * DeviceMenu.LEFT_EDGE
    if edge or ges.ges == "two_finger_swipe" then
        broadcast("ChangeFlIntensity", ges, dir == "north" and 1 or -1)
        return true
    end
    return false
end

--[[--
For an app's swipe handler: the device menu (a swipe down from the top edge)
or the light (see lightGesture). opts as for show(). True if handled.
--]]
function DeviceMenu.handleSwipe(ges, opts)
    if DeviceMenu.isTopSwipe(ges) then
        DeviceMenu.show(opts)
        return true
    end
    return DeviceMenu.lightGesture(ges)
end

--[[--
Auto-rotate, for an app in front: KOReader sends the accelerometer's turn
(SetRotationMode) only to the window in front, so each app passes it here
and then lays itself out again. portrait_only: only upright <-> upside down
(an app laid out for portrait). True if the screen turned.
--]]
function DeviceMenu.followRotation(mode, portrait_only)
    if type(mode) ~= "number" or mode == Screen:getRotationMode() then return false end
    if portrait_only and bit.band(mode, 1) ~= bit.band(Screen:getRotationMode(), 1) then return false end
    local ui = currentUI()
    if ui then
        ui:handleEvent(Event:new("SetRotationMode", mode))
    else
        Screen:setRotationMode(mode)
    end
    return true
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

--[[--
The standard entries, in order: { key = "light", item = {...} } or
{ separator = true }. Entries the device or the installed plugins cannot do
are left out. opts.close_app: for Home, the app closes first; opts.no_home:
leave Home out (the Launcher itself).
--]]
function DeviceMenu.entries(opts)
    opts = opts or {}
    local ui = opts.ui or currentUI()
    local list = {}
    local function add(key, item) table.insert(list, { key = key, item = item }) end
    local function sep() table.insert(list, { separator = true }) end

    -- Screen
    if Device:hasFrontlight() then
        add("light", {
            text = _("Light"),
            help_text = _("Tap: on or off. Hold: brightness and warmth."),
            checked_func = function() return Device:getPowerDevice():isFrontlightOn() end,
            callback = function() broadcast("ToggleFrontlight") end,
            hold_callback = function(touchmenu)
                if touchmenu and touchmenu.closeMenu then touchmenu:closeMenu() end
                broadcast("ShowFlDialog")
            end,
        })
    end
    add("night_mode", {
        text = _("Night mode"),
        checked_func = function() return G_reader_settings:isTrue("night_mode") end,
        callback = function() broadcast("ToggleNightMode") end,
    })
    sep()

    -- Connections
    if Device:hasWifiToggle() then
        add("wifi", {
            text = _("Wi-Fi"),
            checked_func = function() return NetworkMgr:isWifiOn() end,
            callback = function()
                if NetworkMgr:isWifiOn() then NetworkMgr:toggleWifiOff() else NetworkMgr:toggleWifiOn() end
            end,
        })
    end
    if ui and ui.tailscale then
        add("network", {
            text = _("Network…"),
            callback = function() broadcast("ShowNetworkPanel") end,
        })
    end
    if ui and ui.kobohub then
        add("kobohub", {
            text = _("Check KoboHub"),
            callback = function() broadcast("KoboHubCheckNow") end,
        })
    end
    if ui and ui.mykobo then
        add("dev_mode", {
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
    sep()

    -- Go
    if ui and ui.launcher and not opts.no_home then
        add("home", {
            text = _("Home"),
            callback = function()
                if opts.close_app then opts.close_app() end
                broadcast("LauncherShow")
            end,
        })
    end
    if Device:isKobo() then
        add("go_to_kobo", {
            text = _("Go to Kobo"),
            help_text = _("Leave the Launcher for the Kobo software."),
            keep_menu_open = true,
            callback = function()
                UIManager:show(ConfirmBox:new{
                    text = _("Leave the Launcher and go to the Kobo software?"),
                    ok_text = _("Go to Kobo"),
                    ok_callback = function() broadcast("Exit") end,
                })
            end,
        })
    end
    sep()

    -- Power
    if Device:canSuspend() then
        add("sleep", {
            text = _("Sleep"),
            callback = function() UIManager:nextTick(function() UIManager:suspend() end) end,
        })
    end
    if Device:canRestart() then
        add("restart_koreader", {
            text = _("Restart Launcher"),
            callback = function() broadcast("Restart") end,
        })
    end
    if Device:canReboot() then
        add("restart_kobo", {
            text = _("Restart Kobo"),
            keep_menu_open = true, -- the question comes over the menu; No goes back to it
            callback = function() UIManager:askForReboot() end,
        })
    end
    if Device:canPowerOff() then
        add("shutdown_kobo", {
            text = _("Shut down Kobo"),
            keep_menu_open = true,
            callback = function() UIManager:askForPowerOff() end,
        })
    end
    return list
end

--- The TouchMenu items: the app's own first, then the standard entries.
function DeviceMenu.items(opts)
    opts = opts or {}
    local items = {}
    for __, it in ipairs(opts.items or {}) do table.insert(items, it) end
    if #items > 0 then items[#items].separator = true end
    for __, e in ipairs(DeviceMenu.entries(opts)) do
        if e.separator then
            if #items > 0 then items[#items].separator = true end
        else
            table.insert(items, e.item)
        end
    end
    if #items > 0 then items[#items].separator = nil end
    return items
end

--- Show the menu. opts: title, items (the app's own), close_app, no_home, on_close.
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
