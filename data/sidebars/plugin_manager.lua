local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local style = require "core.style"
local keymap = require "core.keymap"
local View = require "core.view"

local PluginMgrView = View:extend()

PluginMgrView.id = 4
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

return PluginMgrView
