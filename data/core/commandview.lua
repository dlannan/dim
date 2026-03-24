local core = require "core"
local common = require "core.common"
local style = require "core.style"
local Doc = require "core.doc"
local DocView = require "core.docview"
local View = require "core.view"
local utils   = require("lua.utils")


local SingleLineDoc = utils.deepcopy(Doc)

function SingleLineDoc:insert(line, col, text)
  self:insert(line, col, text:gsub("\n", ""))
end

local CommandView = {}

local max_suggestions = 10

local noop = function() end

local default_state = {
  submit = noop,
  suggest = noop,
  cancel = noop,
}


function CommandView:new()
  local new_commandview = utils.deepcopy(CommandView)
  new_commandview.docview = DocView:new(SingleLineDoc:new())
  new_commandview.docview.parent = new_commandview
  new_commandview.doc = new_commandview.docview.doc
  new_commandview.view = new_commandview.docview.view

  new_commandview.suggestion_idx = 1
  new_commandview.suggestions = {}
  new_commandview.suggestions_height = 0
  new_commandview.last_change_id = 0
  new_commandview.gutter_width = 0
  new_commandview.gutter_text_brightness = 0
  new_commandview.selection_offset = 0
  new_commandview.state = default_state
  new_commandview.font = "font"
  new_commandview.view.size.y = 0
  new_commandview.label = ""

  new_commandview.view.get_scrollable_size = function() return 0 end 
  new_commandview.view.scroll_to_make_visible = function() end 
  return new_commandview
end


function CommandView:get_name()
  return "CommandView"
end


function CommandView:get_line_screen_position()
  local x = self.docview:get_line_screen_position(1)
  local _, y = self.view:get_content_offset()
  local lh = self.docview:get_line_height()
  return x, y + (self.view.size.y - lh) / 2
end


function CommandView:get_scrollable_size()
  return 0
end


function CommandView:scroll_to_make_visible()
  -- no-op function to disable this functionality
end


function CommandView:get_text()
  return self.doc:get_text(1, 1, 1, math.huge)
end


function CommandView:set_text(text, select)
  self.doc:remove(1, 1, math.huge, math.huge)
  self.doc:text_input(text)
  if select then
    self.doc:set_selection(math.huge, math.huge, 1, 1)
  end
end


function CommandView:move_suggestion_idx(dir)
  local n = self.suggestion_idx + dir
  self.suggestion_idx = common.clamp(n, 1, #self.suggestions)
  self:complete()
  self.last_change_id = self.doc:get_change_id()
end


function CommandView:complete()
  if #self.suggestions > 0 then
    self:set_text(self.suggestions[self.suggestion_idx].text)
  end
end


function CommandView:submit()
  local suggestion = self.suggestions[self.suggestion_idx]
  local text = self:get_text()
  local submit = self.state.submit
  self:exit(true)
  submit(text, suggestion)
end


function CommandView:enter(text, submit, suggest, cancel)
  if self.state ~= default_state then
    return
  end
  self.state = {
    submit = submit or noop,
    suggest = suggest or noop,
    cancel = cancel or noop,
  }
  core.set_active_view(self)
  self:update_suggestions()
  self.gutter_text_brightness = 100
  self.label = text .. ": "
end


function CommandView:exit(submitted, inexplicit)
  if core.last_active_view and core.active_view == self then
    core.set_active_view(core.last_active_view)
  end
  local cancel = self.state.cancel
  self.state = default_state
  self.doc:reset()
  self.suggestions = {}
  if not submitted then cancel(not inexplicit) end
end


function CommandView:get_gutter_width()
  return self.gutter_width
end


function CommandView:get_suggestion_line_height()
  return self.docview:get_font():get_height() + style.padding.y
end


function CommandView:update_suggestions()
  local t = self.state.suggest(self:get_text()) or {}
  local res = {}
  for i, item in ipairs(t) do
    if i == max_suggestions then
      break
    end
    if type(item) == "string" then
      item = { text = item }
    end
    res[i] = item
  end
  self.suggestions = res
  self.suggestion_idx = 1
end


function CommandView:on_text_input(text)
  self.doc:text_input(text)
end

function CommandView:update()
  self.docview:update()

  if core.active_view ~= self and self.state ~= default_state then
    self:exit(false, true)
  end

  -- update suggestions if text has changed
  if self.last_change_id ~= self.doc:get_change_id() then
    self:update_suggestions()
    self.last_change_id = self.doc:get_change_id()
  end

  -- update gutter text color brightness
  self.view:move_towards(self, "gutter_text_brightness", 0, 0.1)

  -- update gutter width
  local dest = self.docview:get_font():get_width(self.label) + style.padding.x
  if self.view.size.y <= 0 then
    self.gutter_width = dest
  else
    self.view:move_towards(self, "gutter_width", dest)
  end

  -- update suggestions box height
  local lh = self:get_suggestion_line_height()
  local dest = #self.suggestions * lh
  self.view:move_towards(self, "suggestions_height", dest)

  -- update suggestion cursor offset
  local dest = self.suggestion_idx * self:get_suggestion_line_height()
  self.view:move_towards(self, "selection_offset", dest)

  -- update size based on whether this is the active_view
  local dest = 0
  if self == core.active_view then
    dest = style.font:get_height() + style.padding.y * 2
  end
  self.view:move_towards(self.view.size, "y", dest)
end


function CommandView:draw_line_highlight()
  -- no-op function to disable this functionality
end


function CommandView:draw_line_gutter(idx, x, y)
  local yoffset = self:get_line_text_y_offset()
  local pos = self.view.position
  local color = common.lerp(style.text, style.accent, self.gutter_text_brightness / 100)
  core.push_clip_rect(pos.x, pos.y, self:get_gutter_width(), self.size.y)
  x = x + style.padding.x
  renderer.draw_text(self.docview:get_font(), self.label, x, y + yoffset, color)
  core.pop_clip_rect()
end


local function draw_suggestions_box(self)
  local lh = self:get_suggestion_line_height()
  local dh = style.divider_size
  local x, _ = self:get_line_screen_position()
  local h = math.ceil(self.suggestions_height)
  local rx, ry, rw, rh = self.view.position.x, self.view.position.y - h - dh, self.view.size.x, h

  -- draw suggestions background
  if #self.suggestions > 0 then
    renderer.draw_rect(rx, ry, rw, rh, style.background3)
    renderer.draw_rect(rx, ry - dh, rw, dh, style.divider)
    local y = self.view.position.y - self.selection_offset - dh
    renderer.draw_rect(rx, y, rw, lh, style.line_highlight)
  end

  -- draw suggestion text
  core.push_clip_rect(rx, ry, rw, rh)
  for i, item in ipairs(self.suggestions) do
    local color = (i == self.suggestion_idx) and style.accent or style.text
    local y = self.view.position.y - i * lh - dh
    common.draw_text(self.docview:get_font(), color, item.text, nil, x, y, 0, lh)

    if item.info then
      local w = self.view.size.x - x - style.padding.x
      common.draw_text(self.docview:get_font(), style.dim, item.info, "right", x, y, w, lh)
    end
  end
  core.pop_clip_rect()
end


function CommandView:draw()
  self.docview:draw()
  core.root_view:defer_draw(draw_suggestions_box, self)
end


return CommandView
