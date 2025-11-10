local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local style = require "core.style"
local keymap = require "core.keymap"
local View = require "core.view"

local PanelsView = View:extend()

PanelsView.width = 200
PanelsView.max_width = PanelsView.width
PanelsView.visible = true
PanelsView.separator  = "      "
PanelsView.separator2 = "   |   "


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


function PanelsView:new(config)
  PanelsView.super.new(self)
  self.scrollable = true
  self.visible = true
  self.header = config.title or ""
  self.size.x = PanelsView.width
  self.size.y = style.font:get_height()
  self.init_size = true
end

function View:get_scrollable_size()
    return style.font:get_height()
  end

function PanelsView:get_name()
    return "Panels"
end

function PanelsView:on_mouse_pressed(button, x, y)
  core.root_view:set_focus_view()
end

function PanelsView:update()

  self.size.y = style.font:get_height() + style.padding.y * 2

  if(self.init_size == true and self.size.x ~= PanelsView.width) then
    self:move_towards(self.size, "x", PanelsView.width, 0.5, function() 
      self.init_size = false 
    end)
  else 
    -- PanelsView.max_width = self.size.x -- Update for border movement
  end

  PanelsView.super.update(self)
end

function PanelsView:draw()
    self:draw_background(style.background)
    local w, h = draw_text(0, 0, { 0, 0, 0, 0 })
    local x = self.position.x + style.padding.x
    local y = self.position.y + style.padding.y
    draw_text(x, y, style.text)
end

command.add(nil, {
  ["panelsview:toggle"] = function()
    PanelsView.visible = not PanelsView.visible
    PanelsView.width = PanelsView.visible and PanelsView.max_width or 0 
  end,
})

keymap.add { ["ctrl+\\"] = "panelsview:toggle" }


return PanelsView
