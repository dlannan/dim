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
    local new_consoledoc = utils.deepcopy(ConsoleDoc)
    new_consoledoc.doc = Doc:new()
    new_consoledoc.doc:reset()
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
    self.doc.insert(self, last_line, col, text)
    self.doc.move_to(self, #self.lines, col)
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
    self.doc.move_to(self, #self.lines, col)
end

-- Write a line to the console
function ConsoleDoc:write_line(line)
    table.insert(self.console_lines, line)
--     print(line)
end

function ConsoleDoc:load(filename)
    if(string.match(filename, "^Console_")) then
        ConsoleDoc.new(self, filename)
    end
end

local ConsoleDocView = utils.deepcopy(DocView)

-- Helper: create a new console doc
function ConsoleDocView:new(doc)

    doc = doc or ConsoleDoc:new()
    doc.name = string.format("Console_%s", #ConsoleData.consoles)
    self.module = "data.plugins.console"
    self.doc:new(self, doc)
    doc:insert(1, 1, doc.prompt)
    -- Initialize prompt
    ConsoleDocView.font = "console_font"
    doc.console_id = #ConsoleData.consoles + 1
    tinsert(ConsoleData.consoles, doc)
    return doc
end

function ConsoleDocView:get_name()
    local id = self.doc.console_id
    return fmt("Console_%d", id)
end

-- Command to open a console
command.add(nil, {
    ["console:new"] = function()
        local node = core.root_view:get_active_node()
        local doc = ConsoleDoc:new()
        node:add_view(ConsoleDocView:new(doc))
    end
})

return ConsoleDocView
