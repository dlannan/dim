local core          = require "core"
local style         = require "core.style"
local common        = require "core.common"
local Doc           = require "core.doc"
local DocView       = require "core.docview"
local View          = require "core.view"
local utils         = require("lua.utils")

local syntax        = require "core.syntax"

local tinsert       = table.insert

local nk            = sg
local cammgr        = require("lua.engine.camera_manager")
local bins 	        = require("lua.geometry.bins")

local threed_models = {
  files = { "%.glb$", "%.gltf$" },
  count = 0,
}

local function find(string)
  for i, v in ipairs(threed_models.files) do
    if common.match_pattern(string, v or {}) then
      return i
    end
  end
  return nil
end

local function draw_stats(model, pos, size)
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
  if ( find(filename) ) then
    core.try(function()
      threed_models.count = threed_models.count + 1
      local bin_target = bins.BTYPE_OPAQUE + threed_models.count

      local params = {
        bin_target = bin_target,
        on_load = function(model)
          local cam_name = "gltf_cam_"..model.name
          -- Should have some sort of default configh ere
          local newcam = cammgr.add(cam_name, 60.0, 1, 0.01, 1000.0) 
          local clear_color = { 0.118, 0.118, 0.118, 0.0 }
          bins.add_offscreen(newcam, clear_color, bin_target, true)
          model.camera = cam_name
          model.bin_target = bin_target
        end
      }
      self.model = renderer.load_model(filename, params)
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


local function GLTF_on_mouse_moved(self, x, y, dx, dy)
  self.hovered = true
end

local function GLTF_on_hide(doc)
  if(doc.model) then
    local model = doc.model
    if(doc.drawn == true) then 
      renderer.hide_model(model) 
      doc.drawn = false 
    end
  end
end

-- NOTE: These draw routines only fire on updates needed for the UI window. 
--       THEY DO NOT UPDATE PER FRAME RENDER!! 
local function GLTF_draw(self)

  -- print("drawing....", debug.traceback())
  -- if(self.doc.model) then  pprint( self.doc.model ) end
  if(self.doc.model and self.doc.model.loaded == true) then

    if(self.view and self.mouse_mapped == nil) then 
      self.view.on_mouse_moved = GLTF_on_mouse_moved
      self.mouse_mapped = true
    end
  
    self.view:draw_background(style.threed_background)
    -- Work out aspect for image so it is always centered and correct aspect view
    local model = self.doc.model
    local doc_size = self.view.size
    local doc_pos = self.view.position
    self.doc.on_hide = GLTF_on_hide

    if(self.view.hovered) then 
      system.set_cursor("arrow", { 
          position = { x = doc_pos.x, y = doc_pos.y }, 
          size = { x = 1.0, y = 1.0 }
      })
      renderer.set_cursor()
      self.view.hovered = nil
    end

    core.try(function()
      renderer.draw_model(model, doc_pos.x, doc_pos.y, doc_size.x, doc_size.y)
      -- local info = sg.sg_image_info(renderer.color_img)
      local camera = cammgr.get(model.data.camera)
      if(camera and camera.color_image) then
        renderer.draw_image( camera.color_image, doc_pos.x, doc_pos.y, doc_size.x, doc_size.y)
      end
      draw_stats(model, doc_pos, doc_size)
      self.doc.drawn = true
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
