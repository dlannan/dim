local core = require "core"
local style = require "core.style"
local common = require "core.common"
local Doc = require "core.doc"
local DocView = require "core.docview"

local syntax = require "core.syntax"

local images = {
  files = { "%.glb$", "%.gltf$" },
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
    local gltf = renderer.load_model(filename)
    if(gltf == nil) then 
      original_doc_load(self, filename)
    else
      self.model = { model = gltf, model_type = "gltf", scale = 1.0 }
      self.filename = filename
    end
  else
    original_doc_load(self, filename)
  end
end

local original_docview_draw = DocView.draw

DocView.draw = function(self)
  if(self.doc.model) then 
    self:draw_background(style.background)
    -- Work out aspect for image so it is always centered and correct aspect view
    local model = self.doc.model
    local doc_size = self.size
    local doc_pos = self.position

    renderer.draw_model(model, doc_pos.x, doc_pos.y, doc_size.x, doc_size.y)
  else
    original_docview_draw(self)
  end
end
