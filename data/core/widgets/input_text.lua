
-- Widget for simple text input. Uses the same kinda of input as docview
--   with only 1 line of text entry and display.
-- Registers as "is_docview" so that autocomplete and other filters can be applied if needed.

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local style = require "core.style"
local Doc = require "core.doc"

local utils   = require("lua.utils")

local WidgetInputText = {}

function WidgetInputText:new(default_text)
    local w_inputtext = Doc:new()
    w_inputtext:insert(1, 1, default_text)
    w_inputtext.font = style.widget_font   -- new styles for widgets
    w_inputtext.get_height = WidgetInputText.get_height
    w_inputtext.on_text_input = WidgetInputText.on_text_input
    w_inputtext.update = WidgetInputText.update
    w_inputtext.draw = WidgetInputText.draw
    return w_inputtext
end

function WidgetInputText:get_height()
    return self.font:get_height()
end

function WidgetInputText:on_text_input(text)
    self:text_input(text)
end

function WidgetInputText:update()

end 

function WidgetInputText:draw(x, y, w, color)
    local h = self:get_height() + style.padding.y
    core.push_clip_rect(x, y, w, h)
    renderer.draw_rect(x, y, w, h, style.widget_background)
    w = renderer.draw_text(self.font, self.lines[1], x + style.padding.x, y + style.padding.y, color)
    core.pop_clip_rect()
    return w
end

return WidgetInputText 
