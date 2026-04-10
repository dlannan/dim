local core = require "core"
local style = require "core.style"
local common = require "core.common"
local Doc = require "core.doc"
local DocView = require "core.docview"
local StatusView = require "core.statusview"
local utils   = require("lua.utils")
local syntax = require "core.syntax"
local utils   = require("lua.utils")

sg              = require("sokol_gfx")
sg              = require("sokol_nuklear")
local nk        = sg

local mpv       = require('ffi.libmpv')

local tinsert   = table.insert

local videos = {

  files       = { "%.mp4$", "%.mkv$", "%.mov$" },
  file_types  = { "mp4", "mkv", "mov" },

  player      = {
    path        = "./data/plugins/view_video/",
    exec        = "mpv.exe",          -- Set your preferred video player tool
    params      = "%s",       -- Params to run (will doc params as I go)
    windowed    = false,          -- open in separate windon or embedded doc (defaults to embedded)
  },
}

local function find(str, field)
  for i, v in ipairs(videos.files) do
    if common.match_pattern(str, v or {}) then
      return i
    end
  end
  return nil
end

-- Override the Doc loader - if its a mp4.. then load it, and make a Video Viewer for it.
local videodoc_load = function(self, filename)
  local idx = find(filename, "files")
  if ( idx ) then
    video_renderer.load(filename)
    self.video = { 
        vtype = videos.file_types[idx], 
        filename = filename
    }
    self.filename = filename   
    -- Notify mpv the video is closing!
    self.on_close = function(self) 
        video_renderer.close_video(self.filename)
    end
    return true
  end
  return nil
end

tinsert(Doc.loaders, videodoc_load)

local function videodocview_draw(self)

  if(self.doc.video) then 
    self.view:draw_background(style.background)
    local video = self.doc.video
    local video_aspect      = 1.0
    local doc_size          = self.view.size
    local doc_pos           = self.view.position

    local doc_width,  doc_height = doc_size.x, doc_size.y
    local doc_aspect = doc_width / doc_height
    local scaled_width, scaled_height

    video.frame = video_renderer.get_frame(self.doc.filename)
    if(video.frame and video.nk_img == nil) then 

        local sg_img_desc = ffi.new("sg_image_desc[1]", {})

        -- sg_img_desc[0].render_target = true
        sg_img_desc[0].width        = 1024
        sg_img_desc[0].height       = 1024
        sg_img_desc[0].pixel_format = sg.SG_PIXELFORMAT_RGBA8
        sg_img_desc[0].sample_count = 1
        sg_img_desc[0].label        = "video-image"
        sg_img_desc[0].usage        = sg.SG_USAGE_STREAM
        
        video.pixels = ffi.new("unsigned int[?]", 1024 * 1024)

        sg_img_desc[0].data.subimage[0][0].ptr = video.pixels
        sg_img_desc[0].data.subimage[0][0].size = 1024 * 1024 * 4
        video.sg_img_desc           = sg_img_desc

        video.sg_img = sg.sg_make_image(video.sg_img_desc)
        -- // create a sokol-nuklear image object which associates an sg_image with an sg_sampler
        video.img_desc              = ffi.new("snk_image_desc_t[1]")
        video.img_desc[0].image     = video.sg_img

        video.snk_img               = nk.snk_make_image(video.img_desc)
        local nk_hnd                = nk.snk_nkhandle(video.snk_img)
        video.nk_img                = nk.nk_image_handle(nk_hnd)

        video_renderer.set_frame_buffer(video.filename, video.pixels)
    end      

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

    if(video.nk_img and video.frame and video.frame.frame_ready == true) then

        -- sg.sg_update_image(video.sg_img, video.sg_img_desc[0].data)
        -- local nk_hnd = nk.snk_nkhandle(video.snk_img)
        -- video.nk_img = nk.nk_image_handle(nk_hnd)
        renderer.draw_image(video.nk_img, x, y, scaled_width, scaled_height)
    end
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