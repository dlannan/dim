local core = require "core"
local style = require "core.style"
local command = require "core.command"
local common = require "core.common"
local config = require "core.config"
local View = require "core.view"
local utils   = require("lua.utils")

config.bigclock_time_format = "%H:%M:%S"
config.bigclock_date_format = "%A, %d %B %Y"
config.bigclock_scale = 1


local ClockView = {}


function ClockView:new()
  local new_clockview = utils.deepcopy(ClockView)
  new_clockview.view = utils.deepcopy(View)
  new_clockview.time_text = ""
  new_clockview.date_text = ""
  return new_clockview
end


function ClockView:get_name()
  return "Big Clock"
end


function ClockView:update_fonts()
  local size = math.floor(self.view.size.x * 0.15 / 15) * 15 * config.bigclock_scale
  if self.font_size ~= size then
    self.time_font = renderer.font.load(EXEDIR .. "/data/fonts/font.ttf", size)
    self.date_font = renderer.font.load(EXEDIR .. "/data/fonts/font.ttf", size * 0.3)
    self.font_size = size
    collectgarbage()
  end
  return self.font
end


function ClockView:update()
  local time_text = os.date(config.bigclock_time_format)
  local date_text = os.date(config.bigclock_date_format)
  if self.time_text ~= time_text or self.date_text ~= date_text then
    core.redraw = true
    self.time_text = time_text
    self.date_text = date_text
  end
  self.view:update()
end


function ClockView:draw()
  self:update_fonts()
  self.view:draw_background(style.background)
  local x, y = self.view.position.x, self.view.position.y
  local w, h = self.view.size.x, self.view.size.y
  local _, y = common.draw_text(self.time_font, style.text, self.time_text, "center", x, y, w, h)
  local th = self.date_font:get_height()
  common.draw_text(self.date_font, style.dim, self.date_text, "center", x, y, w, th)
end


command.add(nil, {
  ["big-clock:open"] = function()
    local node = core.root_view:get_active_node()
    node:add_view(ClockView:new())
  end,
})


return ClockView
