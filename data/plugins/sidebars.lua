local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"

local ICON_SIZE = 24.0 * SCALE
local SIDEBAR_SIZE = 35.0 * SCALE

local SidebarData = {
    -- Sidebar can be extended as needed. Add your panel here
    color = style.line_number,
    position = { x = 0, y = 0 },
    size = { x = SIDEBAR_SIZE, y = SIDEBAR_SIZE },
    panels  = {
        { id = 1, name = "workspaces", icon = "", module = "workspaces", config = {} },
        { id = 2, name = "treeview", icon = "", module = "treeview", config = {} } ,
    },

    active_selected = 1,  -- Which item is actively selected (should always have one?)
}

-- Add a font to style so other plugins can use it if needed
style.fa_font   = renderer.font.load(EXEDIR .. "/data/fonts/fontawesome-webfont.ttf", ICON_SIZE)

local SidebarView = View:extend()

function SidebarView:new()
    SidebarView.super.new(self)
  self.scrollable = true
  self.visible = true
  self.init_size = true
  self.cache = {}
end

function SidebarView:get_cached(item)
  local t = self.cache[item.filename]
  if not t then
    t = {}
    t.icon = item.icon
    t.id = item.id
    t.selected = item.id == SidebarData.active_selected
    t.name = item.name
    t.depth = 1
    self.cache[t.id] = t
  end
  return t
end

function SidebarView:get_name()
  return "Project"
end

function SidebarView:get_item_height()
  return style.fa_font:get_height() + style.padding.y
end

function SidebarView:check_cache()
  -- invalidate cache's skip values if project_files has changed
  if core.project_files ~= self.last_project_files then
    for _, v in pairs(self.cache) do
      v.skip = nil
    end
    self.last_project_files = core.project_files
  end
end

function SidebarView:each_item()
  return coroutine.wrap(function()
    self:check_cache()
    local ox, oy = self:get_content_offset()
    local y = oy + style.padding.y
    local w = self.size.x
    local h = self:get_item_height()

    local i = 1
    while i <= #SidebarData.panels do
      local item = SidebarData.panels[i]
      local cached = self:get_cached(item)

      coroutine.yield(cached, ox, y, w, h)
      y = y + h
      i = i + 1
    end
  end)
end

function SidebarView:on_mouse_moved(px, py, dx, dy)
  self.hovered_item = nil
  for item, x,y,w,h in self:each_item() do
    if px > x and py > y and px <= x + w and py <= y + h then
      self.hovered_item = item
      break
    end
  end
end

function SidebarView:on_mouse_pressed(button, x, y)
  if not self.hovered_item then
    return 
  elseif self.hovered_item.type == "dir" then
    self.hovered_item.expanded = not self.hovered_item.expanded
  else
    -- TODO: Open panel if it is closed
    -- core.try(function()
    --   core.root_view:open_doc(core.open_doc(self.hovered_item.filename))
    -- end)
  end
end

function SidebarView:update()

  if(self.init_size == true and self.size.x ~= self.target_width) then
    self:move_towards(self.size, "x", self.target_width, 0.5, function() self.init_size = false end)
  else 
    self.target_width = self.size.x -- Update for border movement
  end

  SidebarView.super.update(self)
end

function SidebarView:draw()
  self:draw_background(style.background2)
  local spacing = 5 * SCALE
  local doc = core.active_view.doc
  for item, x,y,w,h in self:each_item() do
    local color = style.dim

    -- highlight active_view doc
    if item.selected == true then
      color = style.accent
    end

    -- hovered item background
    if item == self.hovered_item then
      renderer.draw_rect(x, y, w, h, style.line_highlight)
      color = style.accent
    end
    x = x + spacing
    y = y + spacing
    x = common.draw_text(style.fa_font, color, item.icon, nil, x, y, ICON_SIZE + spacing, ICON_SIZE + spacing)
  end
end

-- init
local view = SidebarView()
view.target_width = SIDEBAR_SIZE
local node = core.root_view:get_active_node()
-- Ok - the node is locked so you cant change its size. So.. we make a special case :)
local child = node:split("left", view, true)

local no_errors = true
-- Process panel modules 
for i, mod in ipairs(SidebarData.panels) do 
  local modname = "plugins.sidebars." .. mod.module
  local ok = core.try(require, modname)
  if ok then
    core.log_quiet("Loaded plugin %q", modname)
  else
    no_errors = false
  end  
end

-- register commands and keymap
command.add(nil, {
  ["sidebarview:toggle"] = function()
    view.visible = not view.visible
    view.target_width = SidebarData.size.x - view.target_width
    view.init_size = true
  end,
})

keymap.add { ["ctrl+shift+\\"] = "sidebarview:toggle" }
