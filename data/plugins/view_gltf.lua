local core = require "core"
local style = require "core.style"
local common = require "core.common"
local Doc = require "core.doc"
local DocView = require "core.docview"
local View = require "core.view"
local utils   = require("lua.utils")

local syntax = require "core.syntax"

local tinsert     = table.insert

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

local function draw_states(model, pos, size)
  if(model.data == nil or model.data.mesh == nil) then return end
  local color = style.background2
  renderer.draw_rect(pos.x, pos.y, 180, 100, color)

  local xpos = pos.x + 10
  local ypos = pos.y + 10
  for k,v in pairs(model.data.mesh.stats) do
    local text = string.format("%s: %s", k, tostring(v))
    local tw, th = style.font:get_width(text), style.font:get_height(text)
    common.draw_text( style.font, style.text, text, "left", xpos, ypos, tw, th)
    ypos = ypos + th
  end
end

-- Override the Doc loader - if its a png.. then load it, and make a png Image Viewer for it.
local function GLTF_load(self, filename)
  if ( find(filename, "files") ) then
    core.try(function()
      self.model = renderer.load_model(filename)
    end)
    if(self.model) then
      self.model.scale = 1.0
      self.filename = filename
      return true
    end
  end
  return nil
end

tinsert(Doc.loaders, GLTF_load)


local function GLTF_draw(self)
  if(self.doc.model) then
    self.view:draw_background(style.background)
    -- Work out aspect for image so it is always centered and correct aspect view
    local model = self.doc.model
    local doc_size = self.view.size
    local doc_pos = self.view.position

    core.try(function()
      renderer.draw_model(model, doc_pos.x, doc_pos.y, doc_size.x, doc_size.y)
      draw_states(model, doc_pos, doc_size)
    end)
    return true
  end
  return nil
end

local function GLTF_on_mouse_wheel(self, y)
  if(self.doc.model) then
    local model = self.doc.model
    model.scale = model.scale + y / 100  -- 100 should be dpi or something I think.
    return true
  end
  return nil
end

tinsert(DocView.drawers, GLTF_draw)
tinsert(DocView.on_mouse_wheels, GLTF_on_mouse_wheel)
