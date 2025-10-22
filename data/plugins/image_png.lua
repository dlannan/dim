local core = require "core"
local style = require "core.style"
local command = require "core.command"
local common = require "core.common"
local config = require "core.config"
local View = require "core.view"
local Doc = require "core.doc"

local syntax = require "core.syntax"

local images = {
  files = { "%.png$" },
}

local function find(string, field)
  for i, v in ipairs(images.files) do
    if common.match_pattern(string, v or {}) then
      return i
    end
  end
  return nil
end

-- Override the Doc loader - if its a png.. then load it, and make a png Image Viewer for it.
Doc.load = function(self, filename)
  if ( find(filename, "files") ) then 
    local fp = assert( io.open(filename, "rb") )
    self.image = 

    fp:close()
  else
    local fp = assert( io.open(filename, "rb") )
    self:reset()
    self.filename = filename
    self.lines = {}
    for line in fp:lines() do
      if line:byte(-1) == 13 then
        line = line:sub(1, -2)
        self.crlf = true
      end
      table.insert(self.lines, line .. "\n")
    end
    if #self.lines == 0 then
      table.insert(self.lines, "\n")
    end
    fp:close()
    self:reset_syntax()
  end
end

local ImageView = View:extend()

function ImageView:new()
  ImageView.super.new(self)
end

function ImageView:load(filename)
print(filename)
  ImageView.super.load(self, filename)
end

function ImageView:get_name()
  return "Image View"
end

function ImageView:update_fonts()
  return self.font
end

function ImageView:update()
  if self.image_ready then
    core.redraw = true
  end
  ImageView.super.update(self)
end


function ImageView:draw()
  self:draw_background(style.background)
  local x, y = self.position.x, self.position.y
  local w, h = self.size.x, self.size.y
  -- local _, y = common.draw_text(self.time_font, style.text, self.time_text, "center", x, y, w, h)
  -- local th = self.date_font:get_height()
  -- common.draw_text(self.date_font, style.dim, self.date_text, "center", x, y, w, th)
end


command.add(nil, {
  ["image:open"] = function()
    local node = core.root_view:get_active_node()
    node:add_view(ImageView())
  end,
})


return ImageView