local core      = require "core"
local common    = require "core.common"
local command   = require "core.command"
local config    = require "core.config"
local keymap    = require "core.keymap"
local style     = require "core.style"
local View      = require "core.view"

local fmt       = string.format
local tinsert   = table.insert

local ffi       = require("ffi")
local utils     = require("lua.utils")

-- Some platform specific calls for searching:
local search_case_insensitive
local search_case_sensitive

if(ffi.os == "Windows") then

    search_case_sensitive = [[findstr /S /R "%s" %s]]
    search_case_insensitive = [[findstr /I /S /R "%s" %s]]
else


end

local function get_search( search_term, search_path )
    search_path = search_path or "./*"
    if(search_term == nil or string.len(search_term) == 0) then return {} end
    local results =system.exec( fmt(search_case_insensitive, search_term, search_path))
    local lines = utils.csplit(results, "\n")
    local items = {}
    for k,v in ipairs(lines) do
        item = { filename = v, name = filename, id = k }
        tinsert(items, item)
    end
    return items
end

-- console.lua
local SearchFilesData = {
    font            = style.font,
    search_files    = {}, -- most recent search results
    searched        = {}, -- maybe cache searches TBD
    child           = nil,
}

local SearchFilesView = {}

SearchFilesView.id = 4
SearchFilesView.name = "search"
SearchFilesView.icon = ""
SearchFilesView.module = "search"
SearchFilesView.config = {}
SearchFilesView.split_dir = "down"
SearchFilesView.split_node = "Panels"
SearchFilesView.locked = true
SearchFilesView.command = nil

-- Helper: create a new console doc
function SearchFilesView:new()
    local new_searchfilesview = utils.deepcopy(SearchFilesView)
    new_searchfilesview.view = View:new()
    new_searchfilesview.view.scrollable = true
    new_searchfilesview.visible = false
    new_searchfilesview.init_size = true
    new_searchfilesview.search_id = #SearchFilesData.searched
    new_searchfilesview.cache = {}

    -- Initialize font
    SearchFilesView.font = SearchFilesData.font
    return new_searchfilesview
end

function SearchFilesView:get_cached(item)
    local t = self.cache[item.filename]
    if not t then
      t = {}
      t.filename = item.filename
      t.abs_filename = system.absolute_path(item.filename)
      t.name = t.filename:match("[^\\/]+$")
      self.cache[t.filename] = t
    end
    return t
end

function SearchFilesView:get_item_height()
    return style.font:get_height() + style.padding.y
end

function SearchFilesView:get_name()
    return "SearchFiles"
end

function SearchFilesView:check_cache()
    -- invalidate cache's skip values if project_files has changed
    if SearchFilesData.search_files ~= self.last_search_files then
      for _, v in pairs(self.cache) do
        v.skip = nil
      end
      self.last_search_files = SearchFilesData.search_files
    end
end

function SearchFilesView:each_item()
    return coroutine.wrap(function()
        self:check_cache()
        local ox, oy = self.view:get_content_offset()
        local y = oy + style.padding.y
        local w = self.view.size.x
        local h = self:get_item_height()

        local i = 1
        while i <= #SearchFilesData.search_files do
            local item = SearchFilesData.search_files[i]
            local cached = self:get_cached(item)

            coroutine.yield(cached, ox, y, w, h)
            y = y + h
            i = i + 1

            if not cached.expanded then
                if cached.skip then
                i = cached.skip
                else
                local depth = cached.depth
                while i <= #SearchFilesData.search_files do
                    local filename = SearchFilesData.search_files[i].filename
                    if get_depth(filename) <= depth then break end
                    i = i + 1
                end
                cached.skip = i
                end
            end
        end
    end)
end

function SearchFilesView:on_mouse_moved(px, py, dx, dy)
    self.hovered_item = nil
    for item, x,y,w,h in self:each_item() do
        if px > x and py > y and px <= x + w and py <= y + h then
        self.hovered_item = item
        break
        end
    end
end

function SearchFilesView:on_mouse_pressed(button, x, y)
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

function SearchFilesView:update()
    if(self.visible == false) then return end
    self.view.size.y = style.font:get_height() + style.padding.y * 2
    -- if(self.visible == true) then
    --     self.size.x = self.width
    --     self.size.y = 200
    -- else
    --     self.size.x = 0
    --     self.size.y = 0
    -- end
    self.view:update()
end

function SearchFilesView:draw()

    if(self.visible == false) then return end
    self.view:draw_background(style.background2)

    local icon_width = style.icon_font:get_width("D")
    local spacing = style.font:get_width(" ") * 2

    local doc = core.active_view.view.doc
    local active_filename = doc and system.absolute_path(doc.filename or "")

    for item, x,y,w,h in self:each_item() do
        local color = style.text

        -- highlight active_view doc
        if item.abs_filename == active_filename then
            color = style.accent
        end

        -- hovered item background
        if item == self.hovered_item then
            renderer.draw_rect(x, y, w, h, style.line_highlight)
            color = style.accent
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
end

-- Command to toggle file search panel
command.add(nil, {
    ["searchfiles:toggle"] = function()
        local node = core.root_view:get_named_node("SearchFiles")
        local view = node.active_view
        view.visible = not view.visible
    end
})

keymap.add { ["ctrl+shift+f"] = "searchfiles:toggle" }


return SearchFilesView
