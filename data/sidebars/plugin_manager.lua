local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local style = require "core.style"
local keymap = require "core.keymap"
local View = require "core.view"
local utils   = require("lua.utils")

local PluginMgrView = {

    id = 5,
    name = "plugin-manager",
    icon = "",
    module = "plugin_manager",
    config = {},
    split_dir = "down",
    split_node = "Panels",
    locked = "Y",
    command = nil,
}

function PluginMgrView:new()
    local new_pluginmgrview = utils.deepcopy(PluginMgrView)
    new_pluginmgrview.view = View:new()
    new_pluginmgrview.view.scrollable = true
    new_pluginmgrview.visible = false
    new_pluginmgrview.init_size = true
    return new_pluginmgrview
end

function PluginMgrView:get_name()
    return "PluginMgr"
end

function PluginMgrView:get_item_height()
    if(self.visible == false) then return 0 end
    return style.font:get_height() + style.padding.y
end

function PluginMgrView:update()
    if(self.visible == false) then 
        self.view.size.y = 0
        return 
    end
    self.view.size.y = style.font:get_height() + style.padding.y * 2
    self.view:update()
end

function PluginMgrView:draw()
    if(self.visible == false) then return end
    self.view:draw_background(style.background)
end


return PluginMgrView
