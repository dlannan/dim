local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local style = require "core.style"
local keymap = require "core.keymap"
local View = require "core.view"
local utils   = require("lua.utils")

local PanelsView = {

  width       = 280,
  visible     = true,
  separator   = "      ",
  separator2  = "   |   ",

  id          = 2,
  name        = "panels",
  icon        = nil,
  module      = "panels",
  config      = {},
  split_dir   = "down",
  split_node  = "Workspaces",
  locked      = {},
  nofocus     = true,
  resizable   = true,
  command     = nil,
}

PanelsView.max_width = PanelsView.width


function PanelsView:new()
  local new_panelsview = utils.deepcopy(PanelsView)
  new_panelsview.view = View:new()
  new_panelsview.view.scrollable  = true
  new_panelsview.visible          = true
  new_panelsview.init_size        = true

  return new_panelsview
end

function PanelsView:get_scrollable_size()
    return self.view.get_scrollable_size(self)
end

function PanelsView:get_name()
    return "Panels"
end

function PanelsView:on_mouse_pressed(...)
  -- core.root_view:set_focus_view()
  self.view:on_mouse_pressed(...)
end

function PanelsView:on_mouse_released(...)
  self.view:on_mouse_released(...)
end

function PanelsView:on_mouse_moved(...)
  self.view:on_mouse_moved(...)
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
