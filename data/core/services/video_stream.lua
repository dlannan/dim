

-- -----------------------------------------------------------------------------------------

require "core.strict"

local ffi           = require("ffi")
local uv            = require("luv")
local tinsert       = table.insert

local common        = require "core.common"
local config        = require "core.config"

local msgpack       = require "lua.msgpack"

local running       = false
local pipe_writer_fd = nil

local PATHSEP = nil

--------------------------------------------------------------------------------------------------

local function video_stream_thread()

    local redraw = false
    while running do
        -- every check disable redraw
        redraw = false

        -- If there is a waiting frame.. then copy and send to main process for rendering
        if(redraw == true) then
            local frame_data = video_renderer.get_frame(filename)
            if(pipe_writer_fd) then 
                pipe_writer_fd:write("MSGPACK_START")
                pipe_writer_fd:write(frame_data)
                pipe_writer_fd:write("MSGPACK_END")
            end
        end

        -- wait roughly 24Hz
        win.Sleep(1.0 / 24.0)
    end
end

--------------------------------------------------------------------------------------------------
    
local function init(pipe_writer)
    pipe_writer_fd = pipe_writer
    PATHSEP = package.config:sub(1, 1)
    running = true
end

-------------------------------------------------------------------------------------------------

local function run()
    video_stream_thread()
end

--------------------------------------------------------------------------------------------------

local function stop()
  running = false
end

--------------------------------------------------------------------------------------------------

return {
    init        = init,
    run         = run,
    stop        = stop,
}

--------------------------------------------------------------------------------------------------
