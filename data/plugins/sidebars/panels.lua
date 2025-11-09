local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local style = require "core.style"
local DocView = require "core.docview"
local LogView = require "core.logview"
local View = require "core.view"

local PanelsView = View:extend()

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
  self.header = config.title or ""
  self.size.x = 200
  self.size.y = style.font:get_height()
end

function View:get_scrollable_size()
    return style.font:get_height()
  end

function PanelsView:get_name()
    return "Panels"
end

function PanelsView:update()
  self.size.x = 200
  self.size.y = style.font:get_height() + style.padding.y * 2
  PanelsView.super.update(self)
end

function PanelsView:draw()
    self:draw_background(style.background)
    local w, h = draw_text(0, 0, { 0, 0, 0, 0 })
    local x = self.position.x + style.padding.x
    local y = self.position.y + style.padding.y
    draw_text(x, y, style.dim)
end

return PanelsView
