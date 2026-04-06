local sapp          = require("sokol_app")
local stb           = require("stb")

local hmm           = require("hmm")
local hutils        = require("hmm_utils")

local ffi           = require("ffi")

local utils         = require("lua.utils")
local dirtools      = require("tools.vfs.dirtools")

local mpv           = require('ffi.libmpv')
local uv            = require('luv')

local tinsert       = table.insert
local tremove       = table.remove

-- --------------------------------------------------------------------------------------

video_renderer      = {
    
    ready           = false,
    videos          = {},
    load_queue      = {},

    ctr             = 0,
}

-- --------------------------------------------------------------------------------------
-- Global handlers so mpv works properly

function on_mpv_events(ctx)
end

function on_video_frame_complete(ctx)
    -- if(ctx == nil) then return end
    -- local video = ffi.cast("int *", ctx)
    -- video[0] = 1
    -- print("render_frame_done.")
end

-- --------------------------------------------------------------------------------------
-- This loads video ready for playing, sets up window and doc, and holds in pause mode.
video_renderer.do_load = function(filename)

    local mpv_handle = mpv.mpv_create()
    if (mpv_handle == nil) then
        pprint("[Error] mpv context init failed")
        return
    end
    mpv.mpv_set_option_string(mpv_handle, "vo", "libmpv")
  
    if (mpv.mpv_initialize(mpv_handle) < 0) then
        pprint("[Error] mpv init failed")
        return 
    end
  
    mpv.mpv_request_log_messages(mpv_handle, "debug")
  
    video_renderer.param_advanced = ffi.new("int[1]", { 1 })
    video_renderer.param_api =  ffi.new("char[2]", "sw")
    local params = ffi.new("mpv_render_param[3]", {
        { mpv.MPV_RENDER_PARAM_API_TYPE,video_renderer.param_api },
        -- // Tell libmpv that you will call mpv_render_context_update() on render
        -- // context update callbacks, and that you will _not_ block on the core
        -- // ever (see <libmpv/render.h> "Threading" section for what libmpv
        -- // functions you can call at all when this is active).
        -- // In particular, this means you must call e.g. mpv_command_async()
        -- // instead of mpv_command().
        -- // If you want to use synchronous calls, either make them on a separate
        -- // thread, or remove the option below (this will disable features like
        -- // DR and is not recommended anyway).
        { mpv.MPV_RENDER_PARAM_ADVANCED_CONTROL, video_renderer.param_advanced },
        {0}
    })
  
    local pixels = ffi.new("unsigned int[?]", 1024 * 1024)
    ffi.fill(pixels, 1024 * 1024 * 4, 0x7f)
    local sw_size = ffi.new("int[2]", {1024, 1024})
    local sw_format = ffi.new("char[4]", "0bgr")
    local sw_stride = ffi.new("int[1]", {1024 * 4})
    local render_params = ffi.new("mpv_render_param[5]", {    
        {mpv.MPV_RENDER_PARAM_SW_SIZE, sw_size},
        {mpv.MPV_RENDER_PARAM_SW_FORMAT, sw_format},
        {mpv.MPV_RENDER_PARAM_SW_STRIDE, sw_stride},
        {mpv.MPV_RENDER_PARAM_SW_POINTER, pixels},
        {0}
    })

    local temp = ffi.new("intptr_t [1]", {0})
    local mpv_rd_ptr = ffi.new("struct mpv_render_context *[1]", { ffi.cast("struct mpv_render_context *", temp) })
    local res = mpv.mpv_render_context_create(mpv_rd_ptr, mpv_handle, params)
    if(res < 0) then 
        pprint("[Error] mpv failed to initialize mpv render context: ", res)
        return
    end
    local mpv_rd = mpv_rd_ptr[0]

    local ctx = ffi.new("int[1]", {0})
    mpv.mpv_render_context_set_update_callback(mpv_rd, on_video_frame_complete, nil)

    -- mpv.mpv_set_wakeup_callback(mpv_handle, on_mpv_events, nil)
  
    pprint(filename, mpv_rd_ptr[0], mpv_rd)
    -- // When there is a need to call mpv_render_context_update(), which can
    -- // request a new frame to be rendered.
    -- // (Separate from the normal event handling mechanism for the sake of
    -- //  users which run OpenGL on a different thread.)
  
    -- local video_cmd = string.format("%s%s", videos.player.path, videos.player.exec)
    -- -- Add "--pause" to start paused! Maybe make option?
    -- local params = { "--script=start_video.lua", string.format(videos.player.params, filename) }
    -- local handle, pid = uv.spawn( video_cmd, { args = params, 
    --     stdio = { 0, 1, 2 }  -- This is the default stdin, stdout, stderr pipe handle ids.
    -- }, function(code, signal) -- on exit
    --     pprint(string.format("[Process] Video Player: %s Exit code: %d Exit signal: %d", video_cmd, code, signal))
    -- end)
    -- pprint("[Process] Video Player Spawned: ", handle, " PID: "..pid)
  
    -- // Play this file.
    local cmd = ffi.new("const char *[3]", {"loadfile", filename, nil})
    mpv.mpv_command_async(mpv_handle, 0, cmd)

    local video = { 
        handle        = mpv_handle, 
        mpv_rd        = mpv_rd, -- store this in case gc collects it!!
        reader        = mpv_rd_ptr, 
        cmd           = cmd, 
        params        = params, 
        render_params = render_params, 
        pixels        = pixels,
        render_frame  = 0, 
        ctx           = ctx,
    }
    video_renderer.videos[filename] = video
end

-- --------------------------------------------------------------------------------------

video_renderer.load = function(filename)
    tinsert(video_renderer.load_queue, filename)
end

-- --------------------------------------------------------------------------------------

video_renderer.video_render_update = function(video)

    if(video.ctx[0] == 1) then 
        video.ctx[0] = 0
    end

    local flags = mpv.mpv_render_context_update(video.reader[0])
    if (bit.band(flags, mpv.MPV_RENDER_UPDATE_FRAME) > 0) then
        -- print(string.format("flags: 0x%02x   0x%02x", flags, mpv.MPV_RENDER_UPDATE_FRAME))
        -- print("[Info] Video need redraw frame.")
        mpv.mpv_render_context_render(video.reader[0], video.render_params);
        video.ctx[0] = 1
    end
end
  
-- --------------------------------------------------------------------------------------

video_renderer.render_videos = function (renderer)

    if(renderer.ready == false) then return end

    for k,v in ipairs(video_renderer.load_queue) do 
        video_renderer.do_load(v)
    end
    video_renderer.load_queue = {}

    for k,v in pairs(video_renderer.videos) do 
        if(v) then 
            video_renderer.video_render_update(v) 
            if(v.closing) then 
                mpv.mpv_render_context_free(v.reader[0])
                mpv.mpv_destroy(v.handle)
                video_renderer.videos[k] = nil
            end
        end         
    end
end

-- --------------------------------------------------------------------------------------

video_renderer.init = function()
    video_renderer.ready = true
end

-- --------------------------------------------------------------------------------------

video_renderer.close_video = function( filename )

    local video = video_renderer.videos[filename]
    if(video) then 
        video.closing = true 
    end
end

-- --------------------------------------------------------------------------------------
