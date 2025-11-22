local core = require "core"
local common = require "core.common"
local style = require "core.style"
local keymap = require "core.keymap"
local View = require "core.view"
local DocView = require "core.docview"
local utils   = require("lua.utils")

local EmptyView = {}

function EmptyView:new()
    local new_emptyview = utils.deepcopy(EmptyView)
    new_emptyview.view = View:new()
    new_emptyview.is_empty = true
    return new_emptyview
end

local function draw_text(x, y, color)
  local th = style.big_font:get_height()
  local dh = th + style.padding.y * 2
  local wd = x

  x = renderer.draw_text(style.big_font, "dim", x, y + (dh - th) / 2, color)
  x = x + style.padding.x
  renderer.draw_rect(x, y, math.ceil(1 * SCALE), dh, color)
  renderer.draw_text(style.font, "not so lite", wd, y + (dh - th) / 2 + style.big_font:get_height(), color)

  renderer.draw_rect(x, y, math.ceil(1 * SCALE), dh * 1.5, color)
  local lines = {
    { fmt = "%s to run a command", cmd = "core:find-command" },
    { fmt = "%s to open a file from the project", cmd = "core:find-file" },
  }
  th = style.font:get_height()
  y = y + (dh - th * 2 - style.padding.y) / 2
  local w = 0
  for _, line in ipairs(lines) do
    local text = string.format(line.fmt, keymap.get_binding(line.cmd))
    w = math.max(w, renderer.draw_text(style.font, text, x + style.padding.x, y, color))
    y = y + th + style.padding.y
  end
  return w, dh
end

function EmptyView:draw()
  self.view:draw_background(style.background)
  local w, h = draw_text(0, 0, { 0, 0, 0, 0 })
  local x = self.view.position.x + math.max(style.padding.x, (self.view.size.x - w) / 2)
  local y = self.view.position.y + (self.view.size.y - h) / 2
  draw_text(x, y, style.dim)
end

local Node = {
    type = "leaf",
    position = { x = 0, y = 0 },
    size = { x = 0, y = 0 },
    views = {},
    divider = 0.5,
}

function Node:new(node_type)
    local new_node = utils.deepcopy(Node)
    new_node.type = node_type or "leaf"
    if new_node.type == "leaf" then
        new_node:add_view(EmptyView:new())
    end
    return new_node
end


function Node:propagate(fn, ...)
  self.a[fn](self.a, ...)
  self.b[fn](self.b, ...)
end


function Node:on_mouse_moved(x, y, ...)
  self.hovered_tab = self:get_tab_overlapping_point(x, y)
  if self.type == "leaf" then
    local ok = self.active_view.on_mouse_moved and self.active_view:on_mouse_moved(x, y, ...)
  else
    self:propagate("on_mouse_moved", x, y, ...)
  end
end


function Node:on_mouse_released(...)
  if self.type == "leaf" then
    local ok = self.active_view.on_mouse_released and self.active_view:on_mouse_released(...)
  else
    self:propagate("on_mouse_released", ...)
  end
end


function Node:consume(node)
  for k, _ in pairs(self) do self[k] = nil end
  for k, v in pairs(node) do self[k] = v   end
end


local type_map = { up="vsplit", down="vsplit", left="hsplit", right="hsplit" }
-- locked can be: "X" or "Y" or ("B" or true) - X = horizontal lock, Y = vertical lock, B = horiz and vert locked
function Node:split(dir, view, locked)
  assert(self.type == "leaf", "Tried to split non-leaf node")
  local node_type = assert(type_map[dir], "Invalid direction")
  local last_active = core.active_view
  local child = Node:new()
  child:consume(self)
  self:consume(Node:new(node_type))
  self.a = child
  self.b = Node:new()
  if view then
    view._is_locked = locked -- dodgy "prelock lock!"
    self.b:add_view(view)
  end
  if locked then
    self.b.locked = locked
    core.set_active_view(last_active)
  end

--   self.divider = 0.1 
  if dir == "up" or dir == "left" then
    self.a, self.b = self.b, self.a
    return self.a
  end
  return self.b
end


