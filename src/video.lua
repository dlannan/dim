local sapp          = require("sokol_app")
local stb           = require("stb")

local hmm           = require("hmm")
local hutils        = require("hmm_utils")

local ffi           = require("ffi")

local utils         = require("lua.utils")
local dirtools      = require("tools.vfs.dirtools")

local msgpack       = require "lua.msgpack"
local mputils       = require "lua.msgpack-utils"

local tinsert       = table.insert
local tremove       = table.remove

-- --------------------------------------------------------------------------------------

video_renderer      = {
    
    ready               = false,
    input_writer_fd     = nil, 
    output_reader_fd    = nil,
    frames              = {},

    load_reqs           = {},   -- Loading queue on main api side. Since tcps need setup
}

--------------------------------------------------------------------------------------------------

video_renderer.load = function(filename)
    tinsert(video_renderer.load_reqs, filename)
end

-- --------------------------------------------------------------------------------------

video_renderer.init = function()
    video_renderer.ready = true
    mputils.read_chunk(video_renderer.output_reader_fd, function(data) 
        if(data.filename) then 
            video_renderer.frames[data.filename] = video_renderer.frames[data.filename] or { frame_id = 0, filename = data.filename }
            video_renderer.frames[data.filename].data = data.data
            video_renderer.frames[data.filename].frame_ready = nil
            video_renderer.frames[data.filename].frame_id = video_renderer.frames[data.filename].frame_id + 1
            print("Frame Ctr: ", video_renderer.frames[data.filename].frame_id, data.filename)
        end
    end)
end

-- --------------------------------------------------------------------------------------

video_renderer.get_frame = function( filename )
    local frame = video_renderer.frames[filename]
    if(frame and frame.data) then return frame end 
    return nil
end

-- --------------------------------------------------------------------------------------

video_renderer.set_frame_buffer = function( filename, target )
    local frame = video_renderer.frames[filename]
    if(frame) then 
        frame.buffer = target
    end
end

-- --------------------------------------------------------------------------------------

video_renderer.close_video = function( filename )
    if(filename) then 
        local cmd_close      = { cmd = "close", filename = filename }
        mputils.write_chunk(video_renderer.input_writer_fd, cmd_close)
    end
end

-- --------------------------------------------------------------------------------------

video_renderer.poll = function()

    if(video_renderer.input_writer_fd == nil) then return end

    for k, filename in ipairs(video_renderer.load_reqs) do
        local cmd_open      = { cmd = "open", filename = filename }
        mputils.write_chunk(video_renderer.input_writer_fd, cmd_open)
    end
    video_renderer.load_reqs = {}

    for k,frame in pairs(video_renderer.frames) do
        if(frame and frame.buffer) then 
            ffi.copy(frame.buffer, frame.data, 1024 * 1024)
            local cmd_ack      = { cmd = "ack", filename = frame.filename }
            mputils.write_chunk(video_renderer.input_writer_fd, cmd_ack)
            frame.frame_ready = true -- clear for next frame
        end
    end
end

-- --------------------------------------------------------------------------------------
