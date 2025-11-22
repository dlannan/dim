local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"

local json  = require("lua.json")
local utils = require("lua.utils")

local WorkspacesView = {

  id = 1,
  name = "workspaces",
  icon = "",
  module = "workspaces",
  config = {},
  split_dir = "right",
  split_node = "Sidebar",
  locked = "Y",
  command = nil,

  max_width = 200,
  pad = 3,
}

WorkspacesView.width = WorkspacesView.max_width

local core = require "core"
local DocView = require "core.docview"


-- Unlike original workspace plugin, this holds multiple workspaces.
-- Allows user to jump between them and store them.
-- These will be selectable on startup too.

-- New workspace structure:
local WorkspaceData         = {
  current = 1,
  spaces = {
  }
}

local workspace_filename = ".dim_workspace.json"


local function serialize(val)
  if type(val) == "string" then
    return string.format("%q", val)
  elseif type(val) == "table" then
    local t = {}
    for k, v in pairs(val) do
      table.insert(t, "[" .. serialize(k) .. "]=" .. serialize(v))
    end
    return "{" .. table.concat(t, ",") .. "}"
  end
  return tostring(val)
end


local function has_no_locked_children(node)
  if node.locked then return false end
  if node.type == "leaf" then return true end
  return has_no_locked_children(node.a) and has_no_locked_children(node.b)
end


local function get_unlocked_root(node)
  if node.type == "leaf" then
    return not node.locked and node
  end
  if has_no_locked_children(node) then
    return node
  end
  return get_unlocked_root(node.a) or get_unlocked_root(node.b)
end


local function save_view(view)
  
  if view.is_docview then
    return {
      type = "doc",
      active = (core.active_view == view or core.active_view == view.parent),
      filename = view.doc.filename,
      selection = { view.doc:get_selection() },
      scroll = { x = view.view.scroll.to.x, y = view.view.scroll.to.y },
      text = not view.doc.filename and view.doc:get_text(1, 1, math.huge, math.huge)
    }
  end
  for name, mod in pairs(package.loaded) do
    if mod == view then
      return {
        type = "view",
        active = (core.active_view == view),
        module = name
      }
    end
  end
end


local function load_view(t)
  if t.type == "doc" then
    local ok, doc = pcall(core.open_doc, t.filename)
    if not ok then
      return DocView:new(core.open_doc())
    end
    local dv = DocView:new(doc)
    if t.text then doc:insert(1, 1, t.text) end
    doc:set_selection(table.unpack(t.selection))
    dv.last_line, dv.last_col = doc:get_selection()
    dv.view.scroll.x, dv.view.scroll.to.x = t.scroll.x, t.scroll.x
    dv.view.scroll.y, dv.view.scroll.to.y = t.scroll.y, t.scroll.y
    return dv
  end
  return require(t.module)()
end


local function save_node(node)
  local res = {}
  res.type = node.type
  if node.type == "leaf" then
    res.views = {}
    for _, view in ipairs(node.views) do
      local t = save_view(view)
      if t then
        table.insert(res.views, t)
        if node.active_view == view then
          res.active_view = #res.views
        end
      end
    end
  else
    res.divider = node.divider
    res.a = save_node(node.a)
    res.b = save_node(node.b)
  end
  return res
end


local function load_node(node, t)
  if t == nil then return nil end
  if t.type == "leaf" then
    local res
    for _, v in ipairs(t.views) do
      local view = load_view(v)
      if v.active then res = view end
      node:add_view(view)
    end
    if t.active_view then
      node:set_active_view(node.views[t.active_view])
    end
    return res
  else
    node:split(t.type == "hsplit" and "right" or "down")
    node.divider = t.divider
    local res1 = load_node(node.a, t.a)
    local res2 = load_node(node.b, t.b)
    return res1 or res2
  end
end

-- Save the workspace to the _current_ worspace. 
local function save_workspace()
  local root = get_unlocked_root(core.root_view.root_node)
  -- Read the original and deserialize into table. 
  local data_str = utils.loaddata(workspace_filename)
  local node_tbl = nil
  if(data_str) then 
    node_tbl = json.decode(data_str)
    node_tbl.current = WorkspaceData.current 
    node_tbl.spaces[node_tbl.current] = save_node(root) 

  -- Not found, then make a new one!!
  else 
    node_tbl = {
        current = 1,
        spaces = {
            [1] = save_node(root)
        }
    }
  end
  local out_str = json.encode(node_tbl)
  utils.savedata(workspace_filename, out_str)
