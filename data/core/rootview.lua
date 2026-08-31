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

  new_rootview.grab = nil -- = {view = nil, button = nil}
  new_rootview.overlapping_view = nil
  new_rootview.touched_view = nil
  new_rootview.first_dnd_processed = false  
  return new_rootview
end


function RootView:defer_draw(fn, ...)
  table.insert(self.deferred_draws, 1, { fn = fn, ... })
end


function RootView:get_active_node()
  local node = self.root_node:get_node_for_view(core.active_view)
  if not node then node = self:get_primary_node() end
  return node
end

---@return core.node
local function get_primary_node(node)
  if node.is_primary_node then
    return node
  end
  if node.type ~= "leaf" then
    return get_primary_node(node.a) or get_primary_node(node.b)
  end
end

---@return core.node
function RootView:get_active_node_default()
  local node = self.root_node:get_node_for_view(core.active_view)
  if not node then node = self:get_primary_node() end
  if node.locked or node.nofocus then
    local default_node = self:get_primary_node()
    if(default_node) then 
      local default_view = default_node.views[1]
      assert(default_view, "internal error: cannot find original document node.")
      core.set_active_view(default_view)
      node = self:get_active_node()
    end
  end
  return node
end

---@return core.node
function RootView:get_primary_node()
  return get_primary_node(self.root_node)
end

---@param node core.node
---@return core.node
local function select_next_primary_node(node)
  if node.is_primary_node then return end
  if node.type ~= "leaf" then
    return select_next_primary_node(node.a) or select_next_primary_node(node.b)
  else
    local lx, ly = node:get_locked_size()
    if not lx and not ly then
      return node
    end
  end
end

---@return core.node
function RootView:select_next_primary_node()
  return select_next_primary_node(self.root_node)
end

function RootView:get_view_node(view)
  return self.root_node:get_node_for_view(view)
end

function RootView:set_focus_view()
  -- print("Setting focus view...", core.focus_view, core.focus_view._is_locked)
  core.set_active_view(core.focus_view)
end

function RootView:get_named_node(name)
  return self.root_node:get_named_node(name)
end

---@param doc core.doc
---@return core.docview
function RootView:open_doc(doc)
  local node = self:get_active_node()
  if(node == nil) then node = core.root_view:get_active_node() end
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

  local view =  DocView:new(doc)
  node:add_view(view)
  self.root_node:update_layout()
  view:scroll_to_line(view.doc:get_selection(), true, true)
  return view
end

---@param keep_active boolean
function RootView:close_all_docviews(keep_active)
  self.root_node:close_all_docviews(keep_active)
end

---Obtain mouse grab.
---
---This means that mouse movements will be sent to the specified view, even when
---those occur outside of it.
---There can't be multiple mouse grabs, even for different buttons.
---@see RootView:ungrab_mouse
---@param button core.view.mousebutton
---@param view core.view
function RootView:grab_mouse(button, view)
  assert(self.grab == nil)
  self.grab = {view = view, button = button}
end

---Release mouse grab.
---
---The specified button *must* be the last button that grabbed the mouse.
---@see RootView:grab_mouse
---@param button core.view.mousebutton
function RootView:ungrab_mouse(button)
  assert(self.grab and self.grab.button == button)
  self.grab = nil
end


---Function to intercept mouse pressed events on the active view.
---Do nothing by default.
---@param button core.view.mousebutton
---@param x number
---@param y number
---@param clicks integer
function RootView.on_view_mouse_pressed(button, x, y, clicks)
end

