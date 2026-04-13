

-- -----------------------------------------------------------------------------------------

require "core.strict"

local ffi           = require("ffi")
local bit           = require("bit")
local uv            = require("luv")
local tinsert       = table.insert

local common        = require "core.common"
local config        = require "core.config"

local utils         = require("lua.utils")
local dirtools      = require("tools.vfs.dirtools")

-- local mpv           = require('ffi.libmpv')
local msgpack       = require "lua.msgpack"
local mputils       = require "lua.msgpack-utils"

local tinsert       = table.insert
local tremove       = table.remove

local PATHSEP = nil

-- --------------------------------------------------------------------------------------

local video_mgr      = {
    
    running         = false,
    videos          = {},
    frames          = {},

    ctr             = 0,
    input_writer_fd = nil,
    output_writer   = nil,

    cmd             = nil,
}

-- --------------------------------------------------------------------------------------
-- Global handlers so mpv works properly

local function on_mpv_events(ctx)
end

-- --------------------------------------------------------------------------------------
-- This loads video ready for playing, sets up window and doc, and holds in pause mode.
video_mgr.do_load = function(filename)

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
  
    video_mgr.param_advanced = ffi.new("int[1]", { 1 })
    video_mgr.param_api =  ffi.new("char[2]", "sw")
    local params = ffi.new("mpv_render_param[3]", {
        { mpv.MPV_RENDER_PARAM_API_TYPE,video_mgr.param_api },
        -- // Tell libmpv that you will call mpv_render_context_update() on render
        -- // context update callbacks, and that you will _not_ block on the core
        -- // ever (see <libmpv/render.h> "Threading" section for what libmpv
        -- // functions you can call at all when this is active).
        -- // In particular, this means you must call e.g. mpv_command_async()
        -- // instead of mpv_command().
        -- // If you want to use synchronous calls, either make them on a separate
        -- // thread, or remove the option below (this will disable features like
        -- // DR and is not recommended anyway).
        { mpv.MPV_RENDER_PARAM_ADVANCED_CONTROL, video_mgr.param_advanced },
        {0}
    })
  
    local pixels = ffi.new("unsigned int[?]", 1024 * 1024)
    ffi.fill(pixels, 1024 * 1024 * 4, 0xff)
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
    -- This makes a uid that tells the handler what filename was being processed
    local ctx = ffi.new("int[1]", { 0 })

    -- mpv.mpv_set_wakeup_callback(mpv_handle, function(ctx)
    --     print("wakeup")
    -- end, ctx)
    
    -- pprint(filename, mpv_handle, mpv_rd, ctx[0])

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
  
    local cmd = ffi.new("const char *[3]", { "loadfile",  ffi.string(filename), nil})
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
        next_frame    = true,  -- Need to kick of the first frame from here
    }
    video_mgr.videos[filename] = video

    mpv.mpv_render_context_set_update_callback(mpv_rd, function(ctx)
        -- print("update")
        local ready = ffi.cast("int *", ctx)
        ready[0]  = 1
    end, ctx)

    -- // Play this file.
    local err = mpv.mpv_command_async(mpv_handle, 0, cmd)
    if(err < 0) then print("[libmpv] Error: ", ffi.string(mpv.mpv_error_string(err))) end
    -- mpv.mpv_command(mpv_handle, cmd)
end

-- --------------------------------------------------------------------------------------

video_mgr.load = function(filename)
    if(filename) then 
        -- video_mgr.do_load(filename)
    end
end 

-- --------------------------------------------------------------------------------------

video_mgr.video_render_update = function(video)

    local flags = mpv.mpv_render_context_update(video.reader[0])
    if (bit.band(flags, mpv.MPV_RENDER_UPDATE_FRAME) > 0) then
        -- print(string.format("flags: 0x%02x   0x%02x", flags, mpv.MPV_RENDER_UPDATE_FRAME))
        -- print("[Info] Video need redraw frame.")
        local res = mpv.mpv_render_context_render(video.reader[0], video.render_params)
        if(res < 0) then 
            pprint("[libmpv] Error: ", res) -- , ffi.string(mpv.mpv_error_string(res)))
            video.closing = true -- close broken videos
        end
    end
end

-- --------------------------------------------------------------------------------------

video_mgr.render_videos = function()

    -- Remove closing videos first (so they arent processed)
    for k,v in pairs(video_mgr.videos) do 
        if(v) then 
            video_mgr.video_render_update(v) 
            if(v.closing) then 
                mpv.mpv_render_context_free(v.reader[0])
                mpv.mpv_destroy(v.handle)
                video_mgr.videos[k] = nil
            end
        end  
    end

    -- Process incoming frames so they can be sent
    for k,v in pairs(video_mgr.videos) do 
        if(v) then 
            if(v.ctx[0] == 1) then
                local frame = video_mgr.frames[k] or { filename = k }
                frame.data = ffi.string(v.pixels, 1024 * 1024 * 4)
                video_mgr.frames[k] = frame
                v.ctx[0] = 0
            end
        end 
    end
end

-- --------------------------------------------------------------------------------------

video_mgr.next_frame = function( filename )

    local video = video_mgr.videos[filename]
    if(video) then 
        if(video) then video.next_frame = true  end
    end
end

-- --------------------------------------------------------------------------------------

video_mgr.close_video = function( filename )

    local video = video_mgr.videos[filename]
    if(video) then video.closing = true end
end

--------------------------------------------------------------------------------------------------

local function on_command(data)

    if(data.cmd == "open" and data.filename) then 
        video_mgr.load(data.filename)
    end 
    if(data.cmd == "close" and data.filename) then 
        video_mgr.close_video(data.filename)
    end
    if(data.cmd == "ack" and data.filename) then 
        video_mgr.next_frame(data.filename)
    end
end

--------------------------------------------------------------------------------------------------

local function video_stream_thread()

    local redraw = false
    if video_mgr.running == true then
    
        -- Updates all videos as needed - frames will be updates to send to main proc
        video_mgr.render_videos()

        -- If there is a waiting frame.. then copy and send to main process for rendering
        for k, frame in pairs(video_mgr.frames) do
            local video = video_mgr.videos[k]
            if video and video.next_frame == true and frame.data then 
                print("sending frame: ", k)
                if(video_mgr.output_writer) then 
                    mputils.write_chunk(video_mgr.output_writer, { filename = frame.filename, data = frame.data })
                end
                video.next_frame = false
                frame.data = nil
            end
        end

        -- wait roughly 60Hz
        uv.sleep(0.010)
    end
end

--------------------------------------------------------------------------------------------------
    
local function init(input_reader_fd, output_writer)
    video_mgr.output_writer = output_writer
    -- video_mgr.input_reader_fd = input_reader
    PATHSEP = package.config:sub(1, 1)

    pprint(output_writer, uv.tcp_getpeername(output_writer))

    if(input_reader_fd) then 
        video_mgr.input_reader = assert(uv.new_tcp())
        video_mgr.input_reader:open(input_reader_fd) 

        mputils.read_chunk(video_mgr.input_reader, function(data)
            -- pprint("Recived pipe input:", data)    
            if(on_command) then on_command(data) end
        end)
    end    
    pprint(video_mgr.input_reader, uv.tcp_getpeername(video_mgr.input_reader))
    video_mgr.running = true
end

-------------------------------------------------------------------------------------------------

local function run(input_reader)
    video_stream_thread()
end

--------------------------------------------------------------------------------------------------

local function stop()
    video_mgr.running = false
end

--------------------------------------------------------------------------------------------------

return {
    init        = init,
    run         = run,
    stop        = stop,
}

--------------------------------------------------------------------------------------------------
