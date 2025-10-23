local core = require "core"
local style = require "core.style"
local common = require "core.common"
local Doc = require "core.doc"
local DocView = require "core.docview"

local syntax = require "core.syntax"

local images = {
  files = { "%.png$", "%.jpg$", "%.jpeg$", "%.tga$", "%.gif$" },
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
local original_doc_load = Doc.load

Doc.load = function(self, filename)
  if ( find(filename, "files") ) then 
    self.image = renderer.load_image(filename)
  else
    original_doc_load(self, filename)
  end
end

local original_docview_draw = DocView.draw

DocView.draw = function(self)
  if(self.doc.image) then 
    self:draw_background(style.background)
    local x, y = self.position.x, self.position.y
    local w, h = self.size.x, self.size.y
    renderer.draw_image(self.doc.image, x, y, w, h)
  else
    original_docview_draw(self)
  end
end
