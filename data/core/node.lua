local core = require "core"
local common = require "core.common"
local config = require "core.config"
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
  renderer.draw_text(style.font, "its a small world...", wd, y + (dh - th) / 2 + style.big_font:get_height(), color)

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
    hovered_close = 0,
    tab_shift = 0,
    tab_offset = 1,
    tab_width = 0, 
    move_towards = 0, 
}

function Node:new(node_type)
    local new_node = utils.deepcopy(Node)
    new_node.type = node_type or "leaf"

    new_node.tab_width = style.tab_width
    new_node.move_towards = View.move_towards
  
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

---@deprecated
function Node:on_mouse_left()
  core.deprecation_log("Node:on_mouse_left")
  if self.type == "leaf" then
    self.active_view.view:on_mouse_left()
  else
    self:propagate("on_mouse_left")
  end
end

function Node:consume(node)
  for k, _ in pairs(self) do self[k] = nil end
  for k, v in pairs(node) do self[k] = v   end
end

local type_map = { up="vsplit", down="vsplit", left="hsplit", right="hsplit" }

-- The "locked" argument below should be in the form {x = <boolean>, y = <boolean>}
-- and it indicates if the node want to have a fixed size along the axis where the
-- boolean is true. If not it will be expanded to take all the available space.
-- The "resizable" flag indicates if, along the "locked" axis the node can be resized
-- by the user. If the node is marked as resizable their view should provide a
-- set_target_size method.
function Node:split(dir, view, locked, resizable)
  assert(self.type == "leaf", "Tried to split non-leaf node")
  local node_type = assert(type_map[dir], "Invalid direction")
  local last_active = core.active_view
  local child = Node:new()
  child:consume(self)
  self:consume(Node:new(node_type))
  self.a = child
  local view_node = Node:new()
  self.b = view_node
  if view then 
    self.b:add_view(view) 
    self.b.nofocus = view.nofocus
  end

  if locked then
    assert(type(locked) == 'table')
    self.b.locked = locked
    self.b.resizable = resizable or false
    if(last_active) then 
      core.set_active_view(last_active) 
    end
  end

  if dir == "up" or dir == "left" then
    self.a, self.b = self.b, self.a
  end
  return view_node
end

