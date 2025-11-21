local core      = require "core"
local common    = require "core.common"
local command   = require "core.command"
local config    = require "core.config"
local keymap    = require "core.keymap"
local style     = require "core.style"
local DocView   = require "core.docview"
local Doc       = require "core.doc"
local utils     = require("lua.utils")

local fmt       = string.format
local tinsert   = table.insert

-- console.lua
local ConsoleData = {
    font = renderer.font.load(EXEDIR .. "/data/fonts/CascadiaMonoNF-SemiBold.ttf", 13.5 * SCALE),
    -- Stores all console documents
    consoles = {},
}

local ConsoleDoc = {}

function ConsoleDoc:new()
    local new_consoledoc = Doc:new()
    
    new_consoledoc.get_name = ConsoleDoc.get_name
    new_consoledoc.append_line = ConsoleDoc.append_line 
    new_consoledoc.execute_current_line = ConsoleDoc.execute_current_line
    new_consoledoc.insert = ConsoleDoc.insert 
    new_consoledoc.write_line = ConsoleDoc.write_line
    new_consoledoc.load = ConsoleDoc.load 

    new_consoledoc.prompt = "> "
    new_consoledoc.console_lines = {}
    style.console_font = ConsoleData.font
    return new_consoledoc
end

function ConsoleDoc:get_name()
    return self.name
end

function ConsoleDoc:append_line(text, col)
    local last_line = #self.lines
    local psize = #self.prompt + 1
    col = col or psize

    if(tonumber(col) < psize) then col = psize end
    self.redo_stack = { idx = 1 }
    local line, col = self:sanitize_position(last_line, col)
    self:raw_insert(line, col, text, self.undo_stack, system.get_time())
    self:move_to( #self.lines, col)
    return #self.lines
end

-- Handle Enter key: execute command
function ConsoleDoc:execute_current_line()
    local line = self.lines[#self.lines-1]:sub(#self.prompt + 1)
    line = line:gsub("\n", "")

    -- Simple echo for now; you can extend to Lua evaluation
    local results = system.exec(line)

    self:write_line(fmt("%s", line))
    self:append_line(results)
    self:append_line(self.prompt)
end

function ConsoleDoc:insert(line, col, text)
    -- Only allow appending after the last line
    local last_line = self:append_line( text, col )
    local psize = #self.prompt + 1
    if(text == "\n") then
        self:execute_current_line()
    end
    if(tonumber(col) < psize) then col = psize end
    self:move_to( #self.lines, col)
end

-- Write a line to the console
function ConsoleDoc:write_line(line)
    tinsert(self.console_lines, line)
--     print(line)
end

function ConsoleDoc:load(filename)
    if(string.match(filename, "^Console_")) then
        ConsoleDoc.new(self, filename)
    end
end

local ConsoleDocView = {}

-- Helper: create a new console doc
function ConsoleDocView:new()

    local new_consoledocview = utils.deepcopy(ConsoleDocView)
    local doc = ConsoleDoc:new()

    new_consoledocview.docview = DocView:new(doc)
    new_consoledocview.docview.parent = new_consoledocview
    new_consoledocview.doc = new_consoledocview.docview.doc
    new_consoledocview.view = new_consoledocview.docview.view

    new_consoledocview.doc.name = string.format("Console_%s", #ConsoleData.consoles)
    new_consoledocview.module = "data.plugins.console"
    new_consoledocview.doc:insert(1, 1, doc.prompt)

    -- Initialize prompt
    new_consoledocview.font = "console_font"
    new_consoledocview.console_id = #ConsoleData.consoles + 1
    tinsert(ConsoleData.consoles, new_consoledocview)
    return new_consoledocview
end

function ConsoleDocView:get_name()
    local id = self.console_id
    return fmt("Console_%d", id)
end

function ConsoleDocView:get_scrollable_size()
    return self.docview:get_scrollable_size()
end

function ConsoleDocView:update(...) 
    self.docview:update(...)
end

function ConsoleDocView:on_text_input(text)
    self.doc:text_input(text)
end

function ConsoleDocView:on_mouse_wheel(...)
    self.docview:on_mouse_wheel(...)
end

function ConsoleDocView:draw() 
    self.docview:draw()
end

-- Command to open a console
command.add(nil, {
    ["console:new"] = function()
        local node = core.root_view:get_active_node()
        local consoledoc = ConsoleDocView:new()
        node:add_view(consoledoc)
    end
})

return ConsoleDocView
