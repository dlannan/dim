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
}



--------------------------------------------------------------------------------------------------

video_renderer.load = function(filename)
    local cmd_open      = { cmd = "open", filename = filename }
    mputils.write_chunk(video_renderer.input_writer_fd, cmd_open)
end

-- --------------------------------------------------------------------------------------
local frame_ctr = 0 

video_renderer.init = function()
    video_renderer.ready = true
    mputils.read_chunk(video_renderer.output_reader_fd, function(data) 
        if(data.filename) then 
            video_renderer.frames[data.filename] = video_renderer.frames[data.filename] or { frame_id = 0, filename = data.filename }
            video_renderer.frames[data.filename].data = data.data
            video_renderer.frames[data.filename].frame_ready = true
            video_renderer.frames[data.filename].frame_id = video_renderer.frames[data.filename].frame_id + 1
            print("Frame Ctr: ", video_renderer.frames[data.filename].frame_id, data.filename)
        end
    end)
end

-- --------------------------------------------------------------------------------------

video_renderer.get_frame = function( filename )
    local frame = video_renderer.frames[filename]
    if(frame and frame.frame_ready == true) then return frame end 
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

    for k,frame in pairs(video_renderer.frames) do
        if(frame and frame.frame_ready == true) then 
            ffi.copy(frame.buffer, frame.data, 1024 * 1024)
            local cmd_ack      = { cmd = "ack", filename = filename }
            mputils.write_chunk(video_renderer.input_writer_fd, cmd_ack)
            frame.frame_ready = false
        end
    end
end

-- --------------------------------------------------------------------------------------
