local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local style = require "core.style"
local keymap = require "core.keymap"
local View = require "core.view"

local PluginMgrView = View:extend()

PluginMgrView.id = 5
PluginMgrView.name = "plugin-manager"
PluginMgrView.icon = ""
PluginMgrView.module = "plugin_manager"
PluginMgrView.config = {}
PluginMgrView.split_dir = "down"
PluginMgrView.split_node = "Panels"
PluginMgrView.command = nil

function PluginMgrView:new()
    PluginMgrView.super.new(self)
    self.scrollable = true
    self.visible = false
    self.init_size = true
end

function PluginMgrView:update()
    if(self.visible == false) then return end
    self.size.y = style.font:get_height() + style.padding.y * 2
    PluginMgrView.super.update(self)
end

function PluginMgrView:draw()
    if(self.visible == false) then return end
    self:draw_background(style.background)
end


return PluginMgrView
