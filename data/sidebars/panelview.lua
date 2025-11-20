local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local style = require "core.style"
local keymap = require "core.keymap"
local View = require "core.view"
local utils   = require("lua.utils")

local PanelsView = {}

PanelsView.width = 200
PanelsView.max_width = PanelsView.width
PanelsView.visible = true
PanelsView.separator  = "      "
PanelsView.separator2 = "   |   "

PanelsView.id = 2
PanelsView.name = "panels"
PanelsView.icon = nil
PanelsView.module = "panels"
PanelsView.config = {}
PanelsView.split_dir = "down"
PanelsView.split_node = "Workspaces"
PanelsView.locked = true
PanelsView.command = nil


-- Taken from Rootview - used for EmptyView
local function draw_text(x, y, color)
    local th = style.font:get_height()
    local dh = th + style.padding.y * 2
    local w = 0

    local line = { fmt = "[%s] ", text = config.project_path }
    local text = string.format(line.fmt, line.text)
    w = renderer.draw_text(style.font, text, x + style.padding.x, y, color)
    return w, dh
end


function PanelsView:new()
  local new_panelsview = utils.deepcopy(PanelsView)
  new_panelsview.view = View:new()
  new_panelsview.view.scrollable = true
  new_panelsview.visible = true
  new_panelsview.init_size = true

  return new_panelsview
end

function PanelsView:get_scrollable_size()
    return self.view.get_scrollable_size(self)
end

function PanelsView:get_name()
    return "Panels"
end

function PanelsView:on_mouse_pressed(button, x, y)
  core.root_view:set_focus_view()
end

function PanelsView:update()

  if(self.init_size == true and self.view.size.x ~= PanelsView.width) then
    self.view:move_towards(self.view.size, "x", PanelsView.width, 0.5, function() 
      self.init_size = false 
    end)
  else 
    -- PanelsView.max_width = self.size.x -- Update for border movement
  end

  self.view:update()
end

function PanelsView:draw()
    self.view:draw_background(style.background)
end


return PanelsView
