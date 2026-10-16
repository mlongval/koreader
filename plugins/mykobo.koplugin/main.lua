--[[--
My Kobo (Kobo fork of KOReader).

Dev mode: while on, the Kobo does not go to sleep by itself and Wi-Fi is
kept on (for SSH, installs, long jobs). It switches itself off after 3
hours, so a forgotten switch can't drain the battery. Outside Dev mode,
Wi-Fi is turned off after 10 minutes without use.

"Use" is measured on the Wi-Fi interface: a minute with more than a
little traffic counts as used (a single translation is too small to
show; a tap after Wi-Fi went off just brings it back). Tailscale's
keep-alives stay under the threshold, and minutes in which KoboHub is checked in the background
(kobohub_client busy) don't count either way, so the automatic checks
don't keep Wi-Fi on.

First run (once): turns off the speed-reading plugin, and puts the quick
menu on a long-press of the top-left corner (if nothing is there yet).

Books folder (once, in the file browser): the books at the top of the home
folder move into Books/, the way the file browser's own Cut and Paste moves
them (reading positions, history, collections), and downloads (OPDS,
KoboHub's Calibre) go to Books/ from then on.

@module koplugin.mykobo
--]]--

local DataStorage = require("datastorage")
local Device = require("device")
local Dispatcher = require("dispatcher")
local DocSettings = require("docsettings")
local DocumentRegistry = require("document/documentregistry")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local NetworkMgr = require("ui/network/manager")
local PluginShare = require("pluginshare")
local ReadCollection = require("readcollection")
local ReadHistory = require("readhistory")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

local DEV_HOURS = 3
local WIFI_IDLE = 10 * 60      -- seconds without use before Wi-Fi goes off
-- Sent per minute: more than this is use. Measured on the Elipsa
-- (2026-10-14), Tailscale alone sends about 20 KB a minute.
local USE_BYTES = 60 * 1024
local UNTIL = "kobo_devmode_until"

local QUICK_MENU = {
    "toggle_frontlight",
    "show_network_panel",
    "toggle_dev_mode",
    "learnmode_sidebyside",
    "learnmode_toggle",
    "kobohub_check_now",
    "readiteventually_mark_read",
    "toggle_rotation",
    "menu_search",
}

-- Shared by the reader's and the file browser's instances.
local state = { end_task = nil, idle_task = nil, applied = false,
                last_bytes = nil, last_use = os.time() }

local function toast(text, timeout)
    UIManager:show(InfoMessage:new{ text = text, timeout = timeout or 3 })
end

local function devUntil()
    return G_reader_settings:readSetting(UNTIL) or 0
end

local function devOn()
    return devUntil() > os.time()
end

local function txBytes()
    local name = NetworkMgr.getNetworkInterfaceName and NetworkMgr:getNetworkInterfaceName()
    if not name then return nil end
    local f = io.open("/sys/class/net/" .. name .. "/statistics/tx_bytes", "rb")
    if not f then return nil end
    local n = f:read("*number")
    f:close()
    return n
end

local function backgroundBusy()
    local ok, Client = pcall(require, "kobohub_client")
    return ok and (Client.busy or 0) > 0
end

-- Every minute while Wi-Fi is on: note use; turn Wi-Fi off when idle.
local function idleCheck()
    state.idle_task = nil
    if not NetworkMgr:isWifiOn() then
        state.last_bytes = nil
        return
    end
    local now = os.time()
    local bytes = txBytes()
    if bytes and state.last_bytes and not backgroundBusy()
            and bytes - state.last_bytes > USE_BYTES then
        state.last_use = now
    end
    state.last_bytes = bytes
    if devOn() then state.last_use = now end
    if now - state.last_use >= WIFI_IDLE then
        logger.info("mykobo: Wi-Fi unused for", now - state.last_use, "s; turning it off")
        NetworkMgr:disableWifi(nil, false)
        return
    end
    state.idle_task = idleCheck
    UIManager:scheduleIn(60, idleCheck)
end

local function startIdleCheck()
    state.last_use = os.time()
    state.last_bytes = txBytes()
    if state.idle_task then UIManager:unschedule(state.idle_task) end
    state.idle_task = idleCheck
    UIManager:scheduleIn(60, idleCheck)
end

local devOff

-- Make the current Dev mode setting take effect (on start, and on toggle).
local function applyDev()
    if state.end_task then UIManager:unschedule(state.end_task) end
    state.end_task = nil
    if devOn() then
        PluginShare.pause_auto_suspend = true
        if not state.applied then UIManager:preventStandby() end
        state.applied = true
        state.end_task = function() devOff(true) end
        UIManager:scheduleIn(devUntil() - os.time(), state.end_task)
    else
        PluginShare.pause_auto_suspend = false
        if state.applied then UIManager:allowStandby() end
        state.applied = false
    end
end

local function devOnNow(ui)
    G_reader_settings:saveSetting(UNTIL, os.time() + DEV_HOURS * 3600)
    G_reader_settings:flush()
    applyDev()
    if not NetworkMgr:isWifiOn() then NetworkMgr:enableWifi(nil, false) end
    local ssh = ui and ui.SSH
    if ssh and ssh.isRunning and not ssh:isRunning() and ssh.start then
        pcall(ssh.start, ssh)
    end
    toast(T(_("Dev mode on until %1: no sleep, Wi-Fi stays on."),
        os.date("%H:%M", devUntil())))
end

devOff = function(timed_out)
    G_reader_settings:delSetting(UNTIL)
    G_reader_settings:flush()
    applyDev()
    startIdleCheck()
    toast(timed_out and _("Dev mode ended (3 hours). Back to saving battery.")
        or _("Dev mode off: back to saving battery."))
end

-- Once: the settings the menu redesign decided on.
local function firstRun(ui)
    if G_reader_settings:readSetting("kobo_fork_setup") then return end
    local disabled = G_reader_settings:readSetting("plugins_disabled") or {}
    disabled.perceptionexpander = true
    G_reader_settings:saveSetting("plugins_disabled", disabled)

    local path = DataStorage:getSettingsDir() .. "/gestures.lua"
    local file = LuaSettings:open(path)
    local live = ui.gestures and ui.gestures.settings_data
    local data = live and live.data or file.data
    data.gesture_reader = data.gesture_reader or {}
    local ges = data.gesture_reader
    if ges.hold_top_left_corner == nil or next(ges.hold_top_left_corner) == nil then
        local actions = { settings = { show_as_quickmenu = true, order = {} } }
        for _, a in ipairs(QUICK_MENU) do
            actions[a] = true
            table.insert(actions.settings.order, a)
        end
        ges.hold_top_left_corner = actions
        if live then
            ui.gestures.updated = true
            live:flush()
        else
            file.data = data
            file:flush()
        end
        logger.info("mykobo: quick menu put on hold top-left corner")
    else
        logger.warn("mykobo: hold top-left corner already used; quick menu not set")
    end
    G_reader_settings:saveSetting("kobo_fork_setup", 1)
    G_reader_settings:flush()
end

-- Once, in the file browser: the books at the top of home move into Books/.
local function booksFolder(ui)
    if G_reader_settings:readSetting("kobo_books_folder") or not ui.file_chooser then return end
    local home = G_reader_settings:readSetting("home_dir") or Device.home_dir
    if not home or lfs.attributes(home, "mode") ~= "directory" then return end
    local books = home .. "/Books"
    util.makePath(books)
    local moved, n = {}, 0
    local lastfile = G_reader_settings:readSetting("lastfile")
    for f in lfs.dir(home) do
        local path = home .. "/" .. f
        local new_path = books .. "/" .. f
        if f:sub(1, 1) ~= "." and lfs.attributes(path, "mode") == "file"
                and ui.file_chooser:show_file(f) and DocumentRegistry:hasProvider(path)
                and not lfs.attributes(new_path, "mode") then
            if os.rename(path, new_path) then
                DocSettings.updateLocation(path, new_path)
                moved[path] = true
                n = n + 1
                if lastfile == path then
                    G_reader_settings:saveSetting("lastfile", new_path)
                end
            else
                logger.warn("mykobo: could not move", path)
            end
        end
    end
    if n > 0 then
        ReadHistory:updateItems(moved, books)
        ReadCollection:updateItems(moved, books)
    end
    if not G_reader_settings:readSetting("download_dir") then
        G_reader_settings:saveSetting("download_dir", books)
    end
    G_reader_settings:saveSetting("kobo_books_folder", 1)
    G_reader_settings:flush()
    logger.info("mykobo: moved", n, "books into", books)
    ui.file_chooser:refreshPath()
    toast(T(_("%1 books moved into the Books folder."), n), 4)
end

local MyKobo = WidgetContainer:extend{
    name = "mykobo",
    is_doc_only = false,
}

-- The Wi-Fi icon in the top bar (crengine's Alt status bar), right of the
-- clock: the footer's icons, from the Nerd symbols font (a crengine
-- fallback font in this fork, see CreDocument.fallback_fonts).
local function wifiHeader()
    return NetworkMgr:isWifiOn() and "\u{ECA8}" or "\u{ECA9}"
end

function MyKobo:refreshHeader()
    local cre = self.ui.crelistener
    if cre then
        cre:updatePageInfoOverride()
        cre:updateHeader()
    end
end

function MyKobo:init()
    if self.ui.crelistener then
        self.ui.crelistener:addAdditionalHeaderContent(wifiHeader)
    end
    Dispatcher:registerAction("toggle_dev_mode", {
        category = "none", event = "ToggleDevMode", title = _("Dev mode on/off"), general = true,
    })
    self.ui.menu:registerToMainMenu(self)
    UIManager:nextTick(function()
        firstRun(self.ui)
        booksFolder(self.ui)
        applyDev()
        if NetworkMgr:isWifiOn() and not state.idle_task then startIdleCheck() end
    end)
end

function MyKobo:onNetworkConnected()
    startIdleCheck()
    self:refreshHeader()
end

function MyKobo:onNetworkDisconnected()
    if state.idle_task then UIManager:unschedule(state.idle_task) end
    state.idle_task = nil
    self:refreshHeader()
end

function MyKobo:onResume()
    -- the timer may have run out while asleep
    if state.applied and not devOn() then devOff(true) end
end

function MyKobo:onToggleDevMode()
    if devOn() then devOff(false) else devOnNow(self.ui) end
    return true
end

function MyKobo:addToMainMenu(menu_items)
    menu_items.dev_mode = {
        text_func = function()
            if devOn() then
                return T(_("Dev mode (until %1)"), os.date("%H:%M", devUntil()))
            end
            return _("Dev mode")
        end,
        help_text = T(_("No sleep and Wi-Fi kept on, for %1 hours. Otherwise the Kobo sleeps after its usual delay and Wi-Fi goes off after 10 minutes unused."), DEV_HOURS),
        checked_func = devOn,
        callback = function(touchmenu_instance)
            self:onToggleDevMode()
            touchmenu_instance:updateItems()
        end,
    }
end

return MyKobo
