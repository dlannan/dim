local core      = require "core"
local common    = require "core.common"
local command   = require "core.command"
local config    = require "core.config"
local keymap    = require "core.keymap"
local style     = require "core.style"
local DocView   = require "core.docview"
local Doc       = require "core.doc"

local fmt       = string.format

-- console.lua
local M = {
    font = renderer.font.load(EXEDIR .. "/data/fonts/CascadiaMono-SemiBold.ttf", 13.5 * SCALE)
}

-- Stores all console documents
M.consoles = {}

-- Helper: create a new console doc
local function new_console(name)
    
    local ConsoleDoc = Doc:extend()    

    function ConsoleDoc:new()
        ConsoleDoc.super.new(self)
        ConsoleDoc.super.reset(self)
        self.prompt = "> "
        self.console_lines = {}
        return self
    end

    function ConsoleDoc:get_name()
        return "Console"
    end

    function ConsoleDoc:append_line(text, col)
        local last_line = #self.lines
        local psize = #self.prompt + 1
        col = col or psize

        if(tonumber(col) < psize) then col = psize end 
        ConsoleDoc.super.insert(self, last_line, col, text)
        ConsoleDoc.super.move_to(self, #self.lines, col)
        return #self.lines
    end

    -- Handle Enter key: execute command
    function ConsoleDoc:execute_current_line()
        local line = self.lines[#self.lines-1]:sub(#self.prompt + 1)
        -- Simple echo for now; you can extend to Lua evaluation
        local results = system.exec(line)

        self:write_line(fmt("[Log time]: %s \n", line))
        self:write_line(fmt("[Log time]: %s \n", results))
        self:append_line(self.prompt) 
    end

    function ConsoleDoc:insert(line, col, text)
        -- Only allow appending after the last line
        local last_line = self:append_line( text, col )
        local psize = #self.prompt + 1
        if(text == "\n") then 
            self:execute_current_line()
        end
    end

    -- Write a line to the console
    function ConsoleDoc:write_line(line)
        table.insert(self.console_lines, line)
        self:append_line(line)
        print(line)
    end


    -- Initialize prompt
    local doc = ConsoleDoc:new()
    doc:insert(1, 1, ConsoleDoc.prompt)

    return doc
end

-- Command to open a console
command.add(nil, {
    ["console:new"] = function()
        local doc = new_console("Console")
        local node = core.root_view:get_active_node()
        local view = DocView(doc)
        view.font = "console_font"
        style.console_font = M.font
        node:add_view(view)
        M.consoles[doc] = true
        return doc
    end
})

return M
