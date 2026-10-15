local _ = require("gettext")

local ui = require("apps/reader/readerui").instance or require("apps/filemanager/filemanager").instance

return {
    text = _("Activate menu"),
    sub_item_table = {
        {
            text = _("With a tap"),
            checked_func = function()
                return G_reader_settings:readSetting("activate_menu") ~= "swipe"
            end,
            callback = function()
                if G_reader_settings:readSetting("activate_menu") ~= "swipe" then
                    G_reader_settings:saveSetting("activate_menu", "swipe")
                else
                    G_reader_settings:saveSetting("activate_menu", "swipe_tap")
                end
                ui.menu.activation_menu = G_reader_settings:readSetting("activate_menu")
            end,
        },
        {
            text = _("With a swipe"),
            checked_func = function()
                return G_reader_settings:readSetting("activate_menu") ~= "tap"
            end,
            callback = function()
                if G_reader_settings:readSetting("activate_menu") ~= "tap" then
                    G_reader_settings:saveSetting("activate_menu", "tap")
                else
                    G_reader_settings:saveSetting("activate_menu", "swipe_tap")
                end
                ui.menu.activation_menu = G_reader_settings:readSetting("activate_menu")
            end,
            separator = true,
        },
        {
            text = _("Auto-show bottom menu"),
            checked_func = function()
                return G_reader_settings:isTrue("show_bottom_menu") -- Kobo fork: off by default
            end,
            callback = function()
                G_reader_settings:flipNilOrFalse("show_bottom_menu")
            end,
        },
    }
}
