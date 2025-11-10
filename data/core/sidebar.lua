local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"

local ICON_SIZE     = 24.0 * SCALE
local SIDEBAR_SIZE  = 35.0 * SCALE
local ICON_SPACING  = 8.0 * SCALE

local SidebarData = {
    -- Sidebar can be extended as needed. Add your panel here
    color = style.line_number,
    position = { x = 0, y = 0 },
    size = { x = SIDEBAR_SIZE, y = SIDEBAR_SIZE },
    panels  = {
        { 
          id = 1, 
          name = "workspaces", 
          icon = "", 
          module = "workspaces", 
          config = {},  
          split_dir = nil, 
          split_node = nil, 
          command = "workspaces:toggle" 
        },
        { 
          id = 2, 
          name = "panels", 
          icon = nil, 
          module = "panels", 
          config = { title = config.project_path }, 
          split_dir = "right", 
          split_node = "Sidebar", 
          command = nil
        },
        { 
          id = 3, 
          name = "treeview", 
          icon = "", 
          module = "treeview", 
          config = {},  
          split_dir = "down", 
          split_node = "Panels", 
          command = "treeview:toggle"
        },
        -- { 
        --   id = 4, 
        --   name = "search", 
        --   icon = "", 
        --   module = "search", 
        --   config = {},  
        --   split_dir = "down", 
        --   split_node = "Panels", 
        --   command = "searchfiles:toggle" 
        -- },
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
  self.width  = SIDEBAR_SIZE + ICON_SPACING
end

function SidebarView:load_modules()
  local no_errors = true

  -- Process panel modules 
  --  Make the base structure for enabled panels
  for i, mod in ipairs(SidebarData.panels) do 
    local modname = "plugins.sidebars." .. mod.module
    local ok, ViewClass = core.try(require, modname)
    if ok == true then
      core.log_quiet("Loaded plugin %q", modname)
  
      if(mod.split_dir) then 
        local node = core.root_view:get_active_node()
        if(mod.split_node) then 
          node = core.root_view:get_named_node(mod.split_node)
        end
        local view = ViewClass(mod.config) 
        node:split(mod.split_dir, view, true)
      end
    else
      no_errors = false
    end  
  end
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
  return "Sidebar"
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
      if(item.icon) then 
        local cached = self:get_cached(item)

        coroutine.yield(cached, ox, y, w, h)
        y = y + h
      end
      i = i + 1
    end
  end)
end

function SidebarView:on_mouse_moved(px, py, dx, dy)
  self.hovered_item = nil
  for item, x,y,w,h in self:each_item() do
    if px > x and py > y and px <= x + w and py <= y + h then
      self.hovered_item = item.id
      break
    end
  end
end

function SidebarView:on_mouse_released(button, x, y)
  if not self.hovered_item then
    core.root_view:set_focus_view()
  -- elseif self.hovered_item == "dir" then
  --   self.hovered_item.expanded = not self.hovered_item.expanded
  else
    -- TODO: Open panel if it is closed
    local item = SidebarData.panels[self.hovered_item]
    core.try(function()
      command.perform(item.command)
    end)
  end
end

function SidebarView:update()

  if(self.init_size == true and self.size.x ~= self.width) then
    self:move_towards(self.size, "x", self.width, 0.5, function() self.init_size = false end)
  else 
    self.width = self.size.x -- Update for border movement
  end

  SidebarView.super.update(self)
end

function SidebarView:draw()
  self:draw_background(style.background2)
  local doc = core.active_view.doc
  for item, x,y,w,h in self:each_item() do
    local color = style.dim

    -- highlight active_view doc
    if item.selected == true then
      color = style.accent
    end

    -- hovered item background
    if item.id == self.hovered_item then
      renderer.draw_rect(x, y, w, h, style.line_highlight)
      color = style.icon_hover
    end

    if(item.icon) then 
      x = x + ICON_SPACING
      x = common.draw_text(style.fa_font, color, item.icon, nil, x, y, ICON_SIZE, ICON_SIZE)
    end
  end
end

-- The side bar sets up the whole display view.
-- First a sidebar is made. Then the Panels column, then the documents view.
-- local view = SidebarView()
-- local node = core.root_view:get_active_node()
-- local child = node:split("left", view, true)

-- register commands and keymap
command.add(nil, {
  ["sidebarview:toggle"] = function()
    SidebarView.visible = not SidebarView.visible
    -- view.target_width = SidebarData.size.x - view.target_width
    SidebarView.width = SIDEBAR_SIZE + ICON_SPACING - SidebarView.width 
    SidebarView.init_size = true
  end,
})

keymap.add { ["ctrl+shift+\\"] = "sidebarview:toggle" }

return SidebarView