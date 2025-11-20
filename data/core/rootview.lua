local core = require "core"
local common = require "core.common"
local style = require "core.style"
local keymap = require "core.keymap"
local View = require "core.view"
local DocView = require "core.docview"
local Node = require "core.node"

local utils   = require("lua.utils")

local function copy_position_and_size(dst, src)
  dst.position.x, dst.position.y = src.position.x, src.position.y
  dst.size.x, dst.size.y = src.size.x, src.size.y
end

local RootView = {}

function RootView:new()
  local new_rootview = utils.deepcopy(RootView)
  new_rootview.view = View:new()
  new_rootview.root_node = Node:new()
  new_rootview.deferred_draws = {}
  new_rootview.mouse = { x = 0, y = 0 }
  return new_rootview
end


function RootView:defer_draw(fn, ...)
  table.insert(self.deferred_draws, 1, { fn = fn, ... })
end


function RootView:get_active_node()
  return self.root_node:get_node_for_view(core.active_view)
end

function RootView:get_view_node(view)
  return self.root_node:get_node_for_view(view)
end

function RootView:get_named_node(name)
  return self.root_node:get_named_node(name)
end

function RootView:set_focus_view()
  -- print("Setting focus view...", core.focus_view, core.focus_view._is_locked)
  core.set_active_view(core.focus_view)
end

function RootView:open_doc(doc)
  local node = self:get_active_node()
  if node.locked and core.focus_view then
    self:set_focus_view()
    node = self.root_node:get_node_for_view(core.focus_view)
  end
  assert(not node.locked, "Cannot open doc on locked node")
  for i, view in ipairs(node.views) do
    if view.doc == doc then
      node:set_active_view(node.views[i])
      return view
    end
  end
  local view = DocView:new(doc)
  node:add_view(view)
  self.root_node:update_layout()
  view:scroll_to_line(view.doc:get_selection(), true, true)
  return view
end


function RootView:on_mouse_pressed(button, x, y, clicks)
  local div = self.root_node:get_divider_overlapping_point(x, y)
  if div then
    self.dragged_divider = div
    return
  end
  local node = self.root_node:get_child_overlapping_point(x, y)
  local idx = node:get_tab_overlapping_point(x, y)
  if idx then
    node:set_active_view(node.views[idx])
    if button == "middle" then
      node:close_active_view(self.root_node)
    end
  else
    core.set_active_view(node.active_view)
    if(node.active_view.on_mouse_pressed) then 
      node.active_view:on_mouse_pressed(button, x, y, clicks)
    else
      node.active_view.view:on_mouse_pressed(button, x, y, clicks)
    end
  end
end


function RootView:on_mouse_released(...)
  if self.dragged_divider then
    self.dragged_divider.is_hovered = nil
    self.dragged_divider = nil
    self.dragged_released = true
  end
  self.root_node:on_mouse_released(...)
end


function RootView:on_mouse_moved(x, y, dx, dy)
  if self.dragged_divider then
    self.dragged_divider.is_hovered = true
    local node = self.dragged_divider
    if node.type == "hsplit" then
      node.divider = node.divider + dx / node.size.x
    else
      node.divider = node.divider + dy / node.size.y
    end
    node.divider = common.clamp(node.divider, 0.01, 0.99)
    return
  end
  self.dragged_released = nil
  self.mouse.x, self.mouse.y = x, y
  self.root_node:on_mouse_moved(x, y, dx, dy)

  local node = self.root_node:get_child_overlapping_point(x, y)
  local div = self.root_node:get_divider_overlapping_point(x, y)
  if div then
    system.set_cursor(div.type == "hsplit" and "sizeh" or "sizev", div)
  elseif node:get_tab_overlapping_point(x, y) then
    system.set_cursor("arrow", node)
  else
    system.set_cursor(node.active_view.view.cursor, node)
  end
end


function RootView:on_mouse_wheel(...)
  local x, y = self.mouse.x, self.mouse.y
  self.dragged_released = nil
  local node = self.root_node:get_child_overlapping_point(x, y)
  local ok = node.active_view.on_mouse_wheel and node.active_view:on_mouse_wheel(...)
end


function RootView:on_text_input(...)
  local ok = core.active_view.on_text_input and core.active_view:on_text_input(...)
end


function RootView:update()
  copy_position_and_size(self.root_node, self.view)
  self.root_node:update()
  self.root_node:update_layout()
end


function RootView:draw()
  self.root_node:draw()
  while #self.deferred_draws > 0 do
    local t = table.remove(self.deferred_draws)
    t.fn(table.unpack(t))
  end
end

function RootView:get_node()
  return Node
end

return RootView