end


local function load_workspace()
    local data_str = utils.loaddata(workspace_filename)
    if data_str then
        local t = json.decode(data_str)
        WorkspaceData = t
        local root = get_unlocked_root(core.root_view.root_node)
        local active_view = load_node(root, t.spaces[t.current])
        if active_view then
            core.set_active_view(active_view)
        end
    end
end

core.add_prerun( function() core.try(load_workspace) end )
core.add_postrun( function() print("Saving....");save_workspace() end)

function WorkspacesView:new(config)
  local new_workspacesview        = utils.deepcopy(WorkspacesView)
  new_workspacesview.view         = View:new()
  new_workspacesview.view.scrollable   = true
  new_workspacesview.view.get_scrollable_size = function() return new_workspacesview:get_scrollable_size() end 
  new_workspacesview.visible      = true
  new_workspacesview.header       = config and config.title or ""
  new_workspacesview.init_size    = true
  new_workspacesview.view.size.y  = style.font:get_height() + style.padding.y * 2
  new_workspacesview.view.size.x  = WorkspacesView.width

  return new_workspacesview
end

function WorkspacesView:get_scrollable_size()
    return style.font:get_height() + style.padding.y * 2
  end

function WorkspacesView:get_name()
    return "Workspaces"
end

function WorkspacesView:on_mouse_moved(px, py, dx, dy)
  self.hovered_item = nil
  local bx, by, bw, bh = self.view:get_content_bounds()
  local ox, oy = self.view:get_content_offset()
  local cw, ch = WorkspacesView.width/4, style.font:get_height()
  for i=0, 3 do 
    local x, y = i * cw + ox, oy 
    if px > x and py > y and px <= x + cw and py <= y + bh then
      self.hovered_item = i + 1
      break
    end
  end
  self.view:on_mouse_moved(px, py, dx, dy)
end

function WorkspacesView:on_mouse_pressed(...)
  core.root_view:set_focus_view()
  self.view:on_mouse_pressed(...)
end

function WorkspacesView:on_mouse_released(...)
  self.view:on_mouse_released(...)
end

function WorkspacesView:update()
  self.view.size.y = style.font:get_height() + style.padding.y * 2
  -- if(self.init_size == true and self.size.x ~= WorkspacesView.width) then
  --   self:move_towards(self.size, "x", WorkspacesView.width, 0.5, function() 
  --     self.init_size = false 
  --   end)
  -- else 
  --   -- PanelsView.max_width = self.size.x -- Update for border movement
  -- end
  WorkspacesView.width = self.view.size.x or WorkspacesView.width
  self.view:update()
end

function WorkspacesView:draw()
    self.view:draw_background(style.background)
    local bx, by, bw, bh = self.view:get_content_bounds()
    local ox, oy = self.view:get_content_offset()
    local cw, ch = WorkspacesView.width/4, style.font:get_height()
    local pd = WorkspacesView.pad
    for i=0, 3 do 

      local color = style.background3
      if(i + 1 == self.hovered_item) then color = style.icon_hover end

      local x, y = i * cw + ox, oy
      if(i + 1 == WorkspaceData.current) then 
        renderer.draw_rect(x + pd, y + pd, cw - pd *2, bh - pd *2, style.accent)
      else
        renderer.draw_rect(x + pd, y + pd, cw - pd *2, bh - pd *2, color)
      end
    end
end


command.add(nil, {
  ["workspaces:toggle"] = function()
    local ws_node = core.root_view:get_named_node("Workspaces")
    local ws_view = ws_node.views[1] -- only ever 1 view in a workspace!
    if( ws_view.visible ) then WorkspacesView.max_width = ws_view.view.size.x end 
    ws_view.visible = not ws_view.visible
    ws_view.view.size.x = ws_view.visible and WorkspacesView.max_width or 0 
    WorkspacesView.width = ws_view.view.size.x
  end,
})

keymap.add { ["ctrl+\\"] = "workspaces:toggle" }

return WorkspacesView
