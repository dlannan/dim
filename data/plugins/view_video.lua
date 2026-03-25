local core = require "core"
local style = require "core.style"
local common = require "core.common"
local Doc = require "core.doc"
local DocView = require "core.docview"
local StatusView = require "core.statusview"
local utils   = require("lua.utils")
local syntax = require "core.syntax"
local utils   = require("lua.utils")

local tinsert   = table.insert

local videos = {
  files = { "%.mp4$", "%.mkv$", "%.mov$" },
  file_types = { "mp4", "mkv", "mov" },
}

local function find(string, field)
  for i, v in ipairs(videos.files) do
    if common.match_pattern(string, v or {}) then
      return i
    end
  end
  return nil
end

-- Override the Doc loader - if its a png.. then load it, and make a png Video Viewer for it.
local videodoc_load = function(self, filename)
  local idx = find(filename, "files")
  if ( idx ) then 
    local video, video_info = renderer.load_video(filename)
    if(video) then 
      self.video = { nk_video = video, info = video_info, zoom = 1.0, itype = videos.file_types[idx] }
      self.filename = filename
      return true
    end
  end
  return nil
end

tinsert(Doc.loaders, videodoc_load)

local function videodocview_draw(self)
  if(self.doc.video) then 
    self.view:draw_background(style.background)
    -- Work out aspect for video so it is always centered and correct aspect view
    local img = self.doc.video
    local video_aspect = img.info[0].width / img.info[0].height
    local doc_size = self.view.size
    local doc_pos = self.view.position

    local doc_width,  doc_height = doc_size.x * img.zoom, doc_size.y * img.zoom
    local doc_aspect = doc_width / doc_height
    local scaled_width, scaled_height

    -- If the video is wider than the document
    if video_aspect > doc_aspect then
        -- Scale by height to preserve aspect ratio
        scaled_height = doc_height
        scaled_width = scaled_height * video_aspect
    else
        -- If the video is taller or has the same aspect ratio, scale by width
        scaled_width = doc_width
        scaled_height = scaled_width / video_aspect
    end

    if scaled_width > doc_width then
      scaled_width = doc_width
      scaled_height = scaled_width / video_aspect
    elseif scaled_height > doc_height then
      scaled_height = doc_height
      scaled_width = scaled_height * video_aspect
    end

    local x, y = doc_pos.x, doc_pos.y
    if scaled_width < doc_width then
        x = (doc_width - scaled_width) / 2 + doc_pos.x
    end
    if scaled_height < doc_height then
        y = (doc_height - scaled_height) / 2 + doc_pos.y
    end

    renderer.draw_video(img.nk_video, x, y, scaled_width, scaled_height)
    return true 
  end
  return nil
end

tinsert(DocView.drawers, videodocview_draw)

local VideoStatusView = core.root_view:get_named_node("StatusView")

local function videostatusview_get_items(self)
  local dv = core.active_view
  if(not dv.doc) then 
    return DocView.get_items(self)
  end

  local img = dv.doc.video

  if not img then
    return DocView.get_items(self)
  end
  local left, right = DocView.get_items(self)

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

VideoStatusView.get_items = videostatusview_get_items