function Node:close_active_view(root)
  local do_close = function()
    if #self.views > 1 then
      local idx = self:get_view_idx(self.active_view)
      table.remove(self.views, idx)
      self:set_active_view(self.views[idx] or self.views[#self.views])
    else
      local parent = self:get_parent_node(root)
      local is_a = (parent.a == self)
      local other = parent[is_a and "b" or "a"]
      if other:get_locked_size() then
        self.views = {}
        self:add_view(EmptyView:new())
      else
        parent:consume(other)
        local p = parent
        while p.type ~= "leaf" do
          p = p[is_a and "a" or "b"]
        end
        p:set_active_view(p.active_view)
      end
    end
    core.last_active_view = nil
  end
  self.active_view.view:try_close(do_close)
end

-- TODO: This should support partial locked views
function Node:add_view(view)
  assert(self.type == "leaf", "Tried to add view to non-leaf node")
  assert(not self.locked, "Tried to add view to locked node")
  if self.views[1] and self.views[1].is_empty then
    table.remove(self.views)
  end
  table.insert(self.views, view)
  self:set_active_view(view)
end


function Node:set_active_view(view)
  assert(self.type == "leaf", "Tried to set active view on non-leaf node")
  self.active_view = view
  core.set_active_view(view, self)
end


function Node:get_view_idx(view)
  for i, v in ipairs(self.views) do
    if v == view then return i end
  end
end


function Node:get_node_for_view(view)
  for _, v in ipairs(self.views) do
    if v == view then return self end
  end
  if self.type ~= "leaf" then
    return self.a:get_node_for_view(view) or self.b:get_node_for_view(view)
  end
end

function Node:get_named_node(name)
  for _, v in ipairs(self.views) do
    local vname = v.get_name and v:get_name() or nil
    if vname == name then return self end
  end
  if self.type ~= "leaf" then
    return self.a:get_named_node(name) or self.b:get_named_node(name)
  end
end

function Node:get_parent_node(root)
  if root.a == self or root.b == self then
    return root
  elseif root.type ~= "leaf" then
    return self:get_parent_node(root.a) or self:get_parent_node(root.b)
  end
end


function Node:get_children(t)
  t = t or {}
  for _, view in ipairs(self.views) do
    table.insert(t, view)
  end
  if self.a then self.a:get_children(t) end
  if self.b then self.b:get_children(t) end
  return t
end


function Node:get_divider_overlapping_point(px, py)
  if self.type ~= "leaf" then
    local p = 6
    local x, y, w, h = self:get_divider_rect()
    x, y = x - p, y - p
    w, h = w + p * 2, h + p * 2
    if px > x and py > y and px < x + w and py < y + h then
      return self
    end
    return self.a:get_divider_overlapping_point(px, py)
        or self.b:get_divider_overlapping_point(px, py)
  end
end


function Node:get_tab_overlapping_point(px, py)
  if #self.views == 1 then return nil end
  local x, y, w, h = self:get_tab_rect(1)
  if px >= x and py >= y and px < x + w * #self.views and py < y + h then
    return math.floor((px - x) / w) + 1
  end
end


function Node:get_child_overlapping_point(x, y)
  local child
  if self.type == "leaf" then
    return self
  elseif self.type == "hsplit" then
    child = (x < self.b.position.x) and self.a or self.b
  elseif self.type == "vsplit" then
    child = (y < self.b.position.y) and self.a or self.b
  end
  return child:get_child_overlapping_point(x, y)
end


function Node:get_tab_rect(idx)
  local tw = math.min(style.tab_width, math.ceil(self.size.x / #self.views))
  local h = style.font:get_height() + style.padding.y * 2
  return self.position.x + (idx-1) * tw, self.position.y, tw, h
end


function Node:get_divider_rect()
  local x, y = self.position.x, self.position.y
  if self.type == "hsplit" then
    return x + self.a.size.x, y, style.divider_size, self.size.y
  elseif self.type == "vsplit" then
    return x, y + self.a.size.y, self.size.x, style.divider_size
  end
end

function Node:get_locked_size()
    if self.type == "leaf" then
        if self.locked then
        local size = self.active_view.view.size
        if(self.locked == "X") then size.y = nil end
        if(self.locked == "Y") then size.x = nil end
        return size.x, size.y
        end
    else
        local x1, y1 = self.a:get_locked_size()
        local x2, y2 = self.b:get_locked_size()
        if x1 and x2 and self.type == "hsplit" then
            local dsx = (x1 < 1 or x2 < 1) and 0 or style.divider_size
            return x1 + x2 + dsx, y1 or y2
        elseif y1 and y2 and self.type == "vsplit" then
            local dsy = (y1 < 1 or y2 < 1) and 0 or style.divider_size
            return x1 or x2, y1 + y2 + dsy
        end
    end
end


local function copy_position_and_size(dst, src)
  dst.position.x, dst.position.y = src.position.x, src.position.y
  dst.size.x, dst.size.y = src.size.x, src.size.y
end


-- calculating the sizes is the same for hsplits and vsplits, except the x/y
-- axis are swapped; this function lets us use the same code for both
local function calc_split_sizes(self, x, y, x1, x2)
    local n
    local ds = (x1 and x1 < 1 or x2 and x2 < 1) and 0 or style.divider_size
    if x1 then
      n = x1 + ds
    elseif x2 then
      n = self.size[x] - x2
    else
      n = math.floor(self.size[x] * self.divider)
    end
    self.a.position[x] = self.position[x]
    self.a.position[y] = self.position[y]
    self.a.size[x] = n - ds
    self.a.size[y] = self.size[y]
    self.b.position[x] = self.position[x] + n
    self.b.position[y] = self.position[y]
    self.b.size[x] = self.size[x] - n
    self.b.size[y] = self.size[y]
end


function Node:update_layout()
  if self.type == "leaf" then
    local av = self.active_view.view
    if #self.views > 1 then
      local _, _, _, th = self:get_tab_rect(1)
      av.position.x, av.position.y = self.position.x, self.position.y + th
      av.size.x, av.size.y = self.size.x, self.size.y - th
    else
      copy_position_and_size(av, self)
    end
  else
    local x1, y1 = self.a:get_locked_size()
    local x2, y2 = self.b:get_locked_size()
    if self.type == "hsplit" then
      calc_split_sizes(self, "x", "y", x1, x2)
    elseif self.type == "vsplit" then
      calc_split_sizes(self, "y", "x", y1, y2)
    end
    self.a:update_layout()
    self.b:update_layout()
  end
end


function Node:update()
  if self.type == "leaf" then
    for _, view in ipairs(self.views) do
      local ok = view.update and view:update()
    end
  else
    self.a:update()
    self.b:update()
  end
end


function Node:draw_tabs()
  local x, y, _, h = self:get_tab_rect(1)
  local ds = style.divider_size
  core.push_clip_rect(x, y, self.size.x, h)
  renderer.draw_rect(x, y, self.size.x, h, style.background3)
  renderer.draw_rect(x, y + h - ds, self.size.x, ds, style.divider)

  for i, view in ipairs(self.views) do
    local x, y, w, h = self:get_tab_rect(i)
    local text = view:get_name()
    local color = style.dim
    if view == self.active_view then
      color = style.text
      renderer.draw_rect(x, y, w, h, style.background)
      renderer.draw_rect(x + w, y, ds, h, style.divider)
      renderer.draw_rect(x - ds, y, ds, h, style.divider)
    end
    if i == self.hovered_tab then
      color = style.text
    end
    core.push_clip_rect(x, y, w, h)
    x, w = x + style.padding.x, w - style.padding.x * 2
    local align = style.font:get_width(text) > w and "left" or "center"
    common.draw_text(style.font, color, text, align, x, y, w, h)
    core.pop_clip_rect()
  end

  core.pop_clip_rect()
end


function Node:draw()
  if self.type == "leaf" then
    if #self.views > 1 then
      self:draw_tabs()
    end
    local pos, size = self.active_view.view.position, self.active_view.view.size
    core.push_clip_rect(pos.x, pos.y, size.x + pos.x % 1, size.y + pos.y % 1)
    self.active_view:draw()
    core.pop_clip_rect()
  else
    local x, y, w, h = self:get_divider_rect()
    local color = style.divider
    if(self.is_hovered) then color = style.divider_hover end
    renderer.draw_rect(x, y, w, h, color )
    self:propagate("draw")
  end
end

return Node
