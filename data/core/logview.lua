local core = require "core"
local style = require "core.style"
local View = require "core.view"
local utils   = require("lua.utils")

local LogView = {}


function LogView:new()
  local new_logview = utils.deepcopy(LogView)
  new_logview.view = View:new()
  new_logview.last_item = core.log_items[#core.log_items]
  new_logview.scrollable = true
  new_logview.yoffset = 0
  return new_logview
end


function LogView:get_name()
  return "Log"
end


function LogView:update()
  local item = core.log_items[#core.log_items]
  if self.last_item ~= item then
    self.last_item = item
    self.scroll.to.y = 0
    self.yoffset = -(style.font:get_height() + style.padding.y)
  end

  self.view:move_towards("yoffset", 0)

  self.view:update()
end


local function draw_text_multiline(font, text, x, y, color)
  local th = font:get_height()
  local resx, resy = x, y
  for line in text:gmatch("[^\n]+") do
    resy = y
    resx = renderer.draw_text(style.font, line, x, y, color)
    y = y + th
  end
  return resx, resy
end


function LogView:draw()
  self.view:draw_background(style.background)

  local ox, oy = self.view:get_content_offset()
  local th = style.font:get_height()
  local y = oy + style.padding.y + self.yoffset

  for i = #core.log_items, 1, -1 do
    local x = ox + style.padding.x
    local item = core.log_items[i]
    local time = os.date(nil, item.time)
    x = renderer.draw_text(style.font, time, x, y, style.dim)
    x = x + style.padding.x
    local subx = x
    x, y = draw_text_multiline(style.font, item.text, x, y, style.text)
    renderer.draw_text(style.font, " at " .. item.at, x, y, style.dim)
    y = y + th
    if item.info then
      subx, y = draw_text_multiline(style.font, item.info, subx, y, style.dim)
      y = y + th
    end
    y = y + style.padding.y
  end
end


return LogView