---@param button core.view.mousebutton
---@param x number
---@param y number
---@param clicks integer
---@return boolean
function RootView:on_mouse_pressed(button, x, y, clicks)
  -- If there is a grab, release it first
  -- if self.grab then
  --   self:on_mouse_released(self.grab.button, x, y)
  -- end

  local div = self.root_node:get_divider_overlapping_point(x, y)
  local node = self.root_node:get_child_overlapping_point(x, y)

  if div and (node and not node.active_view.view:scrollbar_overlaps_point(x, y)) then
    self.dragged_divider = div
    return true
  end

  if node.hovered_scroll_button > 0 then
    node:scroll_tabs(node.hovered_scroll_button)
    return true
  end
  local idx = node:get_tab_overlapping_point(x, y)
  if idx then
    if button == "middle" or node.hovered_close == idx then
      node:close_view(self.root_node, node.views[idx])
      return true
    else
      node:set_active_view(node.views[idx])
      return true
    end
  else
    core.set_active_view(node.active_view)
    if(node.active_view.on_mouse_pressed) then 
      node.active_view:on_mouse_pressed(button, x, y, clicks)
    else
      node.active_view.view:on_mouse_pressed(button, x, y, clicks)
    end
    -- self:grab_mouse(button, node.active_view)
    -- return self.on_view_mouse_pressed(button, x, y, clicks) or node.active_view.view:on_mouse_pressed(button, x, y, clicks)
  end
end

function RootView:set_show_overlay(overlay, status)
  overlay.visible = status
  if status then -- reset colors
    -- reload base_color
    overlay.base_color = self:get_overlay_base_color(overlay)
    overlay.color[1] = overlay.base_color[1]
    overlay.color[2] = overlay.base_color[2]
    overlay.color[3] = overlay.base_color[3]
    overlay.color[4] = overlay.base_color[4]
    overlay.opacity = 0
  end
end

---@param button core.view.mousebutton
---@param x number
---@param y number
function RootView:on_mouse_released(button, x, y, ...)

  -- if self.grab then
  --   if self.grab.button == button then
  --     local grabbed_view = self.grab.view
  --     grabbed_view:on_mouse_released(button, x, y, ...)
  --     self:ungrab_mouse(button)

  --     -- If the mouse was released over a different view, send it the mouse position
  --     local hovered_view = self.root_node:get_child_overlapping_point(x, y)
  --     if grabbed_view ~= hovered_view then
  --       self:on_mouse_moved(x, y, 0, 0)
  --     end
  --   end
  --   return
  -- end

  if self.dragged_divider then
    self.dragged_divider = nil
  else
    local node = self.root_node:get_child_overlapping_point(x, y)
    if(node) then 
      node:on_mouse_released(button, x, y)
    end
  end
end


local function resize_child_node(node, axis, value, delta)
  local accept_resize = node.a:resize(axis, value)
  if not accept_resize then
    accept_resize = node.b:resize(axis, node.size[axis] - value)
  end
  if not accept_resize then
    node.divider = node.divider + delta / node.size[axis]
  end
end


---@param x number
---@param y number
---@param dx number
---@param dy number
function RootView:on_mouse_moved(x, y, dx, dy)
  self.mouse.x, self.mouse.y = x, y

  -- if self.grab then
  --   self.grab.view:on_mouse_moved(x, y, dx, dy)
  --   core.request_cursor(self.grab.view.cursor)
  --   return
  -- end

  if core.active_view == core.nag_view then
    core.request_cursor("arrow")
    core.active_view.view:on_mouse_moved(x, y, dx, dy)
    return
  end

  if self.dragged_divider then
    local node = self.dragged_divider
    if node.type == "hsplit" then
      x = common.clamp(x - node.position.x, 0, self.root_node.size.x * 0.95)
      resize_child_node(node, "x", x, dx)
    elseif node.type == "vsplit" then
      y = common.clamp(y - node.position.y, 0, self.root_node.size.y * 0.95)
      resize_child_node(node, "y", y, dy)
    end
    node.divider = common.clamp(node.divider, 0.01, 0.99)
    return
  end

  -- If the view hovered is locked, send moved regardless - you cant grab it
  local node = self.root_node:get_child_overlapping_point(x, y)
  if(node) then 
    node:on_mouse_moved(x, y, dx, dy)
  end

  local div = self.root_node:get_divider_overlapping_point(x, y)
  if div then
    system.set_cursor(div.type == "hsplit" and "sizeh" or "sizev", div)
  elseif node:get_tab_overlapping_point(x, y) then
    system.set_cursor("arrow", node)
  else
    system.set_cursor(node.active_view.view.cursor, node)
  end 
