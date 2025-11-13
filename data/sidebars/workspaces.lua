local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"

local WorkspacesView = View:extend()

WorkspacesView.id = 1
WorkspacesView.name = "workspaces"
WorkspacesView.icon = ""
WorkspacesView.module = "workspaces"
WorkspacesView.config = {}
WorkspacesView.split_dir = nil
WorkspacesView.split_node = nil
WorkspacesView.command = nil


return WorkspacesView