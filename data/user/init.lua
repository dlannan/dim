-- put user settings here
-- this module will be loaded after everything else when the application starts
local core = require "core"
local command = require "core.command"

local keymap = require "core.keymap"
local config = require "core.config"
local style = require "core.style"

-- my own vscode theme
style = require("data.user.colors.vscode_dark")
config.indent_size = 4
-- config.project_path = "F:\\dev\\luajit\\LuaJIT"
config.project_path = "."

-- key binding:
-- keymap.add { ["ctrl+escape"] = "core:quit" }

command.add(nil, {
    ["style:reload"] = function()
      package.loaded["core.style"] = nil
      local style = require "core.style"
      core.redraw = true
      core.log("✅ Style reloaded.")
    end
})