end

function RootView:on_mouse_left()
  if self.overlapping_view then
    self.overlapping_view.view:on_mouse_left()
  end
end


function RootView:on_mouse_wheel(...)
  local x, y = self.mouse.x, self.mouse.y
  local node = self.root_node:get_child_overlapping_point(x, y)
    -- return node.active_view.view:on_mouse_wheel(...)
  local ok = node.active_view.on_mouse_wheel and node.active_view:on_mouse_wheel(...)
end

function RootView:on_touch_pressed(x, y, ...)
  local touched_node = self.root_node:get_child_overlapping_point(x, y)
  self.touched_view = touched_node and touched_node.active_view
end

function RootView:on_touch_released(x, y, ...)
  self.touched_view = nil
end


function RootView:on_touch_moved(x, y, dx, dy, ...)
  if not self.touched_view then return end
  if core.active_view == core.nag_view then
    core.active_view.view:on_touch_moved(x, y, dx, dy, ...)
    return
  end

  if self.dragged_divider then
    local node = self.dragged_divider
    if node.type == "hsplit" then
      x = common.clamp(x - node.position.x, 0, self.root_node.size.x * 0.95)
      resize_child_node(node, "x", x, dx)
    elseif node.type == "vsplit" then
      y = common.clamp(y - node.position.y, 0, self.root_node.size.y * 0.95)
      resize_child_node(node, "y", y, dy)
    end
    node.divider = common.clamp(node.divider, 0.01, 0.99)
    return
  end

  self.touched_view:on_touch_moved(x, y, dx, dy, ...)
end

function RootView:on_text_input(...)
  local ok = core.active_view.on_text_input and core.active_view:on_text_input(...)
end

---@param filename string
---@param x number
---@param y number
---@return boolean
function RootView:on_file_dropped(filename, x, y)
  local node = self.root_node:get_child_overlapping_point(x, y)
  local result = node and node.active_view.view:on_file_dropped(filename, x, y)
  if result then return result end
  local info = system.get_file_info(filename)
  if info and info.type == "dir" then
    if self.first_dnd_processed then
      -- first update done, open in new window
      system.exec(string.format("%q %q", EXEFILE, filename))
    else
      -- DND event before first update, this is sent by macOS when folder is dropped into the dock
      core.confirm_close_docs(core.docs, function(dirpath)
        core.open_folder_project(dirpath)
      end, system.absolute_path(filename))
      self.first_dnd_processed = true
    end
  else
    local ok, doc = core.try(core.open_doc, filename)
    if ok then
      local node = core.root_view.root_node:get_child_overlapping_point(x, y)
      node:set_active_view(node.active_view)
      core.root_view:open_doc(doc)
    end
  end
  return true
end

function RootView:on_ime_text_editing(...)
  core.active_view.view:on_ime_text_editing(...)
end

function RootView:on_focus_lost(...)
  -- We force a redraw so documents can redraw without the cursor.
  core.redraw = true
end

function RootView:update()
  copy_position_and_size(self.root_node, self.view)
  self.root_node:update()
  self.root_node:update_layout()

  -- set this to true because at this point there are no dnd requests
  -- that are caused by the initial dnd into dock user action
  self.first_dnd_processed = true
end


function RootView:draw()
  self.root_node:draw()
  while #self.deferred_draws > 0 do
    local t = table.remove(self.deferred_draws)
    t.fn(table.unpack(t))
  end

  if core.cursor_change_req then
    system.set_cursor(core.cursor_change_req, { 
        position = { 
          x = self.mouse.x, 
          y = self.mouse.y 
        }, 
        size = { 
          x = 1.0, 
          y = 1.0 
        }
      })
    core.cursor_change_req = nil
  end
end

function RootView:get_node()
  return Node
end

return RootView
