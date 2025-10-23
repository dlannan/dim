local core = require "core"
local style = require "core.style"
local common = require "core.common"
local Doc = require "core.doc"
local DocView = require "core.docview"
local StatusView = require "core.statusview"

local syntax = require "core.syntax"

local images = {
  files = { "%.png$", "%.jpg$", "%.jpeg$", "%.tga$", "%.gif$" },
  file_types = { "png", "jpg", "jpeg", "tga", "gif" },
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
  local idx = find(filename, "files")
  if ( idx ) then 
    local image, image_info = renderer.load_image(filename)
    if(image == nil) then 
      original_doc_load(self, filename)
    else
      self.image = { nk_image = image, info = image_info, zoom = 1.0, itype = images.file_types[idx] }
      self.filename = filename
    end
  else
    original_doc_load(self, filename)
  end
end

local original_docview_draw = DocView.draw

DocView.draw = function(self)
  if(self.doc.image) then 
    self:draw_background(style.background)
    -- Work out aspect for image so it is always centered and correct aspect view
    local img = self.doc.image
    local image_aspect = img.info[0].width / img.info[0].height
    local doc_size = self.size
    local doc_pos = self.position

    local doc_width,  doc_height = doc_size.x * img.zoom, doc_size.y * img.zoom
    local doc_aspect = doc_width / doc_height
    local scaled_width, scaled_height

    -- If the image is wider than the document
    if image_aspect > doc_aspect then
        -- Scale by height to preserve aspect ratio
        scaled_height = doc_height
        scaled_width = scaled_height * image_aspect
    else
        -- If the image is taller or has the same aspect ratio, scale by width
        scaled_width = doc_width
        scaled_height = scaled_width / image_aspect
    end

    if scaled_width > doc_width then
      scaled_width = doc_width
      scaled_height = scaled_width / image_aspect
    elseif scaled_height > doc_height then
      scaled_height = doc_height
      scaled_width = scaled_height * image_aspect
    end

    local x, y = doc_pos.x, doc_pos.y
    if scaled_width < doc_width then
        x = (doc_width - scaled_width) / 2 + doc_pos.x
    end
    if scaled_height < doc_height then
        y = (doc_height - scaled_height) / 2 + doc_pos.y
    end

    renderer.draw_image(img.nk_image, x, y, scaled_width, scaled_height)
  else
    original_docview_draw(self)
  end
end

local get_items = StatusView.get_items

function StatusView:get_items()
  local dv = core.active_view
  if(not dv.doc) then 
    return get_items(self)
  end

  local img = dv.doc.image

  if not img then
    return get_items(self)
  end
  local left, right = get_items(self)

  local itype, w, h = img.itype, img.info[0].width, img.info[0].height

  local t = {
    style.font, style.dim, self.separator2,
    style.text, itype,
    style.font, style.dim, " > ",
    style.text, w,
    style.text, " x ",
    style.text, h
  }
  for _, item in ipairs(t) do
    table.insert(right, item)
  end

  return left, right
end