function Node:remove_view(root, view)
  if #self.views > 1 then
    local idx = self:get_view_idx(view)
    if idx < self.tab_offset then
      self.tab_offset = self.tab_offset - 1
    end
    table.remove(self.views, idx)
    if self.active_view == view then
      self:set_active_view(self.views[idx] or self.views[#self.views])
    end
  else
    local parent = self:get_parent_node(root)
    local is_a = (parent.a == self)
    local other = parent[is_a and "b" or "a"]
    local locked_size_x, locked_size_y = other:get_locked_size()
    local locked_size
    if parent.type == "hsplit" then
      locked_size = locked_size_x
    else
      locked_size = locked_size_y
    end
    local next_primary
    if self.is_primary_node then
      next_primary = core.root_view:select_next_primary_node()
    end
    if locked_size or (self.is_primary_node and not next_primary) then
      self.views = {}
      self:add_view(EmptyView:new())
    else
      if other == next_primary then
        next_primary = parent
      end
      parent:consume(other)
      local p = parent
      while p.type ~= "leaf" do
        p = p[is_a and "a" or "b"]
      end
      p:set_active_view(p.active_view)
      if self.is_primary_node then
        next_primary.is_primary_node = true
      end
    end
  end
  core.last_active_view = nil
end

function Node:close_view(root, view)
  local do_close = function()
    self:remove_view(root, view)
  end
  view:try_close(do_close)
end


-- Assumes the node 
local anodetype = { up = true, left = true }
local bnodetype = { down = true, right = true }

function Node:get_direction_node(dir)
  
  if self.a and (anodetype[dir]) then 
    return self.a:get_direction_node(dir) 
  elseif self.b and (bnodetype[dir]) then 
    return self.b:get_direction_node(dir) 
  else 
    return self 
  end
end

function Node:close_active_view(root)
  self:close_view(root, self.active_view)
end

function Node:add_view(view, idx)
  assert(self.type == "leaf", "Tried to add view to non-leaf node")
  -- assert(not self.locked, "Tried to add view to locked node")
  if self.views[1] and self.views[1].is_empty == true then
    table.remove(self.views)
    if idx and idx > 1 then
      idx = idx - 1
    end
  end
  idx = common.clamp(idx or (#self.views + 1), 1, (#self.views + 1))
  table.insert(self.views, idx, view)
  self:set_active_view(view)
end

function Node:set_active_view(view)
  assert(self.type == "leaf", "Tried to set active view on non-leaf node")
  local last_active_view = self.active_view
  self.active_view = view
  core.set_active_view(view)
  if last_active_view and last_active_view ~= view then
    if(last_active_view.on_mouse_left) then last_active_view:on_mouse_left() end
  end
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
  return nil
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

function Node:get_children_nodes(t)
  t = t or {}
  table.insert(t, self)
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

function Node:get_visible_tabs_number()
  return math.min(#self.views - self.tab_offset + 1, config.max_tabs)
end


-- Returns true for nodes that accept either "proportional" resizes (based on the
-- node.divider) or "locked" resizable nodes (along the resize axis).
function Node:is_resizable(axis)
  if self.type == 'leaf' then
    return not self.locked or not self.locked[axis] or self.resizable
  else
    local a_resizable = self.a:is_resizable(axis)
    local b_resizable = self.b:is_resizable(axis)
    return a_resizable and b_resizable
  end
end

-- Return true iff it is a locked pane along the rezise axis and is
-- declared "resizable".
function Node:is_locked_resizable(axis)
  return self.locked and self.locked[axis] and self.resizable
end

function Node:resize(axis, value)
  -- the application works fine with non-integer values but to have pixel-perfect
  -- placements of view elements, like the scrollbar, we round the value to be
  -- an integer.
  value = math.floor(value)
  if self.type == 'leaf' then
    -- If it is not locked we don't accept the
    -- resize operation here because for proportional panes the resize is
    -- done using the "divider" value of the parent node.
    if self:is_locked_resizable(axis) then
      return self.active_view.view:set_target_size(axis, value)
    end
  else
    if self.type == (axis == "x" and "hsplit" or "vsplit") then
      -- we are resizing a node that is splitted along the resize axis
      if self.a:is_locked_resizable(axis) and self.b:is_locked_resizable(axis) then
        local rem_value = value - self.a.size[axis]
        if rem_value >= 0 then
          if self.b.active_view.size[axis] <= 0 then
            -- if 'b' not visible resize 'a' instead
            return self.a.active_view:set_target_size(axis, value)
          end
          return self.b.active_view:set_target_size(axis, rem_value)
        else
          self.b.active_view:set_target_size(axis, 0)
          return self.a.active_view:set_target_size(axis, value)
        end
      end
    else
      -- we are resizing a node that is splitted along the axis perpendicular
      -- to the resize axis
      local a_resizable = self.a:is_resizable(axis)
      local b_resizable = self.b:is_resizable(axis)
      if a_resizable and b_resizable then
        self.a:resize(axis, value)
        self.b:resize(axis, value)
      end
    end
  end
end

-- return the width including the padding space and separately
-- the padding space itself
local function get_scroll_button_width()
  local w = style.icon_font:get_width(">")
  local pad = w
  return w + 2 * pad, pad
end

local function get_tab_y_sizes()
  local height = style.font:get_height()
  local padding = style.padding.y
  local margin = style.margin.tab.top
  return height + (padding * 2) + margin, padding, margin
end

function Node:get_scroll_button_rect(index)
  local w, pad = get_scroll_button_width()
  local h = get_tab_y_sizes()
  local x = self.position.x + (index == 1 and self.size.x - w * 2 or self.size.x - w)
  return x, self.position.y, w, h, pad
end


function Node:get_split_type(mouse_x, mouse_y)
  local x, y = self.position.x, self.position.y
  local w, h = self.size.x, self.size.y
  local _, _, _, tab_h = self:get_scroll_button_rect(1)
  y = y + tab_h
  h = h - tab_h

  local local_mouse_x = mouse_x - x
  local local_mouse_y = mouse_y - y

  if local_mouse_y < 0 then
    return "tab"
  else
    local left_pct = local_mouse_x * 100 / w
    local top_pct = local_mouse_y * 100 / h
    if left_pct <= 30 then
      return "left"
    elseif left_pct >= 70 then
      return "right"
    elseif top_pct <= 30 then
      return "up"
    elseif top_pct >= 70 then
      return "down"
    end
    return "middle"
  end
end

function Node:get_drag_overlay_tab_position(x, y, dragged_node, dragged_index)
  local tab_index = self:get_tab_overlapping_point(x, y)
  if not tab_index then
    local first_tab_x = self:get_tab_rect(1)
    if x < first_tab_x then
      -- mouse before first visible tab
      tab_index = self.tab_offset or 1
    else
      -- mouse after last visible tab
      tab_index = self:get_visible_tabs_number() + (self.tab_offset - 1 or 0)
    end
  end
  local tab_x, tab_y, tab_w, tab_h, margin_y = self:get_tab_rect(tab_index)
  if x > tab_x + tab_w / 2 and tab_index <= #self.views then
    -- use next tab
    tab_x = tab_x + tab_w
    tab_index = tab_index + 1
  end
  if self == dragged_node and dragged_index and tab_index > dragged_index then
    -- the tab we are moving is counted in tab_index
    tab_index = tab_index - 1
    tab_x = tab_x - tab_w
  end
  return tab_index, tab_x, tab_y + margin_y, tab_w, tab_h - margin_y
end

function Node:get_tab_overlapping_point(px, py)
  if #self.views == 1 then return nil end
  local x, y, w, h = self:get_tab_rect(1)
  if px >= x and py >= y and px < x + w * #self.views and py < y + h then
    return math.floor((px - x) / w) + 1
  end
end

local function close_button_location(x, w)
  local cw = style.icon_font:get_width("C")
  local pad = style.padding.x / 2
  return x + w - cw - pad, cw, pad
end

function Node:tab_hovered_update(px, py)
  self.hovered_close = 0
  self.hovered_scroll_button = 0
  if not self:should_show_tabs() then self.hovered_tab = nil return end
  local tab_index = self:get_tab_overlapping_point(px, py)
  self.hovered_tab = tab_index
  if tab_index then
    local x, y, w, h = self:get_tab_rect(tab_index)
    local cx, cw = close_button_location(x, w)
    if px >= cx and px < cx + cw and py >= y and py < y + h and config.tab_close_button then
      self.hovered_close = tab_index
    end
  elseif #self.views > self:get_visible_tabs_number() then
    self.hovered_scroll_button = self:get_scroll_button_index(px, py) or 0
  end
end

function Node:get_scroll_button_index(px, py)
  if #self.views == 1 then return end
  for i = 1, 2 do
    local x, y, w, h = self:get_scroll_button_rect(i)
    if px >= x and px < x + w and py >= y and py < y + h then
      return i
    end
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
        if self.locked or self.nofocus then
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

function Node.copy_position_and_size(dst, src)
  copy_position_and_size(dst, src)
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

function Node:scroll_tabs_to_visible()
  local index = self:get_view_idx(self.active_view)
  if index then
    local tabs_number = self:get_visible_tabs_number()
    if self.tab_offset > index then
      self.tab_offset = index
    elseif self.tab_offset + tabs_number - 1 < index then
      self.tab_offset = index - tabs_number + 1
    elseif tabs_number < config.max_tabs and self.tab_offset > 1 then
      self.tab_offset = #self.views - config.max_tabs + 1
    end
  end
end


function Node:target_tab_width()
  local n = self:get_visible_tabs_number()
  local w = self.size.x
  if #self.views > n then
    w = self.size.x - get_scroll_button_width() * 2
  end
  return common.clamp(style.tab_width, w / config.max_tabs, w / n)
end

function Node:update()
  if self.type == "leaf" then
    self:scroll_tabs_to_visible()
    if(self.active_view.update) then self.active_view:update() end
    self:tab_hovered_update(core.root_view.mouse.x, core.root_view.mouse.y)
    local tab_width = self:target_tab_width()
    -- self:move_towards("tab_shift", tab_width * (self.tab_offset - 1), nil, "tabs")
    -- self:move_towards("tab_width", tab_width, nil, "tabs")
  else
    if(self.a.update) then self.a:update() end
    if(self.b.update) then self.b:update() end
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

function Node:should_show_tabs()
  if self.locked or self.nofocus then return false end
  if config.hide_tabs then
    return false
  elseif #self.views > 1 then -- show tabs while dragging
    return true
  elseif config.always_show_tabs then
    return not self.views[1].is_empty
  end
  return false
end

function Node:draw()
  if(self.no_draw) then return end
  if self.type == "leaf" then
    if #self.views > 1 then
      self:draw_tabs()
    end
    local pos, size = self.active_view.view.position, self.active_view.view.size
    -- if size.x > 0 and size.y > 0 then
      core.push_clip_rect(pos.x, pos.y, size.x, size.y)
      self.active_view:draw(pos, size)
      core.pop_clip_rect()
    -- end
  else
    local x, y, w, h = self:get_divider_rect()
    local color = style.divider
    if(self.is_hovered) then color = style.divider_hover end
    renderer.draw_rect(x, y, w, h, color )
    self:propagate("draw")
  end
end

function Node:is_empty()
  if self.type == "leaf" then
    return #self.views == 0 or (#self.views == 1 and self.views[1].is_empty)
  else
    return self.a:is_empty() and self.b:is_empty()
  end
end

return Node
