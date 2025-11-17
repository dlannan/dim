local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"

config.treeview_size = 200 * SCALE

local TreeViewData = {
  width = config.treeview_size
}

local function get_depth(filename)
  if(config.project_path ~= ".") then
    filename = filename:gsub(config.project_path.."\\","")
  end
  local n = 0
  for sep in filename:gmatch("[\\/]") do
    n = n + 1
  end
  return n
end

local TreeView = View:extend()

TreeView.id = 2
TreeView.name = "treeview"
TreeView.icon = ""
TreeView.module = "treeview"
TreeView.config = {}
TreeView.split_dir = "down"
TreeView.split_node = "Panels"
TreeView.command = nil

function TreeView:new()
  TreeView.super.new(self)
  TreeViewData.view = self
  self.scrollable = true
  self.visible = true
  self.init_size = true
  self.cache = {}

  self.size.x = config.treeview_size
  self.item_count = 0
  TreeViewData.height = self.size.y
end


function TreeView:get_item_height()
  return style.font:get_height() + style.padding.y
end


function TreeView:get_scrollable_size()
  return self:get_item_height() * self.item_count
end


function TreeView:get_cached(item)
  local t = self.cache[item.filename]
  if not t then
    t = {}
    t.filename = item.filename
    t.abs_filename = system.absolute_path(item.filename)
    t.name = t.filename:match("[^\\/]+$")
    t.depth = get_depth(t.filename)
    t.type = item.type
    self.cache[t.filename] = t
  end
  return t
end

function TreeView:get_name()
  return "Project"
end

function TreeView:check_cache()
  -- invalidate cache's skip values if project_files has changed
  if core.project_files ~= self.last_project_files then
    for _, v in pairs(self.cache) do
      v.skip = nil
    end
    self.last_project_files = core.project_files
  end
end

function TreeView:each_item()
  return coroutine.wrap(function()
    self:check_cache()
    local ox, oy = self:get_content_offset()
    local y = oy + style.padding.y
    local w = self.size.x
    local h = self:get_item_height()
    local i = 1
    while i <= #core.project_files do
      local item = core.project_files[i]
      local cached = self:get_cached(item)

      coroutine.yield(cached, ox, y, w, h)
      y = y + h
      i = i + 1

      if not cached.expanded then
        if cached.skip then
          i = cached.skip
        else
          local depth = cached.depth
          while i <= #core.project_files do
            local filename = core.project_files[i].filename
            if get_depth(filename) <= depth then break end
            i = i + 1
          end
          cached.skip = i
        end
      end
    end
  end)
end

function TreeView:on_mouse_moved(px, py, dx, dy)
  self.hovered_item = nil
  for item, x,y,w,h in self:each_item() do
    if px > x and py > y and px <= x + w and py <= y + h then
      self.hovered_item = item
      break
    end
  end
end

function TreeView:on_mouse_released(button, x, y)
  if not self.hovered_item then
    return
  elseif self.hovered_item.type == "dir" then
    self.hovered_item.expanded = not self.hovered_item.expanded
  else
    core.try(function()
      core.root_view:open_doc(core.open_doc(self.hovered_item.filename))
    end)
  end
end

function TreeView:update()

  -- We have to maintain width to the parent panel!
  self.size.x = TreeViewData.width
  if(self.size.y > 0) then TreeViewData.last_height = self.size.y end

  -- if(self.init_size == true and self.size.x < self.target_width) then
  --   self:move_towards(self.size, "x", self.target_width, 0.5, function() self.init_size = false end)
  -- else
  --   self.target_width = self.size.x -- Update for border movement
  -- end

  TreeView.super.update(self)
end

function TreeView:show_panel(visible)
  self.visible = visible 
end

function TreeView:draw()
  self:draw_background(style.background2)
  if(self.visible == false) then return end

  local icon_width = style.icon_font:get_width("D")
  local spacing = style.font:get_width(" ") * 2

  local doc = core.active_view.doc
  local active_filename = doc and system.absolute_path(doc.filename or "")

  self.item_count = 0
  for item, x,y,w,h in self:each_item() do
    self.item_count = self.item_count + 1
    local color = style.text

    -- hovered item background
    if item == self.hovered_item then
      renderer.draw_rect(x, y, w, h, style.line_highlight)
    end

    -- highlight active_view doc
    if item.abs_filename == active_filename then
      color = style.editor_fileselect
      renderer.draw_rect(x, y, w, h, style.editor_background)
    end

    -- icons
    x = x + item.depth * style.padding.x + style.padding.x
    if item.type == "dir" then
      local icon1 = item.expanded and "-" or "+"
      local icon2 = item.expanded and "D" or "d"
      common.draw_text(style.icon_font, color, icon1, nil, x, y, 0, h)
      x = x + style.padding.x
      common.draw_text(style.icon_font, color, icon2, nil, x, y, 0, h)
      x = x + icon_width
    else
      x = x + style.padding.x
      common.draw_text(style.icon_font, color, "f", nil, x, y, 0, h)
      x = x + icon_width
    end

    -- text
    x = x + spacing
    x = common.draw_text(style.font, color, item.name, nil, x, y, 0, h)
  end
  self:draw_scrollbar()
end

-- register commands and keymap
command.add(nil, {
    ["treeview:toggle"] = function()
      TreeViewData.view.visible = not TreeViewData.view.visible
      TreeViewData.height = TreeViewData.view.visible and TreeViewData.last_height or 0
      TreeViewData.init_size = true
    end,
})

keymap.add { ["ctrl+shift+1"] = "treeview:toggle" }

return TreeView
