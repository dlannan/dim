local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"
local utils   = require("lua.utils")

local ICON_SIZE     = 20.0 * SCALE
local SIDEBAR_SIZE  = 35.0 * SCALE
local ICON_SPACING  = 12.0 * SCALE

local SidebarData = {
    -- Sidebar can be extended as needed. Add your panel here
    color = style.line_number,
    position = { x = 0, y = 0 },
    size = { x = SIDEBAR_SIZE, y = SIDEBAR_SIZE },

    panel_select = 3,
    -- The panels are filles out by the panel views (see treeview for example)
    panels  = {},
    pcount  = 0,
}

-- Add font awesome to style so other plugins can use it if needed
style.fa_font   = renderer.font.load(EXEDIR .. "/data/fonts/fontawesome-webfont.ttf", ICON_SIZE)

local SidebarView = {}

function SidebarView:new()
  local new_sidebar = utils.deepcopy(SidebarView)
  new_sidebar.view = View:new()
  new_sidebar.view.scrollable = true
  new_sidebar.visible = true

  new_sidebar.init_size = true
  new_sidebar.cache = {}
  new_sidebar.hovered_item = nil
  SidebarView.width  = SIDEBAR_SIZE + ICON_SPACING
  return new_sidebar
end

function SidebarView:load_panel(ViewClass)
  local no_errors = true

    -- Process panel modules
    --  Make the base structure for enabled panels
    if ViewClass then
    local mod = {
        id = ViewClass.id or #SidebarData.panels,
        name = ViewClass.name,
        icon = ViewClass.icon,
        config = ViewClass.config,
        split_dir = ViewClass.split_dir,
        split_node = ViewClass.split_node,
        command = ViewClass.command,
        view_class = ViewClass,
        locked = ViewClass.locked,
    }
    SidebarData.panels[mod.id] = mod 
    SidebarData.pcount = SidebarData.pcount + 1
  end
end

function SidebarView:init_panels()
  for k, mod in ipairs(SidebarData.panels) do
    if(mod.split_dir) then
      local node = core.root_view:get_active_node()
      if(mod.split_node) then
        node = core.root_view:get_named_node(mod.split_node)
      end
      print(mod.name)
      mod.view = mod.view_class:new(mod.config)
      mod.child = node:split(mod.split_dir, mod.view, mod.locked)
    end 
  end
end

function SidebarView:get_cached(item)
  local t = self.cache[item.filename]
  if not t then
    t = {}
    t.icon = item.icon
    t.id = item.id
    t.name = item.name
    t.command = item.command
    t.view = item.view
    t.locked = item.locked
    self.cache[t.id] = t
  end
  return t
end

function SidebarView:get_name()
  return "Sidebar"
end

function SidebarView:get_item_height()
  return ICON_SIZE + ICON_SPACING
end

function SidebarView:each_item()

  return coroutine.wrap(function()
    local ox, oy = self.view:get_content_offset()
    local y = oy + ICON_SPACING
    local w = self.view.size.x
    local h = self:get_item_height()

    local i = 1
    while i <= SidebarData.pcount do
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

    local item = SidebarData.panels[self.hovered_item]
    if(item) then 
      -- Open the panel (toggle panels usign show_panel method - must be implemented)
      if(SidebarData.panel_select ~= self.hovered_item) then 
        SidebarData.panel_select = self.hovered_item
        -- Iterate panels and set correct one open
        for k,v in ipairs(SidebarData.panels) do 
          if(v.view) then 
            if(SidebarData.panel_select == v.id) then 
              if(v.view.show_panel) then v.view:show_panel(true) end
            else 
              if(v.view.show_panel) then v.view:show_panel(false) end
            end
          end
        end
      else 
        if(item.command) then
          core.try(function()
            command.perform(item.command)
          end)
        end
      end
    end
  end
end

function SidebarView:update()

  if(self.init_size == true and self.view.size.x ~= SidebarView.width) then
    self.view:move_towards(self.view.size, "x", SidebarView.width, 0.5, function() 
      self.init_size = false 
    end)
  else
    -- self.width = self.size.x -- Update for border movement
  end
  -- self.view:update()
end

function SidebarView:draw()
  self.view:draw_background(style.background2)
  local doc = core.active_view.doc
  for item, x,y,w,h in self:each_item() do
    local color = style.dim

    -- Handle state for the panels - only 1 active at a time (for now)
    -- if(SidebarData.panel_select == item.id) then
    --   item.view.visible = true
    -- else
    --   item.view.visible = false
    -- end

    -- highlight active_view doc
    if item.id == SidebarData.panel_select then
      color = style.accent
    end

    -- hovered item background
    if item.id == self.hovered_item then
      renderer.draw_rect(x, y, w, h, style.line_highlight)
      color = style.icon_hover
    end

    -- highlight active_view doc
    if item.id == SidebarData.panel_select then
      renderer.draw_rect(x, y, 2, h, style.text)
    end

    if(item.icon) then
      x = x + ICON_SPACING
      x = common.draw_text(style.fa_font, color, item.icon, nil, x, y+ICON_SPACING * 0.5, ICON_SIZE, ICON_SIZE)
    end
  end
end

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
